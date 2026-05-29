// ============================================================================
// CLINIC DASHBOARD SERVICE — Business Logic Layer
// ============================================================================
// Aggregates data from DynamoDB for dashboard panels
// Enforces RBAC at data level (not just UI)
// All methods return { data, isEmpty, message } pattern
// ============================================================================

import { 
  queryItems, 
  queryAllItems, 
  getItem 
} from '../config/dynamodb.config';
import { 
  ClinicKeys, 
  ClinicPatient, 
  ClinicAppointment, 
  ClinicStaff, 
  ClinicBilling, 
  ClinicInventory, 
  ClinicRoom,
  isClinicAppointment,
  isClinicStaff,
  isClinicBilling,
  isClinicInventory,
  isClinicRoom,
  isClinicPatient,
} from '../config/clinic-dynamodb-schema';
import { logger } from '../utils/logger';
import { getCached } from '../utils/cache';

// ============================================================================
// TYPES
// ============================================================================

export type ClinicRole = 'admin' | 'doctor' | 'nurse' | 'receptionist';

export interface DashboardContext {
  tenantId: string;
  clinicId: string;
  userId: string;
  role: ClinicRole;
  doctorId?: string;  // Set if role is 'doctor'
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function toDateString(date: Date): string {
  return date.toISOString().split('T')[0];
}

function getStartOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function getEndOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

function toCents(amount: number): number {
  return Math.round(amount * 100);
}

function formatCurrency(cents: number, locale = 'en-IN'): string {
  const rupees = cents / 100;
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(rupees);
}

function daysBetween(d1: Date, d2: Date): number {
  const msPerDay = 1000 * 60 * 60 * 24;
  return Math.floor((d2.getTime() - d1.getTime()) / msPerDay);
}

function calculatePercentChange(current: number, previous: number): number {
  if (previous === 0) return current > 0 ? 100 : 0;
  return Math.round(((current - previous) / previous) * 1000) / 10;
}

// ============================================================================
// SERVICE CLASS
// ============================================================================

export class ClinicDashboardService {
  
  // ── LICENSE VALIDATION ─────────────────────────────────────────────────────
  
  async validateClinicLicense(licenseKey: string): Promise<{
    valid: boolean;
    clinicId?: string;
    tenantId?: string;
    businessType?: string;
    expiresAt?: string;
    error?: string;
  }> {
    try {
      const pk = `LICENSE#${licenseKey}`;
      const license = await getItem<Record<string, unknown>>(pk, 'META');
      
      if (!license) {
        return { valid: false, error: 'License not found' };
      }
      
      const businessType = String(license.businessType || '').toLowerCase();
      const isActive = license.isActive === true;
      const expiresAt = String(license.expiresAt || '');
      const isExpired = expiresAt ? new Date(expiresAt) < new Date() : false;
      
      if (businessType !== 'clinic') {
        return { valid: false, error: 'License not valid for clinic business type' };
      }
      
      if (!isActive) {
        return { valid: false, error: 'License is inactive' };
      }
      
      if (isExpired) {
        return { valid: false, error: 'License has expired', expiresAt };
      }
      
      return {
        valid: true,
        clinicId: String(license.clinicId || ''),
        tenantId: String(license.tenantId || ''),
        businessType,
        expiresAt,
      };
    } catch (error) {
      logger.error('License validation error', { licenseKey, error });
      return { valid: false, error: 'License validation failed' };
    }
  }

  // ── ROLE-BASED ACCESS CHECK ────────────────────────────────────────────────
  
  private enforceRoleAccess<T>(
    ctx: DashboardContext,
    allowedRoles: ClinicRole[],
    data: T
  ): T | null {
    if (!allowedRoles.includes(ctx.role)) {
      logger.warn('Access denied', { userId: ctx.userId, role: ctx.role, required: allowedRoles });
      return null;
    }
    return data;
  }

  // ── DASHBOARD OVERVIEW (4 KPI Cards) ───────────────────────────────────────
  
