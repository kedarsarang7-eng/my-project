// Certificate Tracking Screen - Manage jewellery certificates
// Feature: CRUD screen for certificate management
// Requirement 16.5: Certificate and certification tracking screen

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/utils/rid_generator.dart';
import '../../data/models/jewellery_certificate_model.dart';

class CertificateTrackingScreen extends StatefulWidget {
  const CertificateTrackingScreen({super.key});

  @override
  State<CertificateTrackingScreen> createState() =>
      _CertificateTrackingScreenState();
}

class _CertificateTrackingScreenState extends State<CertificateTrackingScreen> {
  final SessionManager _session = sl<SessionManager>();

  late Box<JewelleryCertificate> _certificatesBox;
  List<JewelleryCertificate> _certificates = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';

  final List<String> _filters = [
    'all',
    'hallmark',
    'assay',
    'valuation',
    'insurance',
    'appraisal',
    'expired',
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _certificatesBox = await Hive.openBox<JewelleryCertificate>(
        'jewellery_certificates',
      );
      await _loadCertificates();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCertificates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tenantId = _session.ownerId;
      var certs = _certificatesBox.values
          .where((c) => c.tenantId == tenantId)
          .toList();

      // Apply filter
      switch (_selectedFilter) {
        case 'hallmark':
          certs = certs
              .where((c) => c.type == CertificateType.hallmark)
              .toList();
          break;
        case 'assay':
          certs = certs.where((c) => c.type == CertificateType.assay).toList();
          break;
        case 'valuation':
          certs = certs
              .where((c) => c.type == CertificateType.valuation)
              .toList();
          break;
        case 'insurance':
          certs = certs
              .where((c) => c.type == CertificateType.insurance)
              .toList();
          break;
        case 'appraisal':
          certs = certs
              .where((c) => c.type == CertificateType.appraisal)
              .toList();
          break;
        case 'expired':
          certs = certs.where((c) => c.isExpired).toList();
          break;
      }

      // Sort by issue date descending
      certs.sort((a, b) => b.issueDate.compareTo(a.issueDate));

      setState(() {
        _certificates = certs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load certificates: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addCertificate() async {
    final tenantId = _session.ownerId ?? '';
    if (tenantId.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddCertificateDialog(
        tenantId: tenantId,
        onSave: (certificate) async {
          await _certificatesBox.put(certificate.id, certificate);
        },
      ),
    );

    if (result == true) {
      await _loadCertificates();
    }
  }

  Future<void> _deleteCertificate(JewelleryCertificate cert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Certificate'),
        content: Text(
          'Are you sure you want to delete this ${cert.type.displayName} '
          'certificate issued by ${cert.issuer}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _certificatesBox.delete(cert.id);
      await _loadCertificates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorWidget()
          : Column(
              children: [
                _buildHeader(),
                _buildFilterBar(),
                Expanded(
                  child: _certificates.isEmpty
                      ? _buildEmptyState()
                      : isDesktop
                      ? _buildDataTable()
                      : _buildMobileList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCertificate,
        backgroundColor: const Color(0xFFD4AF37),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'ADD CERTIFICATE',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCertificates,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37),
            const Color(0xFFD4AF37).withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            const Icon(Icons.verified_user, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Certificate Tracking',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Manage jewellery certificates & certifications',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  filter.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedFilter = filter);
                  _loadCertificates();
                },
                selectedColor: const Color(0xFFD4AF37),
                backgroundColor: isDark
                    ? const Color(0xFF0F172A)
                    : Colors.grey[100],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Issuer')),
              DataColumn(label: Text('Product ID')),
              DataColumn(label: Text('Issue Date')),
              DataColumn(label: Text('Expiry')),
              DataColumn(label: Text('Valuation')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _certificates.map((cert) {
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cert.type.icon, size: 16, color: cert.type.color),
                        const SizedBox(width: 8),
                        Text(cert.type.displayName),
                      ],
                    ),
                  ),
                  DataCell(Text(cert.issuer)),
                  DataCell(
                    Text(
                      cert.huid ?? cert.productId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(Text(dateFormat.format(cert.issueDate))),
                  DataCell(
                    Text(
                      cert.expiryDate != null
                          ? dateFormat.format(cert.expiryDate!)
                          : '—',
                    ),
                  ),
                  DataCell(
                    Text(
                      cert.valuationPaisa > 0
                          ? '₹${cert.displayValuation.toStringAsFixed(0)}'
                          : '—',
                    ),
                  ),
                  DataCell(_buildStatusBadge(cert)),
                  DataCell(
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () => _deleteCertificate(cert),
                      tooltip: 'Delete',
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(JewelleryCertificate cert) {
    final String label;
    final Color color;

    if (cert.isExpired) {
      label = 'Expired';
      color = Colors.red;
    } else if (cert.isExpiringSoon) {
      label = 'Expiring Soon';
      color = Colors.orange;
    } else if (!cert.isActive) {
      label = 'Inactive';
      color = Colors.grey;
    } else {
      label = 'Active';
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    final dateFormat = DateFormat('dd MMM yyyy');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _certificates.length,
      itemBuilder: (context, index) {
        final cert = _certificates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: cert.isExpired ? Colors.red : Colors.grey[200]!,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(cert.type.icon, size: 20, color: cert.type.color),
                    const SizedBox(width: 8),
                    Text(
                      cert.type.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    _buildStatusBadge(cert),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Issuer', cert.issuer),
                _buildInfoRow('Product', cert.huid ?? cert.productId),
                _buildInfoRow('Issued', dateFormat.format(cert.issueDate)),
                if (cert.expiryDate != null)
                  _buildInfoRow('Expires', dateFormat.format(cert.expiryDate!)),
                if (cert.valuationPaisa > 0)
                  _buildInfoRow(
                    'Valuation',
                    '₹${cert.displayValuation.toStringAsFixed(0)}',
                  ),
                if (cert.notes != null && cert.notes!.isNotEmpty)
                  _buildInfoRow('Notes', cert.notes!),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red,
                    ),
                    onPressed: () => _deleteCertificate(cert),
                    tooltip: 'Delete',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No certificates tracked yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add certificates for your jewellery items',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addCertificate,
            icon: const Icon(Icons.add),
            label: const Text('ADD CERTIFICATE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for adding a new certificate
class _AddCertificateDialog extends StatefulWidget {
  final String tenantId;
  final Future<void> Function(JewelleryCertificate certificate) onSave;

  const _AddCertificateDialog({required this.tenantId, required this.onSave});

  @override
  State<_AddCertificateDialog> createState() => _AddCertificateDialogState();
}

class _AddCertificateDialogState extends State<_AddCertificateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productIdController = TextEditingController();
  final _huidController = TextEditingController();
  final _issuerController = TextEditingController();
  final _documentUrlController = TextEditingController();
  final _valuationController = TextEditingController();
  final _notesController = TextEditingController();

  CertificateType _selectedType = CertificateType.hallmark;
  DateTime _issueDate = DateTime.now();
  DateTime? _expiryDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _productIdController.dispose();
    _huidController.dispose();
    _issuerController.dispose();
    _documentUrlController.dispose();
    _valuationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Parse valuation to integer paise
      final valuationText = _valuationController.text.trim();
      final valuationPaisa = valuationText.isNotEmpty
          ? (double.tryParse(valuationText) ?? 0) * 100
          : 0;

      final certificate = JewelleryCertificate(
        id: RidGenerator.next(widget.tenantId),
        tenantId: widget.tenantId,
        productId: _productIdController.text.trim(),
        huid: _huidController.text.trim().isEmpty
            ? null
            : _huidController.text.trim(),
        type: _selectedType,
        issuer: _issuerController.text.trim(),
        issueDate: _issueDate,
        expiryDate: _expiryDate,
        documentUrl: _documentUrlController.text.trim().isEmpty
            ? null
            : _documentUrlController.text.trim(),
        valuationPaisa: valuationPaisa.round(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
        synced: false,
      );

      await widget.onSave(certificate);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save certificate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate({required bool isExpiry}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpiry
          ? (_expiryDate ?? DateTime.now().add(const Duration(days: 365)))
          : _issueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          _expiryDate = picked;
        } else {
          _issueDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return AlertDialog(
      title: const Text('Add Certificate'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CertificateType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Certificate Type',
                    border: OutlineInputBorder(),
                  ),
                  items: CertificateType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(type.icon, size: 18, color: type.color),
                          const SizedBox(width: 8),
                          Text(type.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedType = v);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _productIdController,
                  decoration: const InputDecoration(
                    labelText: 'Product ID *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _huidController,
                  decoration: const InputDecoration(
                    labelText: 'HUID (optional)',
                    border: OutlineInputBorder(),
                    hintText: '6-character BIS HUID',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _issuerController,
                  decoration: const InputDecoration(
                    labelText: 'Issuer *',
                    border: OutlineInputBorder(),
                    hintText: 'Issuing authority or organization',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isExpiry: false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Issue Date *',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(dateFormat.format(_issueDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isExpiry: true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Expiry Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _expiryDate != null
                                ? dateFormat.format(_expiryDate!)
                                : 'Not set',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _documentUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Document URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valuationController,
                  decoration: const InputDecoration(
                    labelText: 'Valuation (₹, optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 50000',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('SAVE'),
        ),
      ],
    );
  }
}
