// ============================================================================
// AUTH LOADING SCREEN
// ============================================================================
// Displays loading state while role is being resolved
// Prevents any dashboard rendering during auth state transitions
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';

/// Loading screen shown during authentication/role resolution
///
/// This is the ONLY UI shown while:
/// - Firebase auth is initializing
/// - User role is being fetched from Firestore
/// - Local cache is being validated
class AuthLoadingScreen extends StatelessWidget {
  final String? message;

  const AuthLoadingScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: ResponsiveContainer(
          child: Center(
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo placeholder
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.store_rounded,
                  size: 50,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 40),

              // Loading indicator
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),

              // Message
              Text(
                message ?? 'Setting up your account...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