  async getDashboardOverview(ctx: DashboardContext, date: string): Promise<{
    totalPatients: { count: number; changePercent: number };
    appointmentsToday: { total: number; completed: number; pending: number; cancelled: number };
    staffOnDuty: { total: number; onDuty: number };
    revenueToday: { amountCents: number; changePercent: number; formatted: string };
    isEmpty: boolean;
    message?: string;
  }> {
    const cacheKey = `clinic-overview:${ctx.clinicId}:${date}:${ctx.role}`;
    
    return getCached(cacheKey, 120, async () => {
      try {
        const pk = ClinicKeys.clinicPK(ctx.clinicId);
        const targetDate = date || toDateString(new Date());
        
        // Fetch all required data in parallel
        const [
          patientsResult,
          appointmentsToday,
          staffResult,
          revenueToday,
          revenueYesterday,
        ] = await Promise.all([
          // Total patients count (distinct)
          queryAllItems<ClinicPatient>(pk, 'PATIENT#', { maxPages: 100 }),
          
          // Today's appointments
          queryItems<ClinicAppointment>(pk, 'APPT#', {
            filterExpression: 'begins_with(#date, :date)',
            expressionAttributeNames: { '#date': 'date' },
            expressionAttributeValues: { ':date': targetDate },
          }),
          
          // Staff on duty
          queryAllItems<ClinicStaff>(pk, 'STAFF#', { maxPages: 20 }),
          
          // Today's revenue
          this.getRevenueForDate(ctx.clinicId, targetDate),
          
          // Yesterday's revenue for comparison
          this.getRevenueForDate(ctx.clinicId, this.getYesterday(targetDate)),
        ]);
        
        // Calculate patients metrics
        const patients = patientsResult.filter(isClinicPatient);
        const totalPatients = patients.length;
        const newThisMonth = patients.filter(p => {
          const created = new Date(p.createdAt);
          const now = new Date();
          return created.getMonth() === now.getMonth() && 
                 created.getFullYear() === now.getFullYear();
        }).length;
        const newLastMonth = patients.filter(p => {
          const created = new Date(p.createdAt);
          const now = new Date();
          const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
          return created.getMonth() === lastMonth.getMonth() && 
                 created.getFullYear() === lastMonth.getFullYear();
        }).length;
        
        // Calculate appointments metrics
        const appts = appointmentsToday.items.filter(isClinicAppointment);
        const appointmentsData = {
          total: appts.length,
          completed: appts.filter(a => a.status === 'completed').length,
          pending: appts.filter(a => a.status === 'scheduled' || a.status === 'in-progress').length,
          cancelled: appts.filter(a => a.status === 'cancelled').length,
        };
        
        // Calculate staff metrics
        const staff = staffResult.filter(isClinicStaff);
        const staffData = {
          total: staff.length,
          onDuty: staff.filter(s => s.isOnDuty).length,
        };
        
        // Calculate revenue metrics
        const revenueChange = calculatePercentChange(revenueToday, revenueYesterday);
        
        return {
          totalPatients: {
            count: totalPatients,
            changePercent: calculatePercentChange(newThisMonth, newLastMonth),
          },
          appointmentsToday: appointmentsData,
          staffOnDuty: staffData,
          revenueToday: {
            amountCents: revenueToday,
            changePercent: revenueChange,
            formatted: formatCurrency(revenueToday),
          },
          isEmpty: patients.length === 0 && appts.length === 0,
          message: patients.length === 0 && appts.length === 0 
            ? 'No clinic data available yet' 
            : undefined,
        };
      } catch (error) {
        logger.error('Dashboard overview error', { clinicId: ctx.clinicId, error });
        throw error;
      }
    });
  }

  private async getRevenueForDate(clinicId: string, date: string): Promise<number> {
    const pk = ClinicKeys.clinicPK(clinicId);
    const result = await queryItems<ClinicBilling>(pk, 'BILL#', {
      filterExpression: '#date = :date AND (#status = :paid OR #status = :partial)',
      expressionAttributeNames: { '#date': 'date', '#status': 'status' },
      expressionAttributeValues: { 
        ':date': date, 
        ':paid': 'paid', 
        ':partial': 'partial' 
      },
    });
    
    return result.items
      .filter(isClinicBilling)
      .reduce((sum, bill) => sum + bill.amountPaidCents, 0);
  }

