import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable breadcrumb navigation for clinic screens.
///
/// Usage:
/// ```dart
/// ClinicBreadcrumbs(items: [
///   BreadcrumbItem('Dashboard', onTap: () => Navigator.pop(context)),
///   BreadcrumbItem('Patients'),
/// ])
/// ```
class ClinicBreadcrumbs extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const ClinicBreadcrumbs({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) ...[
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade500),
              const SizedBox(width: 4),
            ],
            if (items[i].onTap != null && i < items.length - 1)
              InkWell(
                onTap: items[i].onTap,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    items[i].label,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              )
            else
              Text(
                items[i].label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  const BreadcrumbItem(this.label, {this.onTap});
}
