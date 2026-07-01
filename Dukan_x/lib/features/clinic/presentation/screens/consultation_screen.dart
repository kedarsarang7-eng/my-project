import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/clinic_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ConsultationScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const ConsultationScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // SOAP Notes Controllers
  final _subjectiveController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _assessmentController = TextEditingController();
  final _planController = TextEditingController();
  
  // Vitals
  final _bpController = TextEditingController();
  final _tempController = TextEditingController();
  final _weightController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _subjectiveController.dispose();
    _objectiveController.dispose();
    _assessmentController.dispose();
    _planController.dispose();
    _bpController.dispose();
    _tempController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveConsultation() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    final soapData = {
      'subjective': _subjectiveController.text,
      'objective': _objectiveController.text,
      'assessment': _assessmentController.text,
      'plan': _planController.text,
      'vitals': {
        'bloodPressure': _bpController.text,
        'temperature': _tempController.text,
        'weight': _weightController.text,
      }
    };
    
    final result = await ref.read(clinicRepositoryProvider).saveConsultation(widget.patientId, soapData);
    
    setState(() => _isSaving = false);
    
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${failure.message}')),
        );
      },
      (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consultation saved successfully!')),
        );
        Navigator.pop(context); // Go back
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Consultation: ${widget.patientName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Patient History',
            onPressed: () {
              // Navigate to patient history
            },
          ),
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'Order Labs',
            onPressed: () {
              // Navigate to lab order screen
            },
          )
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vitals Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vitals', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _bpController,
                            decoration: const InputDecoration(labelText: 'BP (mmHg)', border: OutlineInputBorder()),
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(
                            controller: _tempController,
                            decoration: const InputDecoration(labelText: 'Temp (°F)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(
                            controller: _weightController,
                            decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          )),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // SOAP Notes
              _buildSoapField('Subjective (Symptoms)', _subjectiveController),
              const SizedBox(height: 16),
              _buildSoapField('Objective (Signs/Exam)', _objectiveController),
              const SizedBox(height: 16),
              _buildSoapField('Assessment (Diagnosis)', _assessmentController),
              const SizedBox(height: 16),
              _buildSoapField('Plan (Treatment/Rx)', _planController, lines: 5),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveConsultation,
                  child: _isSaving 
                      ? const CircularProgressIndicator()
                      : const Text('Save & Generate Prescription'),
                ),
              )
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSoapField(String label, TextEditingController controller, {int lines = 3}) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
