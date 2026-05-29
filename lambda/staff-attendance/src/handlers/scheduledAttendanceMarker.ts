// ============================================================================
// SCHEDULED ATTENDANCE MARKER - CloudWatch Events trigger
// ============================================================================
// Triggered daily at midnight to:
// 1. Mark ABSENT for staff who didn't check in
// 2. Auto-close shifts still OPEN after 24 hours
// 3. Generate daily attendance summary
// ============================================================================

import { queryItems, putItem, updateItem } from '../utils/dynamodb';
import { getCurrentTimestamp, getCurrentDate } from '../utils/ulid';
import { TABLES } from '../constants/tables';
import type { StaffProfile, StaffShift, StaffAttendance } from '../types/attendance';

interface ScheduledEvent {
  detail?: {
    action?: string;
  };
}

export const handler = async (event: ScheduledEvent): Promise<void> => {
  const timestamp = getCurrentTimestamp();
  const today = getCurrentDate();
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = yesterday.toISOString().split('T')[0];

  console.log('Running scheduled attendance marker for:', yesterdayStr);

  try {
    // Get all active staff
    const allStaff = await queryItems<StaffProfile>(TABLES.STAFF_PROFILES, {
      keyConditionExpression: 'begins_with(PK, :prefix)',
      expressionAttributeValues: {
        ':prefix': 'STAFF#',
      },
    });

    for (const staff of allStaff.items) {
      if (!staff.isActive) continue;

      // Check if staff has attendance record for yesterday
      const existingAttendance = await queryItems<StaffAttendance>(
        TABLES.STAFF_ATTENDANCE,
        {
          keyConditionExpression: 'PK = :staffId AND SK = :date',
          expressionAttributeValues: {
            ':staffId': `STAFF#${staff.staffId}`,
            ':date': `DATE#${yesterdayStr}`,
          },
        }
      );

      if (existingAttendance.items.length === 0) {
        // No check-in: Mark as ABSENT
        const attendance: StaffAttendance = {
          PK: `STAFF#${staff.staffId}`,
          SK: `DATE#${yesterdayStr}`,
          GSI1PK: `STATION#${staff.petrolPumpId}`,
          GSI1SK: `DATE#${yesterdayStr}#STATUS#ABSENT`,
          staffId: staff.staffId,
          stationId: staff.petrolPumpId,
          date: yesterdayStr,
          status: 'ABSENT',
          hoursWorked: 0,
          overtimeHours: 0,
          isLate: false,
          lateMinutes: 0,
          scheduledStart: staff.shiftTiming?.start || '09:00',
          scheduledEnd: staff.shiftTiming?.end || '17:00',
          markedBy: 'SYSTEM',
          notes: 'Auto-marked: No check-in detected',
          createdAt: timestamp,
          updatedAt: timestamp,
        };

        await putItem(TABLES.STAFF_ATTENDANCE, attendance);
        console.log(`Marked ${staff.fullName} as ABSENT for ${yesterdayStr}`);
      }

      // Check for open shifts that need auto-closing (24+ hours old)
      const openShifts = await queryItems<StaffShift>(TABLES.STAFF_SHIFTS, {
        keyConditionExpression: 'PK = :staffId',
        filterExpression: '#status = :open AND checkInTime < :threshold',
        expressionAttributeNames: {
          '#status': 'status',
        },
        expressionAttributeValues: {
          ':staffId': `STAFF#${staff.staffId}`,
          ':open': 'OPEN',
          ':threshold': new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
        },
      });

      for (const shift of openShifts.items) {
        // Auto-close shift
        const hoursWorked = 24; // Cap at 24 hours
        const overtimeHours = Math.max(0, hoursWorked - 8);

        await updateItem<StaffShift>(
          TABLES.STAFF_SHIFTS,
          { PK: `STAFF#${staff.staffId}`, SK: `SHIFT#${shift.shiftId}` },
          {
            status: 'AUTO_CLOSED',
            checkOutTime: timestamp,
            totalHours: hoursWorked,
            overtimeHours: overtimeHours,
            isOvertime: overtimeHours > 0,
            updatedAt: timestamp,
            GSI2SK: `STATUS#AUTO_CLOSED#DATE#${yesterdayStr}`,
          }
        );

        // Create alert for manager
        // (Implementation would create alert in StaffAlerts table)
        console.log(`Auto-closed shift ${shift.shiftId} for ${staff.fullName}`);
      }
    }

    console.log('Scheduled attendance marking completed successfully');
  } catch (error) {
    console.error('Scheduled attendance marker error:', error);
    throw error;
  }
};
