// ============================================================================
// STAFF & ROOMS PANEL
// ============================================================================
// Two sections:
// - Staff Availability List (with on-duty status)
// - Room Occupancy Grid (available/occupied count)
// ============================================================================

import 'package:flutter/material.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../models/clinic_dashboard_models.dart';

class StaffRoomsPanel extends StatelessWidget {
  final StaffAvailability staff;
  final RoomsStatus rooms;

  const StaffRoomsPanel({
    super.key,
    required this.staff,
    required this.rooms,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Staff & Rooms',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Staff Availability Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Staff Availability',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 10,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Staff List
          if (staff.staff.isNotEmpty)
            ...staff.staff.take(4).map((member) => _StaffRow(member: member))
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No staff on duty',
                  style: TextStyle(
                    fontSize: 12,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Room Occupancy Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Room Occupancy',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 10,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Room Summary
          Row(
            children: [
              _RoomStatusCard(
                count: rooms.occupied,
                label: 'Occupied',
                color: FuturisticColors.error,
              ),
              const SizedBox(width: 12),
              _RoomStatusCard(
                count: rooms.available,
                label: 'Available',
                color: FuturisticColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Room List
          if (rooms.rooms.isNotEmpty)
            ...rooms.rooms.take(3).map((room) => _RoomRow(room: room))
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'No rooms configured',
                  style: TextStyle(
                    fontSize: 12,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  final StaffMember member;

  const _StaffRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: _getRoleColor(member.role).withValues(alpha: 0.1),
            child: Icon(
              _getRoleIcon(member.role),
              size: 16,
              color: _getRoleColor(member.role),
            ),
          ),
          const SizedBox(width: 12),

          // Name & Role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: FuturisticColors.textPrimary,
                  ),
                ),
                Text(
                  member.role.capitalize(),
                  style: TextStyle(
                    fontSize: 11,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: member.isOnDuty
                  ? FuturisticColors.success.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              member.isOnDuty ? 'On Duty' : 'Off Duty',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: member.isOnDuty ? FuturisticColors.success : Colors.grey,
              ),
            ),
          ),

          // Dept
          if (member.department != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: FuturisticColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                member.department!,
                style: TextStyle(
                  fontSize: 10,
                  color: FuturisticColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return const Color(0xFF1565C0);
      case 'nurse':
        return const Color(0xFF9C27B0);
      case 'receptionist':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF607D8B);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return Icons.medical_services_outlined;
      case 'nurse':
        return Icons.healing_outlined;
      case 'receptionist':
        return Icons.support_agent_outlined;
      default:
        return Icons.person_outline;
    }
  }
}

class _RoomStatusCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _RoomStatusCard({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  final Room room;

  const _RoomRow({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          // Room Number
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(room.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                room.roomNumber,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(room.status),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Room Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.type.capitalize(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: FuturisticColors.textPrimary,
                  ),
                ),
                if (room.assignedDoctorName != null)
                  Text(
                    room.assignedDoctorName!,
                    style: TextStyle(
                      fontSize: 10,
                      color: FuturisticColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(room.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              room.status.capitalize(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _getStatusColor(room.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'occupied':
        return FuturisticColors.error;
      case 'available':
        return FuturisticColors.success;
      case 'cleaning':
        return const Color(0xFFFF9800);
      case 'maintenance':
        return Colors.grey;
      default:
        return FuturisticColors.textSecondary;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
