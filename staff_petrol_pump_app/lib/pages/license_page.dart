import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

class LicensePage extends StatefulWidget {
  const LicensePage({super.key});

  @override
  State<LicensePage> createState() => _LicensePageState();
}

class _LicensePageState extends State<LicensePage> {
  final _licenseKeyController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    setState(() => _loading = true);
    try {
      final client = ApiClient();
      final response = await client.post(
        ApiEndpoints.validateLicense,
        data: {
          'licenseKey': _licenseKeyController.text.trim().toUpperCase(),
        },
      );
      final payload = response.data is Map<String, dynamic>
          ? (response.data['data'] as Map<String, dynamic>? ?? response.data as Map<String, dynamic>)
          : <String, dynamic>{};
      setState(() => _result = Map<String, dynamic>.from(payload));
    } catch (e) {
      setState(() {
        _result = {
          'status': 'ERROR',
          'message': e.toString(),
        };
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    setState(() => _loading = true);
    try {
      final client = ApiClient();
      final response = await client.post(
        ApiEndpoints.activateLicense,
        data: {
          'licenseKey': _licenseKeyController.text.trim().toUpperCase(),
        },
      );
      final payload = response.data is Map<String, dynamic>
          ? (response.data['data'] as Map<String, dynamic>? ?? response.data as Map<String, dynamic>)
          : <String, dynamic>{};
      setState(() => _result = Map<String, dynamic>.from(payload));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('License active. Login now.')),
        );
      }
    } catch (e) {
      setState(() {
        _result = {
          'status': 'ERROR',
          'message': e.toString(),
        };
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter License Key')),
      body: Center(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _licenseKeyController,
                decoration: const InputDecoration(labelText: 'License Key'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _validate,
                      child: const Text('Validate'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _activate,
                      child: const Text('Activate'),
                    ),
                  ),
                ],
              ),
              if (_result != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFF2F4FF),
                  ),
                  child: Text(_result.toString()),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
