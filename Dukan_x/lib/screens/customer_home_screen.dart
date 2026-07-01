import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../features/customers/presentation/screens/customer_home_screen.dart'
    as modern;

class CustomerHomeScreen extends StatelessWidget {
  final Customer customer;

  const CustomerHomeScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return modern.CustomerHomeScreen(customerId: customer.id);
  }
}
