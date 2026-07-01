import 'package:flutter/material.dart';

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Colors.redAccent),
            SizedBox(height: 12),
            Text('403 Access Denied', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('You do not have permission to view this page.'),
          ],
        ),
      ),
    );
  }
}