  private getYesterday(dateStr: string): string {
    const date = new Date(dateStr);
    date.setDate(date.getDate() - 1);
    return toDateString(date);
  }

  // ── APPOINTMENTS LIST ──────────────────────────────────────────────────────
  
  async getAppointments(
    ctx: DashboardContext, 
    date: string, 
    doctorId?: string,
    status?: string
  ): Promise<{
    appointments: Array<{
      id: string;
      patientName: string;
      patientId: string;
      doctorName: string;
      doctorId: string;
      type: string;
      startTime: string;
      endTime: string;
      status: string;
      reason: string;
      roomNumber?: string;
    }>;
    isEmpty: boolean;
    message?: string;
  }> {
    // Role-based filtering: doctors only see their own appointments
    const effectiveDoctorId = ctx.role === 'doctor' ? ctx.doctorId : doctorId;
    
    const cacheKey = `clinic-appointments:${ctx.clinicId}:${date}:${effectiveDoctorId || 'all'}:${status || 'all'}`;
    
    return getCached(cacheKey, 60, async () => {
      try {
        const pk = ClinicKeys.clinicPK(ctx.clinicId);
        const targetDate = date || toDateString(new Date());
        
        let appointments: ClinicAppointment[] = [];
        
        if (effectiveDoctorId) {
          // Query by doctor using GSI1
          const result = await queryItems<ClinicAppointment>(
            `DOC#${effectiveDoctorId}`,
            targetDate,
            { indexName: 'GSI1' }
          );
          appointments = result.items.filter(isClinicAppointment);
        } else {
          // Query by date using GSI2
          const result = await queryItems<ClinicAppointment>(
            `DATE#${targetDate}`,
            '',
            { 
              indexName: 'GSI2',
              filterExpression: 'begins_with(SK, :prefix)',
              expressionAttributeValues: { ':prefix': 'APPT#' },
            }
          );
          appointments = result.items.filter(isClinicAppointment);
        }
        
        // Filter by status if specified
        if (status) {
          appointments = appointments.filter(a => a.status === status);
        }
        
        // Sort by start time
        appointments.sort((a, b) => a.startTime.localeCompare(b.startTime));
        
        // Fetch room numbers for occupied rooms
        const roomIds = appointments
          .map(a => a.roomId)
          .filter((id): id is string => !!id);
        
        const roomsMap = new Map<string, ClinicRoom>();
        if (roomIds.length > 0) {
          const roomsResult = await queryAllItems<ClinicRoom>(pk, 'ROOM#', { maxPages: 10 });
          roomsResult.filter(isClinicRoom).forEach(r => roomsMap.set(r.roomId, r));
        }
        
        return {
          appointments: appointments.map(a => ({
            id: a.appointmentId,
            patientName: a.patientName,
            patientId: a.patientId,
            doctorName: a.doctorName,
            doctorId: a.doctorId,
            type: a.type,
            startTime: a.startTime,
            endTime: a.endTime,
            status: a.status,
            reason: a.reason,
            roomNumber: a.roomId ? roomsMap.get(a.roomId)?.roomNumber : undefined,
          })),
          isEmpty: appointments.length === 0,
          message: appointments.length === 0 ? 'No appointments found' : undefined,
        };
      } catch (error) {
        logger.error('Appointments fetch error', { clinicId: ctx.clinicId, error });
        throw error;
      }
    });
  }

  // ── PATIENT INSIGHTS ─────────────────────────────────────────────────────────
  
