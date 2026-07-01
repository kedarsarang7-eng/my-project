// ============================================================================
// SUPPORT SCREENS
// ============================================================================
// Static content for Help, Terms, etc.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildItem(
            context,
            "How to check my dues?",
            "Go to the Dashboard and check 'Total Outstanding'.",
          ),
          _buildItem(
            context,
            "How to link another shop?",
            "Go to Profile > My Shops > Link Shop.",
          ),
          _buildItem(
            context,
            "Can I pay online?",
            "Online payments are currently unavailable. Please arrange payment directly with the shop via Cash or UPI.",
          ),
          _buildItem(
            context,
            "My bill is incorrect",
            "Please contact the shop owner directly using the 'Call' button on the dashboard.",
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            answer,
            style: GoogleFonts.outfit(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Terms & Privacy")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("Privacy Policy"),
            _buildText(
              "We value your privacy. DukanX does not share your personal data with third parties without your consent. Your transaction data is shared only with the specific shop you are linked to.",
            ),
            const SizedBox(height: 24),
            _buildHeader("Terms of Service"),
            _buildText(
              "By using DukanX, you agree to maintain accurate profile information. DukanX is a platform to connect customers and local shops. We are not responsible for the quality of goods or services provided by the shops.",
            ),
            const SizedBox(height: 24),
            _buildHeader("Data Deletion"),
            _buildText(
              "To request data deletion, please contact support@dukanx.com or use the Delete Account option in Security Settings.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 15,
          height: 1.5,
          color: Colors.grey[800],
        ),
      ),
    );
  }
}
