/// Create Service Job Screen
/// Form for creating a new service/repair job
library;

import 'package:flutter/material.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/services/auth_service.dart';
import '../../models/service_job.dart';
import '../../services/service_job_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CreateServiceJobScreen extends StatefulWidget {
  const CreateServiceJobScreen({super.key});

  @override
  State<CreateServiceJobScreen> createState() => _CreateServiceJobScreenState();
}

class _CreateServiceJobScreenState extends State<CreateServiceJobScreen> {
  final _formKey = GlobalKey<FormState>();
  late ServiceJobService _service;
  bool _isLoading = false;

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _imeiController = TextEditingController();
  final _problemController = TextEditingController();

  DeviceType _deviceType = DeviceType.mobile;
  ServicePriority _priority = ServicePriority.normal;
  DateTime? _expectedDelivery;
  final List<String> _selectedSymptoms = [];

  final List<String> _commonSymptoms = [
    'No Power',
    'Screen Crack',
    'Battery Issue',
    'Charging Problem',
    'Speaker Issue',
    'Camera Issue',
    'Software Issue',
    'Water Damage',
  ];

  @override
  void initState() {
    super.initState();
    _service = ServiceJobService(AppDatabase.instance);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _imeiController.dispose();
    _problemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Service Job'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveJob,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection('Customer', Icons.person, [
                    _buildField(
                      _customerNameController,
                      'Name*',
                      Icons.person,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    _buildField(
                      _customerPhoneController,
                      'Phone*',
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v?.length ?? 0) < 10 ? 'Invalid' : null,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('Device', Icons.devices, [
                    DropdownButtonFormField<DeviceType>(
                      value: _deviceType,
                      decoration: const InputDecoration(
                        labelText: 'Device Type',
                        border: OutlineInputBorder(),
                      ),
                      items: DeviceType.values
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _deviceType = v!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            _brandController,
                            'Brand*',
                            Icons.business,
                            validator: (v) =>
                                v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            _modelController,
                            'Model*',
                            Icons.phone_android,
                            validator: (v) =>
                                v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField(_imeiController, 'IMEI/Serial', Icons.qr_code),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('Problem', Icons.warning_amber, [
                    _buildField(
                      _problemController,
                      'Description*',
                      Icons.description,
                      maxLines: 3,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Symptoms:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _commonSymptoms
                          .map(
                            (s) => FilterChip(
                              label: Text(s),
                              selected: _selectedSymptoms.contains(s),
                              onSelected: (sel) => setState(() {
                                sel
                                    ? _selectedSymptoms.add(s)
                                    : _selectedSymptoms.remove(s);
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<ServicePriority>(
                          value: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                          ),
                          items: ServicePriority.values
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.displayName),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _priority = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Expected Delivery',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _expectedDelivery != null
                                  ? '${_expectedDelivery!.day}/${_expectedDelivery!.month}'
                                  : 'Select',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveJob,
                    icon: const Icon(Icons.save),
                    label: const Text('Create Job'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null) setState(() => _expectedDelivery = date);
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = AuthService().currentUser;
      if (user == null) throw Exception('Not logged in');
      await _service.createServiceJob(
        userId: user.uid,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        deviceType: _deviceType,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        imeiOrSerial: _imeiController.text.trim().isNotEmpty
            ? _imeiController.text.trim()
            : null,
        problemDescription: _problemController.text.trim(),
        symptoms: _selectedSymptoms,
        priority: _priority,
        expectedDelivery: _expectedDelivery,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job created'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
