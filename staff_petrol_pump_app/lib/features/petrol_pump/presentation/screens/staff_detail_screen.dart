import 'package:flutter/material.dart';

class StaffDetailScreen extends StatelessWidget {
  final String staffId;
  
  const StaffDetailScreen({
    super.key,
    required this.staffId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Details'),
      ),
      body: const Center(
        child: Text('Staff Detail Screen - To be implemented'),
      ),
    );
  }
}