  async getPatientInsights(ctx: DashboardContext): Promise<{
    newPatientsByDepartment: Array<{ department: string; count: number; percentage: number }>;
    recentPatients: Array<{
      name: string;
      id: string;
      lastVisit: string;
      reason: string;
      status: string;
    }>;
    isEmpty: boolean;
    message?: string;
  }> {
    const cacheKey = `clinic-patient-insights:${ctx.clinicId}`;
    
    return getCached(cacheKey, 300, async () => {
      try {
        const pk = ClinicKeys.clinicPK(ctx.clinicId);
        
        // Fetch patients and appointments
        const [patientsResult, appointmentsResult] = await Promise.all([
          queryAllItems<ClinicPatient>(pk, 'PATIENT#', { maxPages: 50 }),
          queryAllItems<ClinicAppointment>(pk, 'APPT#', { maxPages: 50 }),
        ]);
        
        const patients = patientsResult.filter(isClinicPatient);
        const appointments = appointmentsResult.filter(isClinicAppointment);
        
        // Calculate department distribution for new patients (last 30 days)
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        
        const newPatients = patients.filter(p => new Date(p.createdAt) >= thirtyDaysAgo);
        const deptCounts = new Map<string, number>();
        
        newPatients.forEach(p => {
          const dept = p.department || 'General';
          deptCounts.set(dept, (deptCounts.get(dept) || 0) + 1);
        });
        
        const totalNew = newPatients.length || 1; // Avoid division by zero
        const newPatientsByDepartment = Array.from(deptCounts.entries())
          .map(([department, count]) => ({
            department,
            count,
            percentage: Math.round((count / totalNew) * 100),
          }))
          .sort((a, b) => b.count - a.count)
          .slice(0, 5);
        
        // Get recent patients (last 10 appointments)
        const recentAppts = appointments
          .filter(a => a.status === 'completed')
          .sort((a, b) => b.completedAt?.localeCompare(a.completedAt || '') || 0)
          .slice(0, 10);
        
        const patientMap = new Map(patients.map(p => [p.patientId, p]));
        
        const recentPatients = recentAppts.map(a => {
          const patient = patientMap.get(a.patientId);
          return {
            name: a.patientName,
            id: a.patientId,
            lastVisit: a.date,
            reason: a.reason,
            status: patient?.status || 'returning',
          };
        });
        
        return {
          newPatientsByDepartment,
          recentPatients,
          isEmpty: patients.length === 0,
          message: patients.length === 0 ? 'No patient records found' : undefined,
        };
      } catch (error) {
        logger.error('Patient insights error', { clinicId: ctx.clinicId, error });
        throw error;
      }
    });
  }

  // ── STAFF AVAILABILITY ─────────────────────────────────────────────────────
  
  async getStaffAvailability(ctx: DashboardContext): Promise<{
    staff: Array<{
      userId: string;
      name: string;
      role: string;
      status: string;
      department?: string;
      roomAssigned?: string;
      isOnDuty: boolean;
      shiftStart?: string;
      shiftEnd?: string;
    }>;
    isEmpty: boolean;
    message?: string;
  }> {
    // All roles can see staff availability except receptionist limitations
    const cacheKey = `clinic-staff:${ctx.clinicId}`;
    
    return getCached(cacheKey, 60, async () => {
      try {
        const pk = ClinicKeys.clinicPK(ctx.clinicId);
        const result = await queryAllItems<ClinicStaff>(pk, 'STAFF#', { maxPages: 20 });
        
        const staff = result.filter(isClinicStaff);
        
        // Filter based on role
        let filteredStaff = staff;
        if (ctx.role === 'receptionist') {
          // Receptionists see doctors and nurses only (for check-in purposes)
          filteredStaff = staff.filter(s => s.role === 'doctor' || s.role === 'nurse');
        } else if (ctx.role === 'nurse') {
          // Nurses see all clinical staff
          filteredStaff = staff.filter(s => 
            s.role === 'doctor' || s.role === 'nurse' || s.role === 'lab_tech'
          );
        }
        
        return {
          staff: filteredStaff.map(s => ({
            userId: s.userId,
            name: s.name,
            role: s.role,
            status: s.status,
            department: s.department,
            roomAssigned: s.roomAssigned,
            isOnDuty: s.isOnDuty,
            shiftStart: s.shiftStart,
            shiftEnd: s.shiftEnd,
          })),
          isEmpty: staff.length === 0,
          message: staff.length === 0 ? 'No staff records found' : undefined,
        };
      } catch (error) {
        logger.error('Staff availability error', { clinicId: ctx.clinicId, error });
        throw error;
      }
    });
  }

