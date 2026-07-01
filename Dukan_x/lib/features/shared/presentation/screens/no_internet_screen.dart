import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoInternetScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BoundedBox(
        maxWidth: 800,
        child: Center(
        child: Padding(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No Internet Connection',
                style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20), fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry ?? () => Navigator.of(context).pop(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
