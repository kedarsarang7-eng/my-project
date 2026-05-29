// ============================================================================
// ACADEMIC COACHING — PAYSLIP GENERATION MODULE
// ============================================================================
// Faculty/staff payroll calculation and payslip generation
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
  Keys,
  putItem,
  getItem,
  updateItem,
  queryAllItems,
} from '../config/dynamodb.config';
import { StorageService } from '../services/storage.service';

const storageService = new StorageService();

const AC_PAYSLIP_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_FEE_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

// ============================================================================
// PAYROLL CALCULATION
// ============================================================================

/**
 * GET /ac/faculty/{id}/payroll
 * Calculate payroll for a faculty member
 */
export const calculatePayroll = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const facultyId = event.pathParameters?.id;
    if (!facultyId) return response.badRequest('Faculty ID required');

    const p = event.queryStringParameters || {};
    const { month, year } = p; // Format: month=01-12, year=2024

    if (!month || !year) {
      return response.badRequest('month and year are required');
    }

    const pk = Keys.tenantPK(auth.tenantId);

    // Get faculty details
    const faculty = await getItem<any>(pk, `AC_FACULTY#${facultyId}`);
    if (!faculty) return response.notFound('Faculty not found');

    // Get attendance for the month
    const startDate = `${year}-${month}-01`;
    const endDate = `${year}-${month}-31`;

    const attendance = await queryAllItems(pk, 'AC_FACULTY_ATTENDANCE#', {
      filterExpression: 'facultyId = :facultyId AND #date BETWEEN :start AND :end',
      expressionAttributeNames: { '#date': 'date' },
      expressionAttributeValues: { ':facultyId': facultyId, ':start': startDate, ':end': endDate },
    });

    // Calculate based on salary structure
    const salaryStructure = faculty.salaryStructure || { type: 'fixed', fixedAmountPaisa: 0 };
    let grossSalaryPaisa = 0;
    let workingDays = 0;
    let presentDays = 0;

    if (salaryStructure.type === 'fixed') {
      grossSalaryPaisa = salaryStructure.fixedAmountPaisa || 0;
      workingDays = 30; // Assume 30 days for fixed
      presentDays = attendance.filter((a: any) => a.isPresent).length;
      // Deduct for absences if applicable
      const dailyRate = grossSalaryPaisa / 30;
      const absentDays = 30 - presentDays;
      grossSalaryPaisa -= (dailyRate * absentDays);
    } else if (salaryStructure.type === 'per_class') {
      // Count classes taken
      const classesTaken = attendance.reduce((sum: number, a: any) => sum + (a.classesTaken || 0), 0);
      const perClassRate = salaryStructure.perClassRatePaisa || 0;
      grossSalaryPaisa = classesTaken * perClassRate;
      workingDays = classesTaken;
      presentDays = classesTaken;
    } else if (salaryStructure.type === 'hybrid') {
      const fixed = salaryStructure.fixedAmountPaisa || 0;
      const classesTaken = attendance.reduce((sum: number, a: any) => sum + (a.classesTaken || 0), 0);
      const perClass = (salaryStructure.perClassRatePaisa || 0) * classesTaken;
      grossSalaryPaisa = fixed + perClass;
      workingDays = 30;
      presentDays = attendance.filter((a: any) => a.isPresent).length;
    }

    // Calculate deductions
    const pfDeductionPaisa = Math.round(grossSalaryPaisa * 0.12); // 12% PF
    const esiDeductionPaisa = grossSalaryPaisa <= 21000 * 100 ? Math.round(grossSalaryPaisa * 0.0075) : 0; // 0.75% ESI if <= 21k
    const tdsDeductionPaisa = 0; // Calculate based on tax slab
    const otherDeductionsPaisa = 0;

    const totalDeductionsPaisa = pfDeductionPaisa + esiDeductionPaisa + tdsDeductionPaisa + otherDeductionsPaisa;
    const netSalaryPaisa = grossSalaryPaisa - totalDeductionsPaisa;

    const payroll = {
      facultyId,
      facultyName: `${faculty.firstName} ${faculty.lastName}`,
      month,
      year,
      workingDays,
      presentDays,
      salaryStructure: salaryStructure.type,
      earnings: {
        basicPaisa: Math.round(grossSalaryPaisa * 0.6),
        hraPaisa: Math.round(grossSalaryPaisa * 0.2),
        conveyancePaisa: Math.round(grossSalaryPaisa * 0.1),
        otherAllowancesPaisa: Math.round(grossSalaryPaisa * 0.1),
        grossSalaryPaisa,
      },
      deductions: {
        pfPaisa: pfDeductionPaisa,
        esiPaisa: esiDeductionPaisa,
        tdsPaisa: tdsDeductionPaisa,
        otherPaisa: otherDeductionsPaisa,
        totalDeductionsPaisa,
      },
      netSalaryPaisa,
    };

    return response.success(payroll);
  },
  AC_PAYSLIP_OPTS,
);

