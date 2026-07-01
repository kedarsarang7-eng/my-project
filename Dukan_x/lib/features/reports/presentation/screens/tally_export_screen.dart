import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../services/tally_xml_service.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';

class TallyExportScreen extends StatefulWidget {
  const TallyExportScreen({super.key});

  @override
  State<TallyExportScreen> createState() => _TallyExportScreenState();
}

class _TallyExportScreenState extends State<TallyExportScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Tally XML Export',
      subtitle: 'Export Sales and Receipts for Tally Prime integration',
      actions: [
        DesktopIconButton(
          icon: Icons.upload_file,
          tooltip: 'Generate XML',
          onPressed: _isLoading ? null : _generateAndShare,
        ),
      ],
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 32, // PRESERVED: Desktop uses exactly 32 as before
            ),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Date Range',
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop:
                        18.0, // PRESERVED: Desktop uses exactly 18 as before
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildDateButton(true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDateButton(false)),
                ],
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                PrimaryButton(
                  label: 'Generate & Export XML',
                  icon: Icons.upload_file,
                  onPressed: _generateAndShare,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton(bool isFrom) {
    final date = isFrom ? _fromDate : _toDate;
    return InkWell(
      onTap: () => _pickDate(isFrom),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFrom ? 'From Date' : 'To Date',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
        } else {
          _toDate = picked;
          if (_toDate.isBefore(_fromDate)) _fromDate = _toDate;
        }
      });
    }
  }

  Future<void> _generateAndShare() async {
    setState(() => _isLoading = true);

    try {
      final session = sl<SessionManager>();
      final userId = session.ownerId;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      final service = sl<TallyXmlService>();
      final file = await service.generateExportXml(_fromDate, _toDate, userId);

      if (file != null && mounted) {
        // Share via share_plus
        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              'Tally XML Export (${DateFormat('dd-MMM').format(_fromDate)} to ${DateFormat('dd-MMM').format(_toDate)})',
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate export file')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
