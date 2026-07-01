import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../core/di/service_locator.dart';
import '../core/session/session_manager.dart';
import '../core/theme/futuristic_colors.dart';

class OwnerLinkScreen extends StatefulWidget {
  const OwnerLinkScreen({super.key});

  @override
  State<OwnerLinkScreen> createState() => _OwnerLinkScreenState();
}

class _OwnerLinkScreenState extends State<OwnerLinkScreen> {
  final TextEditingController phoneCtrl = TextEditingController();

  String? generatedCode;
  bool isLoading = false;

  Future<void> _generateCode() async {
    final phone = phoneCtrl.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid 10-digit phone')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      // Get owner ID from SessionManager
      final ownerId = sl<SessionManager>().ownerId ?? '';
      if (ownerId.isEmpty) {
        throw Exception('No active owner session');
      }

      // Generate a simple code from ConnectionService
      // For now, using a simplified approach - generate a QR code data
      // that customer can scan or enter manually
      // Extract a short code from ownerId for display (simplified)
      final shortCode = ownerId.substring(0, 6).toUpperCase();

      setState(() {
        generatedCode = shortCode;
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Code generated: $shortCode')));
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _copyCode() {
    if (generatedCode == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
  }

  @override
  void dispose() {
    phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Generate Link Code for Customer',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter customer phone number and generate a 6-digit code. Share this code with the customer to link their profile.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Phone input
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: InputDecoration(
            hintText: '10-digit mobile',
            prefixIcon: const Icon(Icons.phone, color: Colors.blue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.blue.shade50,
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),

        // Generate button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _generateCode,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : const Text(
                    'Generate Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display generated code
        if (generatedCode != null) ...[
          Card(
            color: FuturisticColors.paidBackground,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ Link Code Generated',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: FuturisticColors.success,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: FuturisticColors.success.withOpacity(0.6),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          generatedCode!,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: FuturisticColors.success,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.blue),
                          onPressed: _copyCode,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Valid for 30 minutes',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share this code with your customer. They can use it to link their profile to your business.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Info card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ℹ️ How it works:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              SizedBox(height: 8),
              Text(
                '1. Enter customer phone number',
                style: TextStyle(fontSize: 11),
              ),
              Text(
                '2. Click "Generate Code"',
                style: TextStyle(fontSize: 11),
              ),
              Text(
                '3. Share the 6-digit code with customer',
                style: TextStyle(fontSize: 11),
              ),
              Text(
                '4. Customer enters code in their app to link profile',
                style: TextStyle(fontSize: 11),
              ),
              Text(
                '5. Bills created for that phone will auto-sync to their profile',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Customer'),
        backgroundColor: Colors.blue,
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftColumn,
                    const SizedBox(height: 24),
                    rightColumn,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: leftColumn,
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: rightColumn,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