// ============================================================================
// PAYSLIP GENERATION
// ============================================================================

/**
 * POST /ac/faculty/{id}/payslip
 * Generate payslip for a faculty member
 */
export const generatePayslip = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const facultyId = event.pathParameters?.id;
    if (!facultyId) return response.badRequest('Faculty ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { month, year, adjustments } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Check if payslip already exists
    const existing = await queryAllItems(pk, 'AC_PAYSLIP#', {
      filterExpression: 'facultyId = :facultyId AND #month = :month AND #year = :year',
      expressionAttributeNames: { '#month': 'month', '#year': 'year' },
      expressionAttributeValues: { ':facultyId': facultyId, ':month': month, ':year': year },
    });

    if (existing.length > 0) {
      return response.error(409, 'PAYSLIP_EXISTS', 'Payslip already generated for this month');
    }

    // Get faculty
    const faculty = await getItem<any>(pk, `AC_FACULTY#${facultyId}`);
    if (!faculty) return response.notFound('Faculty not found');

    // Calculate payroll
    // (Reusing logic from calculatePayroll - simplified here)
    const salaryStructure = faculty.salaryStructure || { type: 'fixed', fixedAmountPaisa: 0 };
    const grossSalaryPaisa = salaryStructure.fixedAmountPaisa || 0;
    const pfDeductionPaisa = Math.round(grossSalaryPaisa * 0.12);
    const esiDeductionPaisa = grossSalaryPaisa <= 21000 * 100 ? Math.round(grossSalaryPaisa * 0.0075) : 0;
    const totalDeductionsPaisa = pfDeductionPaisa + esiDeductionPaisa;
    const netSalaryPaisa = grossSalaryPaisa - totalDeductionsPaisa + (adjustments || 0);

    const id = uid();
    const ts = now();
    const payslipNumber = `PS-${year}${month}-${id.substring(0, 6)}`;

    const payslip = {
      PK: pk,
      SK: `AC_PAYSLIP#${id}`,
      GSI1PK: `AC_PAYSLIPS_BY_FACULTY#${auth.tenantId}#${facultyId}`,
      GSI1SK: `${year}-${month}`,
      id,
      payslipNumber,
      facultyId,
      facultyName: `${faculty.firstName} ${faculty.lastName}`,
      month,
      year,
      salaryStructure: salaryStructure.type,
      grossSalaryPaisa,
      deductions: {
        pfPaisa: pfDeductionPaisa,
        esiPaisa: esiDeductionPaisa,
        totalPaisa: totalDeductionsPaisa,
      },
      adjustments: adjustments || 0,
      netSalaryPaisa,
      status: 'generated',
      generatedAt: ts,
      generatedBy: auth.sub,
      s3Key: null, // Will be set after PDF generation
    };

    await putItem(payslip);

    // In production: Generate PDF and upload to S3
    // const pdfS3Key = await generatePayslipPDF(payslip);
    // await updateItem(pk, `AC_PAYSLIP#${id}`, { updateExpression: 'SET s3Key = :s3Key', ... });

    logger.info('Payslip generated', { tenantId: auth.tenantId, payslipId: id, facultyId, month, year });

    return response.success(payslip, 201);
  },
  AC_PAYSLIP_OPTS,
);

/**
 * GET /ac/faculty/{id}/payslips
 * List payslips for a faculty member
 */
export const listPayslips = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const facultyId = event.pathParameters?.id;
    if (!facultyId) return response.badRequest('Faculty ID required');

    const p = event.queryStringParameters || {};
    const { year } = p;

    const pk = Keys.tenantPK(auth.tenantId);

    let payslips = await queryAllItems(
      `AC_PAYSLIPS_BY_FACULTY#${auth.tenantId}#${facultyId}`,
      '',
      { indexName: 'GSI1' }
    );

    if (year) {
      payslips = payslips.filter((ps: any) => ps.year === year);
    }

    // Sort by month-year desc
    payslips.sort((a: any, b: any) => `${b.year}-${b.month}`.localeCompare(`${a.year}-${a.month}`));

    return response.success(payslips);
  },
  AC_PAYSLIP_OPTS,
);