  // ── ROOMS STATUS ─────────────────────────────────────────────────────────────
  
  async getRoomsStatus(ctx: DashboardContext): Promise<{
    rooms: Array<{
      roomId: string;
      roomNumber: string;
      type: string;
      status: string;
      currentPatientName?: string;
      assignedDoctorName?: string;
      nextAvailableAt?: string;
    }>;
    available: number;
    occupied: number;
    cleaning: number;
    isEmpty: boolean;
    message?: string;
  }> {
    const cacheKey = `clinic-rooms:${ctx.clinicId}`;
    
    return getCached(cacheKey, 30, async () => {
      try {
        const pk = ClinicKeys.clinicPK(ctx.clinicId);
        const result = await queryAllItems<ClinicRoom>(pk, 'ROOM#', { maxPages: 20 });
        
        const rooms = result.filter(isClinicRoom);
        
        // Calculate counts
        const counts = {
          available: rooms.filter(r => r.status === 'available').length,
          occupied: rooms.filter(r => r.status === 'occupied').length,
          cleaning: rooms.filter(r => r.status === 'cleaning').length,
        };
        
        // Mask patient names based on role
        const maskedRooms = rooms.map(r => {
          const canSeePatientDetails = ['admin', 'doctor', 'nurse'].includes(ctx.role);
          return {
            roomId: r.roomId,
            roomNumber: r.roomNumber,
            type: r.type,
            status: r.status,
            currentPatientName: canSeePatientDetails ? r.currentPatientName : 
              r.currentPatientId ? 'Patient' : undefined,
            assignedDoctorName: r.assignedDoctorName,
            nextAvailableAt: r.nextAvailableAt,
          };
        });
        
        return {
          rooms: maskedRooms,
          ...counts,
          isEmpty: rooms.length === 0,
          message: rooms.length === 0 ? 'No rooms configured' : undefined,
        };
      } catch (error) {
        logger.error('Rooms status error', { clinicId: ctx.clinicId, error });
        throw error;
      }
    });
  }

  // ── BILLING SUMMARY ────────────────────────────────────────────────────────
  
  async getBillingSummary(
    ctx: DashboardContext, 
    period: 'daily' | 'weekly' | 'monthly' = 'monthly'
  ): Promise<{
    monthlyRevenue: Array<{ month: string; amountCents: number; formatted: string }>;
    pendingInvoices: number;
    pendingAmountCents: number;
    completedPayments: number;
    isEmpty: boolean;
    message?: string;
  }> {
    // Only admin and receptionist can see billing
    if (!['admin', 'receptionist'].includes(ctx.role)) {
      return {
        monthlyRevenue: [],
        pendingInvoices: 0,
        pendingAmountCents: 0,
        completedPayments: 0,
        isEmpty: true,
        message: 'Access denied: Billing data restricted',
      };
    }
    
    const cacheKey = `clinic-billing:${ctx.clinicId}:${period}`;
    
    return getCached(cacheKey, 300, async () => {
      try {
        const pk = ClinicKeys.clinicPK(ctx.clinicId);
        const result = await queryAllItems<ClinicBilling>(pk, 'BILL#', { maxPages: 100 });
        
        const bills = result.filter(isClinicBilling);
        
        // Group by month
        const monthlyData = new Map<string, number>();
        const months: string[] = [];
        
        // Get last 6 months
        for (let i = 5; i >= 0; i--) {
          const d = new Date();
          d.setMonth(d.getMonth() - i);
          const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
          const label = d.toLocaleString('default', { month: 'short' });
          months.push(label);
          monthlyData.set(key, 0);
        }
        
        let pendingInvoices = 0;
        let pendingAmountCents = 0;
        let completedPayments = 0;
        
        bills.forEach(bill => {
          const monthKey = bill.date.substring(0, 7); // YYYY-MM
          if (monthlyData.has(monthKey)) {
            monthlyData.set(monthKey, (monthlyData.get(monthKey) || 0) + bill.amountPaidCents);
          }
          
          if (bill.status === 'pending' || bill.status === 'overdue') {
            pendingInvoices++;
            pendingAmountCents += bill.balanceCents;
          } else if (bill.status === 'paid') {
            completedPayments++;
          }
        });
        
        const monthlyRevenue = Array.from(monthlyData.entries()).map(([key, amountCents], index) => ({
          month: months[index] || key,
          amountCents,
          formatted: formatCurrency(amountCents),
        }));
        
        return {
          monthlyRevenue,
          pendingInvoices,
          pendingAmountCents,
          completedPayments,
          isEmpty: bills.length === 0,
          message: bills.length === 0 ? 'No billing records found' : undefined,
        };
      } catch (error) {
        logger.error('Billing summary error', { clinicId: ctx.clinicId, error });
        throw error;
      }
    });
  }

