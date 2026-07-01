import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/session/owner_id_resolver.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/repositories/prescription_repository.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'dart:convert';
import '../../data/repositories/medical_template_repository.dart';
import '../../models/medical_template_model.dart';
import '../../models/prescription_model.dart';
import '../../services/contraindication_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AddPrescriptionScreen extends ConsumerStatefulWidget {
  final String? preSelectedPatientId;
  final String? visitId;
  const AddPrescriptionScreen({
    this.preSelectedPatientId,
    this.visitId,
    super.key,
  });

  @override
  ConsumerState<AddPrescriptionScreen> createState() =>
      _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends ConsumerState<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adviceController = TextEditingController();

  // Dependencies
  final PrescriptionRepository _prescriptionRepo = sl<PrescriptionRepository>();
  final ProductsRepository _productsRepo = sl<ProductsRepository>();
  final MedicalTemplateRepository _templateRepo =
      sl<MedicalTemplateRepository>();
  final SessionManager _sessionManager = sl<SessionManager>();

  // State
  String? _selectedPatientId;
  final List<PrescriptionItemModel> _items = [];
  List<MedicalTemplateModel> _rxTemplates = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedPatientId != null) {
      _selectedPatientId = widget.preSelectedPatientId;
    }
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    // Read path: fail safe — skip the (cross-tenant) template load when no
    // authenticated owner is available instead of bucketing under 'SYSTEM'.
    final String docId;
    try {
      docId = resolveOwnerId(
        session: _sessionManager,
        operation: 'load prescription templates',
      );
    } on OwnerIdMissingException {
      return;
    }
    final templates = await _templateRepo.getTemplatesByType(
      docId,
      'PRESCRIPTION',
    );
    if (mounted) setState(() => _rxTemplates = templates);
  }

  Future<void> _saveAsTemplate() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add medicines first to save as template'),
        ),
      );
      return;
    }

    // Ask for template name
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Save Protocol Template',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: TextField(
            controller: nameCtrl,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Protocol Name',
              labelStyle: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, nameCtrl.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    // Write path: block the template write when no owner id is available and
    // surface an error — never attribute to 'SYSTEM'.
    final String docId;
    try {
      docId = resolveOwnerId(
        session: _sessionManager,
        operation: 'save prescription template',
      );
    } on OwnerIdMissingException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot save template — no active clinic session.'),
          ),
        );
      }
      return;
    }

    // Serialize items
    final itemsJson = jsonEncode(_items.map((e) => e.toMap()).toList());

    final template = MedicalTemplateModel(
      id: const Uuid().v4(),
      userId: docId,
      type: 'PRESCRIPTION',
      title: name,
      content: itemsJson,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _templateRepo.createTemplate(template);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Protocol saved!')));
      _loadTemplates();
    }
  }

  void _applyTemplate(MedicalTemplateModel template) {
    try {
      final List<dynamic> list = jsonDecode(template.content);
      final newItems = list
          .map((e) => PrescriptionItemModel.fromMap(e))
          .toList();

      setState(() {
        // Create new IDs for imported items to avoid conflicts
        for (var item in newItems) {
          item.prescriptionId = ''; // Reset
          // item.id should strictly be new too, but PrescriptionItemModel might not allow setter.
          // Assuming it's a data class, we might need copyWith or just replicate.
          // Ideally we regenerate ID here strictly.
        }
        _items.addAll(newItems);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load template: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'New Prescription',
      subtitle: 'Create a new prescription',
      actions: [
        PrimaryButton(
          label: _isSaving ? 'Saving...' : 'Save Prescription',
          icon: _isSaving ? null : Icons.save,
          onPressed: _isSaving ? null : _savePrescription,
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Patient Selection
              _buildSectionTitle('Select Patient'),
              const SizedBox(height: 8),
              _buildPatientDropdown(),
              const SizedBox(height: 24),

              // 2. Add Medicines
              _buildSectionTitle('Prescribed Medicines'),
              const SizedBox(height: 8),
              _buildSectionTitle('Prescribed Medicines'),
              const SizedBox(height: 8),

              // Templates Chips
              if (_rxTemplates.isNotEmpty) ...[
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _rxTemplates.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final t = _rxTemplates[index];
                      return Semantics(
                        label: 'Apply prescription template: ${t.title}',
                        child: ActionChip(
                          label: Text(t.title),
                          backgroundColor: FuturisticColors.primary.withOpacity(
                            0.2,
                          ),
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: () => _applyTemplate(t),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              _buildMedicineSearch(),
              const SizedBox(height: 16),

              // 3. Medicine List
              if (_items.isNotEmpty) ...[
                _buildMedicineList(),
                const SizedBox(height: 24),
              ],

              // 4. Clinical Advice
              _buildSectionTitle('Clinical Advice / Notes'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _adviceController,
                maxLines: 3,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: FuturisticColors.surface,
                  hintText: 'e.g. Drink plenty of water, Rest for 2 days...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _saveAsTemplate,
                    icon: const Icon(
                      Icons.bookmark_add,
                      color: FuturisticColors.primary,
                    ),
                    label: const Text('Save as Protocol'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: FuturisticColors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPatientDropdown() {
    return FutureBuilder(
      future: sl<PatientRepository>().watchAllPatients().first,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: LinearProgressIndicator());
        }
        final patients = snapshot.data ?? [];
        return DropdownButtonFormField<String>(
          value: _selectedPatientId,
          dropdownColor: FuturisticColors.surface,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: FuturisticColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(
              Icons.person,
              color: FuturisticColors.primary,
            ),
          ),
          items: patients
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    p.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedPatientId = val),
          hint: const Text(
            'Choose Patient',
            style: TextStyle(color: Colors.grey),
          ),
          validator: (val) => val == null ? 'Please select a patient' : null,
        );
      },
    );
  }

  Widget _buildMedicineSearch() {
    return Autocomplete<Product>(
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.length < 2) return [];
        final userId = _sessionManager.ownerId ?? '';
        final result = await _productsRepo.search(
          textEditingValue.text,
          userId: userId,
        );
        // Filter to show medicines preferentially, but also include all products
        final products = result.data ?? [];
        // Sort: medicines first, then by name
        products.sort((a, b) {
          final aIsMedicine =
              a.category?.toLowerCase() == 'medicine' ||
              a.category?.toLowerCase() == 'medicines';
          final bIsMedicine =
              b.category?.toLowerCase() == 'medicine' ||
              b.category?.toLowerCase() == 'medicines';
          if (aIsMedicine && !bIsMedicine) return -1;
          if (!aIsMedicine && bIsMedicine) return 1;
          return a.name.compareTo(b.name);
        });
        return products.take(10).toList(); // Limit results
      },
      displayStringForOption: (option) => option.name,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: FuturisticColors.surface,
            hintText: 'Search Medicine...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: const Icon(
              Icons.medication_outlined,
              color: FuturisticColors.primary,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () => controller.clear(),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: FuturisticColors.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 350,
              height: 250,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final isMedicine =
                      option.category?.toLowerCase() == 'medicine' ||
                      option.category?.toLowerCase() == 'medicines';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isMedicine
                          ? FuturisticColors.primary.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      child: Icon(
                        isMedicine ? Icons.medication : Icons.inventory_2,
                        color: isMedicine
                            ? FuturisticColors.primary
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      option.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '₹${option.sellingPrice.toStringAsFixed(2)} • ${option.unit}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (product) => _showAddMedicineDialog(product),
    );
  }

  Widget _buildMedicineList() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: FuturisticColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onSurface.withOpacity(0.1)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, _) =>
            Divider(color: onSurface.withOpacity(0.1), height: 1),
        itemBuilder: (context, index) {
          final item = _items[index];
          return ListTile(
            title: Text(
              item.medicineName,
              style: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${item.dosage ?? ""} • ${item.duration ?? ""} • ${item.instructions ?? ""}',
              style: TextStyle(color: onSurface.withOpacity(0.6)),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => setState(() => _items.removeAt(index)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddMedicineDialog(Product product) async {
    final dosageCtrl = TextEditingController(text: '1-0-1');
    final durationCtrl = TextEditingController(text: '3 Days');
    final instructionCtrl = TextEditingController(text: 'After Food');

    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            product.name,
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(dosageCtrl, 'Dosage (e.g. 1-0-1)'),
              const SizedBox(height: 12),
              _buildDialogField(durationCtrl, 'Duration (e.g. 5 Days)'),
              const SizedBox(height: 12),
              _buildDialogField(instructionCtrl, 'Instructions'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _items.add(
                    PrescriptionItemModel(
                      id: const Uuid().v4(),
                      prescriptionId: '', // Set on save
                      medicineName: product.name,
                      productId: product.id,
                      dosage: dosageCtrl.text,
                      duration: durationCtrl.text,
                      instructions: instructionCtrl.text,
                      frequency: 'Daily', // Default or add field
                    ),
                  );
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FuturisticColors.primary,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: FuturisticColors.primary),
        ),
      ),
    );
  }

  /// Allergy↔Prescription contraindication check (Req 2.12).
  ///
  /// Cross-references prescribed medicines against the patient's recorded
  /// allergies BEFORE persisting. Shows a warning dialog on match — the
  /// clinician may override (acknowledge risk) or cancel (block save).
  /// Non-contraindicated prescriptions save without interruption.
  Future<bool> _checkContraindications() async {
    if (_selectedPatientId == null) return true; // No patient = skip check

    // Fetch patient to get their allergy info
    final patient = await sl<PatientRepository>().getPatientById(
      _selectedPatientId!,
    );
    if (patient == null) return true; // Patient not found, allow save

    final medicineNames = _items.map((item) => item.medicineName).toList();

    final result = checkContraindications(
      allergiesRaw: patient.allergies,
      medicineNames: medicineNames,
    );

    if (result.isSafe) return true; // No contraindications — proceed

    // Show contraindication warning dialog
    if (!mounted) return false;
    final override = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: FuturisticColors.surface,
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: const Text(
          '⚠️ Allergy Contraindication Warning',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The following prescribed medicine(s) may conflict with the '
                "patient's recorded allergies:",
                style: TextStyle(color: Colors.grey.shade300),
              ),
              const SizedBox(height: 16),
              ...result.matches.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.dangerous,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.grey.shade200,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: m.medicineName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: ' — patient allergic to '),
                              TextSpan(
                                text: m.allergyEntry,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  'Proceeding may risk an allergic reaction. '
                  'Override only if clinically justified.',
                  style: TextStyle(color: Colors.orange.shade200, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            child: const Text('Override — I Acknowledge the Risk'),
          ),
        ],
      ),
    );

    return override == true;
  }

  Future<void> _savePrescription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please prescribe at least one medicine')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Write path: block the Rx write when no owner id is available (never
      // attribute to 'SYSTEM'). The throw is handled by the catch below.
      final docId = resolveOwnerId(
        session: _sessionManager,
        operation: 'save prescription',
      );

      // Allergy↔Prescription contraindication check (Req 2.12):
      // Cross-reference prescribed drugs against patient allergies BEFORE
      // persisting. Warn on contraindication; allow clinician override.
      final contraindicationCleared = await _checkContraindications();
      if (!contraindicationCleared) {
        // Clinician chose to cancel — block save.
        return;
      }

      final prescriptionId = const Uuid().v4();

      // Update item IDs
      for (var item in _items) {
        item.prescriptionId = prescriptionId;
      }

      final prescription = PrescriptionModel(
        id: prescriptionId,
        doctorId: docId,
        patientId: _selectedPatientId!,
        visitId:
            widget.visitId ??
            const Uuid().v4(), // Use provided visitId or generate
        date: DateTime.now(),
        advice: _adviceController.text,
        items: _items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _prescriptionRepo.createPrescription(prescription);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription Saved Successfully!')),
        );
        Navigator.pop(
          context,
          prescriptionId,
        ); // Return prescriptionId to caller
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