/**
 * GET /ac/payslips/{id}
 * Get payslip details with download URL
 */
export const getPayslip = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Payslip ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const payslip = await getItem<any>(pk, `AC_PAYSLIP#${id}`);
    
    if (!payslip) return response.notFound('Payslip not found');

    // Generate download URL if PDF exists
    let downloadUrl = null;
    if (payslip.s3Key) {
      downloadUrl = await storageService.getDownloadUrl(payslip.s3Key);
    }

    return response.success({ ...payslip, downloadUrl });
  },
  AC_PAYSLIP_OPTS,
);

/**
 * POST /ac/payslips/bulk-generate
 * Generate payslips for all faculty
 */
export const bulkGeneratePayslips = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { month, year } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Get all active faculty
    const faculty = await queryAllItems(pk, 'AC_FACULTY#');
    const activeFaculty = faculty.filter((f: any) => f.isActive);

    const generated = [];
    const errors = [];

    for (const f of activeFaculty) {
      try {
        // Check if already exists
        const existing = await queryAllItems(pk, 'AC_PAYSLIP#', {
          filterExpression: 'facultyId = :facultyId AND #month = :month AND #year = :year',
          expressionAttributeNames: { '#month': 'month', '#year': 'year' },
          expressionAttributeValues: { ':facultyId': f.id, ':month': month, ':year': year },
        });

        if (existing.length === 0) {
          // Generate payslip (simplified logic)
          const salaryStructure = (f as any).salaryStructure || { type: 'fixed', fixedAmountPaisa: 0 };
          const grossSalaryPaisa = (salaryStructure as any).fixedAmountPaisa || 0;
          const pfDeductionPaisa = Math.round(grossSalaryPaisa * 0.12);
          const netSalaryPaisa = grossSalaryPaisa - pfDeductionPaisa;

          const id = uid();
          const payslip = {
            PK: pk,
            SK: `AC_PAYSLIP#${id}`,
            GSI1PK: `AC_PAYSLIPS_BY_FACULTY#${auth.tenantId}#${f.id}`,
            GSI1SK: `${year}-${month}`,
            id,
            payslipNumber: `PS-${year}${month}-${id.substring(0, 6)}`,
            facultyId: f.id,
            facultyName: `${f.firstName} ${f.lastName}`,
            month,
            year,
            grossSalaryPaisa,
            netSalaryPaisa,
            status: 'generated',
            generatedAt: now(),
            generatedBy: auth.sub,
          };

          await putItem(payslip);
          generated.push(payslip);
        }
      } catch (error) {
        errors.push({ facultyId: f.id, error: (error as Error).message });
      }
    }

    logger.info('Bulk payslip generation complete', { 
      tenantId: auth.tenantId, 
      generated: generated.length, 
      errors: errors.length 
    });

    return response.success({
      generated: generated.length,
      errors: errors.length,
      errorDetails: errors,
      month,
      year,
    });
  },
  AC_PAYSLIP_OPTS,
);

/**
 * GET /ac/payroll/summary
 * Payroll summary for a month
 */
export const getPayrollSummary = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const { month, year } = p;

    if (!month || !year) {
      return response.badRequest('month and year are required');
    }

    const pk = Keys.tenantPK(auth.tenantId);

    const payslips = await queryAllItems(pk, 'AC_PAYSLIP#', {
      filterExpression: '#month = :month AND #year = :year',
      expressionAttributeNames: { '#month': 'month', '#year': 'year' },
      expressionAttributeValues: { ':month': month, ':year': year },
    });

    const summary = {
      totalPayslips: payslips.length,
      totalGrossPaisa: payslips.reduce((sum: number, ps: any) => sum + (ps.grossSalaryPaisa || 0), 0),
      totalNetPaisa: payslips.reduce((sum: number, ps: any) => sum + (ps.netSalaryPaisa || 0), 0),
      totalDeductionsPaisa: payslips.reduce((sum: number, ps: any) => {
        return sum + ((ps.deductions?.totalPaisa || 0) + (ps.deductions?.pfPaisa || 0) + (ps.deductions?.esiPaisa || 0));
      }, 0),
      month,
      year,
    };

    return response.success(summary);
  },
  AC_PAYSLIP_OPTS,
);