  // ── INVENTORY ALERTS ───────────────────────────────────────────────────────
  
  async getInventoryAlerts(ctx: DashboardContext): Promise<{
    items: Array<{
      id: string;
      name: string;
      category: string;
      quantity: number;
      minThreshold: number;
      status: string;
      daysUntilExpiry?: number;
    }>;
    lowStockCount: number;
    expiredCount: number;
    isEmpty: boolean;
    message?: string;
  }> {
    // All roles can see inventory alerts (nurses need this for supplies)
    const cacheKey = `clinic-inventory-alerts:${ctx.clinicId}`;
    
    return getCached(cacheKey, 120, async () => {
      try {
        const pk = ClinicKeys.clinicPK(ctx.clinicId);
        const result = await queryAllItems<ClinicInventory>(pk, 'INVENTORY#', { maxPages: 50 });
        
        const items = result.filter(isClinicInventory);
        const now = new Date();
        const thirtyDaysFromNow = new Date();
        thirtyDaysFromNow.setDate(now.getDate() + 30);
        
        const alerts = items
          .filter(item => {
            // Low stock
            if (item.quantity <= item.minThreshold) return true;
            // Expiring soon
            if (item.expiryDate) {
              const expiry = new Date(item.expiryDate);
              return expiry <= thirtyDaysFromNow;
            }
            return false;
          })
          .map(item => {
            let daysUntilExpiry: number | undefined;
            if (item.expiryDate) {
              daysUntilExpiry = daysBetween(now, new Date(item.expiryDate));
            }
            
            return {
              id: item.itemId,
              name: item.itemName,
              category: item.category,
              quantity: item.quantity,
              minThreshold: item.minThreshold,
              status: item.status,
              daysUntilExpiry,
            };
          })
          .sort((a, b) => {
            // Prioritize expired items, then low stock
            if (a.daysUntilExpiry !== undefined && a.daysUntilExpiry < 0) return -1;
            if (b.daysUntilExpiry !== undefined && b.daysUntilExpiry < 0) return 1;
            return (a.quantity / a.minThreshold) - (b.quantity / b.minThreshold);
          });
        
        return {
          items: alerts,
          lowStockCount: alerts.filter(i => i.quantity <= i.minThreshold).length,
          expiredCount: alerts.filter(i => i.daysUntilExpiry !== undefined && i.daysUntilExpiry < 0).length,
          isEmpty: alerts.length === 0,
          message: alerts.length === 0 ? 'All inventory levels are healthy' : undefined,
        };
      } catch (error) {
        logger.error('Inventory alerts error', { clinicId: ctx.clinicId, error });
        throw error;
      }
    });
  }

  // ── WEEKLY APPOINTMENT TRENDS ────────────────────────────────────────────────
  
