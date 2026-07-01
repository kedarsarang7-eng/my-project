// ============================================================================
// DRUG LICENSE FIELD — pharmacy settings input (Requirement 14)
// ============================================================================
// Self-contained, pharmacy-only widget that lets the tenant view and edit the
// Drug License Number shown on the pharmacy invoice header.
//
//   R14.1 : accepts an alphanumeric value of 1 to 50 characters.
//   R14.4 : an empty or too-long value is rejected; the previously saved value
//           is retained and a length-constraint message is shown.
//
// Persistence + validation live in `DrugLicenseService` / `DrugLicense`; this
// widget only wires them to the UI. It is embedded only for the pharmacy
// business type, so the shared settings screen is behaviourally unchanged for
// the other 18 verticals (Requirement 5.3).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/drug_license_service.dart';
import '../utils/drug_license.dart';

class DrugLicenseField extends StatefulWidget {
  /// Service used to load/save the value. Injectable for tests.
  final DrugLicenseService? service;

  /// Render in dark mode to match the host screen.
  final bool isDark;

  const DrugLicenseField({super.key, this.service, this.isDark = false});

  @override
  State<DrugLicenseField> createState() => _DrugLicenseFieldState();
}

class _DrugLicenseFieldState extends State<DrugLicenseField> {
  late final DrugLicenseService _service;
  final TextEditingController _controller = TextEditingController();

  /// The last successfully saved value, retained so a rejected edit can be
  /// rolled back to it (R14.4).
  String? _savedValue;
  bool _loading = true;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DrugLicenseService();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _service.getDrugLicenseNumber();
      if (!mounted) return;
      setState(() {
        _savedValue = value;
        _controller.text = value ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      final result = await _service.setDrugLicenseNumber(_controller.text);
      if (!mounted) return;
      if (result.saved) {
        setState(() {
          _savedValue = result.value;
          _controller.text = result.value ?? '';
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drug License Number saved.')),
        );
      } else {
        // Rejected: retain the previously saved value and show the constraint.
        setState(() {
          _errorText = result.error;
          _controller.text = _savedValue ?? '';
          _saving = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Could not save Drug License Number.';
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: DrugLicense.maxLength,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Drug License Number',
                      hintText: 'e.g. MH20B123456',
                      errorText: _errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
    );
  }
}
