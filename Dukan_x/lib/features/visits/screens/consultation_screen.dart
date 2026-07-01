import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../models/visit.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/prescription.dart';
import '../../../../core/repository/clinical_prescription_repository.dart';
import '../../../../core/repository/visits_repository.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/di/service_locator.dart';
import 'clinic_invoice_preview_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ConsultationScreen extends ConsumerStatefulWidget {
  final String visitId;
  const ConsultationScreen({super.key, required this.visitId});

  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  // Controllers
  final _symptomsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();

  // Medicines List (Local State)
  // Simple structure: Name, Dosage, Frequency, Days
  final List<Map<String, String>> _medicines = [];

  bool _isLoading = true;
  Visit? _visit;

  @override
  void initState() {
    super.initState();
    _loadVisit();
  }

  Future<void> _loadVisit() async {
    final result = await sl<VisitsRepository>().getVisitById(widget.visitId);
    if (result.isSuccess && result.data != null) {
      final visit = result.data!;

      // Load existing medicines if prescription exists
      List<Map<String, String>> existingMeds = [];
      if (visit.prescriptionId != null && visit.prescriptionId!.isNotEmpty) {
        final rxResult = await sl<ClinicalPrescriptionRepository>()
            .getByVisitId(visit.id);
        if (rxResult.isSuccess && rxResult.data != null) {
          final meds = rxResult.data!.medicines;
          existingMeds = meds
              .map(
                (m) => {
                  'name': m.name,
                  'dosage': m.dosage,
                  'frequency': m.timing,
                  'duration': m.duration,
                },
              )
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _visit = visit;
          _isLoading = false;
          // Pre-fill
          _symptomsController.text = _visit!.symptoms.join(', ');
          _diagnosisController.text = _visit!.diagnosis;
          _notesController.text = _visit!.notes;

          _medicines.clear();
          _medicines.addAll(existingMeds);
        });
      }
    } else {
      // Handle error
    }
  }

  void _addMedicine() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMedicineSheet(
        onAdd: (med) {
          setState(() {
            _medicines.add(med);
          });
        },
      ),
    );
  }

  Future<void> _saveAndClose() async {
    await _saveConsultation(shouldBill: false);
  }

  Future<void> _saveAndBill() async {
    await _saveConsultation(shouldBill: true);
  }

  Future<void> _saveConsultation({required bool shouldBill}) async {
    if (_visit == null) return;

    // 1. Create Medicine Items
    final medicines = _medicines
        .map(
          (m) => MedicineItem(
            name: m['name']!,
            dosage: m['dosage']!,
            timing: m['frequency']!, // Using frequency as timing for now
            duration: m['duration']!,
            instructions: '',
          ),
        )
        .toList();

    // 2. Create Prescription Object
    final now = DateTime.now();
    final prescriptionId = 'rx_${now.millisecondsSinceEpoch}';

    final prescription = Prescription(
      id: prescriptionId,
      visitId: _visit!.id,
      patientId: _visit!.patientId,
      doctorId: _visit!.doctorId, // or current user
      date: now,
      medicines: medicines,
      advice: _notesController.text, // Using notes as advice
      createdAt: now,
      updatedAt: now,
    );

    // 3. Save Prescription
    final repo = sl<ClinicalPrescriptionRepository>();
    await repo.createPrescription(prescription);

    // 4. Update Visit
    final visitRepo = sl<VisitsRepository>();
    final updatedVisit = _visit!.copyWith(
      symptoms: _symptomsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),

      diagnosis: _diagnosisController.text,
      notes: _notesController.text,
      prescriptionId: prescriptionId,
      status: shouldBill
          ? 'completed'
          : 'in_progress', // Complete if billing? Or just updated.
    );

    await visitRepo.updateVisit(updatedVisit);

    if (shouldBill && mounted) {
      // 5. Generate Bill
      final billId = const Uuid().v4();
      final bill = Bill(
        id: billId,
        invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        customerId: _visit!.patientId,
        customerName: 'Patient',
        date: DateTime.now(),
        items: [
          BillItem(
            productId: 'SERVICE_CONSULT',
            productName: 'Consultation Fee',
            qty: 1,
            price: 500.0,
            totalOverride: 500.0,
            unit: 'session',
            gstRate: 0,
          ),
        ],
        subtotal: 500.0,
        grandTotal: 500.0,
        status: 'Unpaid',
        paymentType: 'Cash',
        visitId: _visit!.id,
        prescriptionId: prescriptionId,
        businessType: 'CLINIC',
      );

      await sl<BillsRepository>().createBill(bill);

      if (mounted) {
        Navigator.pop(context); // Close Consultation
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicInvoicePreviewScreen(billId: billId),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation saved successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: FuturisticColors.backgroundDark,
        body: BoundedBox(
          maxWidth: 800,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FuturisticColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Consultation',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () {
              // History
            },
            child: Text(
              'History',
              style: GoogleFonts.outfit(color: FuturisticColors.neonBlue),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Patient Vitals (Collapsed)
            _buildVitalsCard(),
            const SizedBox(height: 16),

            // 2. Clinical Notes
            _buildSection(
              title: 'Symptoms',
              icon: Icons.personal_injury,
              child: _buildTextField(_symptomsController, 'Fever, Cough...'),
            ),
            const SizedBox(height: 16),

            _buildSection(
              title: 'Diagnosis',
              icon: Icons.health_and_safety,
              child: _buildTextField(_diagnosisController, 'Viral Infection'),
            ),
            const SizedBox(height: 16),

            // 3. Prescription Pad
            _buildPrescriptionPad(),
            const SizedBox(height: 16),

            _buildSection(
              title: 'Private Notes',
              icon: Icons.note_outlined,
              child: _buildTextField(
                _notesController,
                'Internal notes...',
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 32),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveAndClose,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Save & Close',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveAndBill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FuturisticColors.neonBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Generate Bill',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildVital('BP', '120/80', 'mmHg'),
          _buildVital('Pulse', '72', 'bpm'),
          _buildVital('Temp', '98.6', '°F'),
          _buildVital('Weight', '70', 'kg'),
        ],
      ),
    );
  }

  Widget _buildVital(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: FuturisticColors.neonBlue),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white38),
        ),
      ),
    );
  }

  Widget _buildPrescriptionPad() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prescription / Medicines',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _addMedicine,
                icon: const Icon(
                  Icons.add_circle,
                  color: FuturisticColors.neonBlue,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          if (_medicines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No medicines added',
                  style: GoogleFonts.outfit(color: Colors.white38),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _medicines.length,
              itemBuilder: (context, index) {
                final med = _medicines[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medication, color: Colors.white54),
                  title: Text(
                    med['name']!,
                    style: GoogleFonts.outfit(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${med['dosage']} • ${med['frequency']} • ${med['duration']}',
                    style: GoogleFonts.outfit(color: Colors.white38),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _medicines.removeAt(index);
                      });
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AddMedicineSheet extends StatefulWidget {
  final Function(Map<String, String>) onAdd;
  const _AddMedicineSheet({required this.onAdd});

  @override
  State<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<_AddMedicineSheet> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _freqCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Medicine',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInput('Medicine Name (e.g. Paracetamol)', _nameCtrl),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInput('Dosage (500mg)', _dosageCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildInput('Frequency (1-0-1)', _freqCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          _buildInput('Duration (3 days)', _durationCtrl),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_nameCtrl.text.isNotEmpty) {
                  widget.onAdd({
                    'name': _nameCtrl.text,
                    'dosage': _dosageCtrl.text,
                    'frequency': _freqCtrl.text,
                    'duration': _durationCtrl.text,
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FuturisticColors.neonBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Add to Prescription',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white38),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