  async getWeeklyAppointmentTrends(
    ctx: DashboardContext, 
    weeks: number = 2
  ): Promise<{
    data: Array<{
      day: string;
      thisWeek: number;
      lastWeek: number;
    }>;
    isEmpty: boolean;
    message?: string;
  }> {
    const cacheKey = `clinic-trends:${ctx.clinicId}:${weeks}`;
    
    return getCached(cacheKey, 300, async () => {
      try {
        const pk = ClinicKeys.clinicPK(ctx.clinicId);
        const result = await queryAllItems<ClinicAppointment>(pk, 'APPT#', { maxPages: 100 });
        
        const appointments = result.filter(isClinicAppointment);
        
        const now = new Date();
        const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        
        // Get current week and previous week
        const thisWeekStart = new Date(now);
        thisWeekStart.setDate(now.getDate() - now.getDay()); // Start of week (Sunday)
        
        const lastWeekStart = new Date(thisWeekStart);
        lastWeekStart.setDate(thisWeekStart.getDate() - 7);
        
        const data: Array<{ day: string; thisWeek: number; lastWeek: number }> = [];
        
        for (let i = 0; i < 7; i++) {
          const thisDay = new Date(thisWeekStart);
          thisDay.setDate(thisWeekStart.getDate() + i);
          
          const lastDay = new Date(lastWeekStart);
          lastDay.setDate(lastWeekStart.getDate() + i);
          
          const thisDayStr = toDateString(thisDay);
          const lastDayStr = toDateString(lastDay);
          
          const thisWeekCount = appointments.filter(a => a.date === thisDayStr).length;
          const lastWeekCount = appointments.filter(a => a.date === lastDayStr).length;
          
          data.push({
            day: dayNames[i],
            thisWeek: thisWeekCount,
            lastWeek: lastWeekCount,
          });
        }
        
        return {
          data,
          isEmpty: appointments.length === 0,
          message: appointments.length === 0 ? 'No appointment history' : undefined,
        };
      } catch (error) {
        logger.error('Weekly trends error', { clinicId: ctx.clinicId, error });
        throw error;
      }
    });
  }

  // ── AVERAGE WAIT TIME ────────────────────────────────────────────────────────
  
  async getAverageWaitTime(
    ctx: DashboardContext, 
    date: string
  ): Promise<{
    avgWaitMinutes: number;
    zone: 'green' | 'yellow' | 'red';
    totalCheckedIn: number;
    isEmpty: boolean;
    message?: string;
  }> {
    const cacheKey = `clinic-wait-time:${ctx.clinicId}:${date}`;
    
    return getCached(cacheKey, 60, async () => {
      try {
        const pk = ClinicKeys.clinicPK(ctx.clinicId);
        const targetDate = date || toDateString(new Date());
        
        // Query appointments for date
        const result = await queryItems<ClinicAppointment>(pk, 'APPT#', {
          filterExpression: '#date = :date AND attribute_exists(checkedInAt)',
          expressionAttributeNames: { '#date': 'date' },
          expressionAttributeValues: { ':date': targetDate },
        });
        
        const appointments = result.items.filter(isClinicAppointment);
        
        let totalWaitMinutes = 0;
        let count = 0;
        
        appointments.forEach(a => {
          if (a.checkedInAt && a.startTime) {
            const checkIn = new Date(a.checkedInAt);
            const start = new Date(a.startTime);
            const waitMinutes = (start.getTime() - checkIn.getTime()) / (1000 * 60);
            if (waitMinutes >= 0) { // Valid wait time
              totalWaitMinutes += waitMinutes;
              count++;
            }
          }
        });
        
        const avgWaitMinutes = count > 0 ? Math.round(totalWaitMinutes / count) : 0;
        
        // Determine zone
        let zone: 'green' | 'yellow' | 'red' = 'green';
        if (avgWaitMinutes > 40) zone = 'red';
        else if (avgWaitMinutes > 20) zone = 'yellow';
        
        return {
          avgWaitMinutes,
          zone,
          totalCheckedIn: count,
          isEmpty: count === 0,
          message: count === 0 ? 'No check-in data available' : undefined,
        };
      } catch (error) {
        logger.error('Wait time error', { clinicId: ctx.clinicId, error });
        throw error;
      }
    });
  }
}

// Export singleton instance
export const clinicDashboardService = new ClinicDashboardService();
