import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/service_locator.dart';
import '../services/patient_registry_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _patientSearchProvider = StateProvider<String>((ref) => '');

final _patientsProvider = FutureProvider.family<List<PatientRecord>, String>(
  (ref, search) => sl<PatientRegistryService>().listPatients(search: search),
);

final _patientHistoryProvider =
    FutureProvider.family<List<PatientPurchaseRecord>, String>(
      (ref, patientId) =>
          sl<PatientRegistryService>().getPurchaseHistory(patientId),
    );

// ─── Screen ───────────────────────────────────────────────────────────────────

class PatientRegistryScreen extends ConsumerStatefulWidget {
  const PatientRegistryScreen({super.key});

  @override
  ConsumerState<PatientRegistryScreen> createState() =>
      _PatientRegistryScreenState();
}

class _PatientRegistryScreenState extends ConsumerState<PatientRegistryScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(_patientSearchProvider);
    final patientsAsync = ref.watch(_patientsProvider(search));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Registry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_patientsProvider(search)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Add Patient'),
        onPressed: () => _showPatientForm(context),
      ),
      body: Center(
        child: BoundedBox(
          maxWidth: 800,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(_patientSearchProvider.notifier).state =
                                  '';
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (v) =>
                      ref.read(_patientSearchProvider.notifier).state = v,
                ),
              ),
              Expanded(
                child: patientsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (patients) {
                    if (patients.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No patients found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: patients.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) =>
                          _PatientTile(patient: patients[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatientForm(BuildContext context, [PatientRecord? existing]) {
    if (context.isDesktop || context.isTablet) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
            child: _PatientFormWidget(
              existing: existing,
              onSaved: () {
                final search = ref.read(_patientSearchProvider);
                ref.invalidate(_patientsProvider(search));
              },
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PatientFormSheet(
          existing: existing,
          onSaved: () {
            final search = ref.read(_patientSearchProvider);
            ref.invalidate(_patientsProvider(search));
          },
        ),
      );
    }
  }
}

// ─── Patient List Tile ────────────────────────────────────────────────────────

class _PatientTile extends ConsumerWidget {
  final PatientRecord patient;
  const _PatientTile({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.teal.shade100,
        child: Text(
          patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.teal.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        patient.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(patient.phone),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showDetail(context, ref, patient),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, PatientRecord p) {
    if (context.isDesktop || context.isTablet) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
            child: _PatientDetailWidget(patient: p),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PatientDetailSheet(patient: p),
      );
    }
  }
}

// ─── Patient Detail Widget ────────────────────────────────────────────────────

class _PatientDetailWidget extends ConsumerWidget {
  final PatientRecord patient;
  final ScrollController? scrollController;
  const _PatientDetailWidget({required this.patient, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_patientHistoryProvider(patient.id));

    return Container(
      padding: const EdgeInsets.all(20),
      child: ListView(
        controller: scrollController,
        shrinkWrap: scrollController == null,
        children: [
          if (scrollController != null) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: TextStyle(
                        fontSize: responsiveValue<double>(
                          context,
                          mobile: 14.0,
                          tablet: 16.0,
                          desktop: 18.0,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      patient.phone,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoRow(icon: Icons.email, label: 'Email', value: patient.email),
          _InfoRow(
            icon: Icons.location_on,
            label: 'Address',
            value: patient.address,
          ),
          _InfoRow(
            icon: Icons.bloodtype,
            label: 'Blood Group',
            value: patient.bloodGroup,
          ),
          _InfoRow(
            icon: Icons.warning_amber,
            label: 'Allergies',
            value: patient.allergies,
          ),
          const Divider(height: 32),
          const Text(
            'Purchase History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load history: $e'),
            data: (history) {
              if (history.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No purchase history found.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return Column(
                children: history
                    .map(
                      (h) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.receipt_long,
                          color: Colors.teal,
                        ),
                        title: Text(h.invoiceNumber),
                        subtitle: Text(
                          h.productNames.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${h.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${h.date.day}/${h.date.month}/${h.date.year}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Patient Detail Sheet ─────────────────────────────────────────────────────

class _PatientDetailSheet extends ConsumerWidget {
  final PatientRecord patient;
  const _PatientDetailSheet({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _PatientDetailWidget(patient: patient, scrollController: ctrl),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _InfoRow({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          Expanded(child: Text(value!, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ─── Patient Form Widget ──────────────────────────────────────────────────────

class _PatientFormWidget extends StatefulWidget {
  final PatientRecord? existing;
  final VoidCallback onSaved;
  final ScrollController? scrollController;
  const _PatientFormWidget({
    this.existing,
    required this.onSaved,
    this.scrollController,
  });

  @override
  State<_PatientFormWidget> createState() => _PatientFormWidgetState();
}

class _PatientFormWidgetState extends State<_PatientFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _bloodGroupCtrl;
  late final TextEditingController _allergiesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _addressCtrl = TextEditingController(text: p?.address ?? '');
    _bloodGroupCtrl = TextEditingController(text: p?.bloodGroup ?? '');
    _allergiesCtrl = TextEditingController(text: p?.allergies ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _bloodGroupCtrl.dispose();
    _allergiesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final svc = sl<PatientRegistryService>();
      final now = DateTime.now();
      final record = PatientRecord(
        id: widget.existing?.id ?? '',
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        bloodGroup: _bloodGroupCtrl.text.trim().isEmpty
            ? null
            : _bloodGroupCtrl.text.trim(),
        allergies: _allergiesCtrl.text.trim().isEmpty
            ? null
            : _allergiesCtrl.text.trim(),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );
      if (widget.existing == null) {
        await svc.createPatient(record);
      } else {
        await svc.updatePatient(widget.existing!.id, record);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        controller: widget.scrollController,
        shrinkWrap: widget.scrollController == null,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom:
              (widget.scrollController != null
                  ? MediaQuery.of(context).viewInsets.bottom
                  : 0) +
              20,
        ),
        children: [
          if (widget.scrollController != null) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            widget.existing == null ? 'New Patient' : 'Edit Patient',
            style: TextStyle(
              fontSize: responsiveValue<double>(
                context,
                mobile: 14.0,
                tablet: 16.0,
                desktop: 18.0,
              ),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _FormField(
            ctrl: _nameCtrl,
            label: 'Full Name *',
            icon: Icons.person,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          _FormField(
            ctrl: _phoneCtrl,
            label: 'Phone *',
            icon: Icons.phone,
            keyboard: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Phone is required';
              if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) {
                return 'Enter a valid 10-digit phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _FormField(
            ctrl: _emailCtrl,
            label: 'Email',
            icon: Icons.email,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _FormField(
            ctrl: _addressCtrl,
            label: 'Address',
            icon: Icons.location_on,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _FormField(
            ctrl: _bloodGroupCtrl,
            label: 'Blood Group',
            icon: Icons.bloodtype,
          ),
          const SizedBox(height: 12),
          _FormField(
            ctrl: _allergiesCtrl,
            label: 'Known Allergies',
            icon: Icons.warning_amber,
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.existing == null
                          ? 'Register Patient'
                          : 'Update Patient',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Patient Form Sheet ───────────────────────────────────────────────────────

class _PatientFormSheet extends StatelessWidget {
  final PatientRecord? existing;
  final VoidCallback onSaved;
  const _PatientFormSheet({this.existing, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _PatientFormWidget(
          existing: existing,
          onSaved: onSaved,
          scrollController: ctrl,
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final int maxLines;
  final String? Function(String?)? validator;

  const _FormField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
