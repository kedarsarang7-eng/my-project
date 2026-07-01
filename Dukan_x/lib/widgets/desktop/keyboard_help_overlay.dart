/// Keyboard Help Overlay - F1 Shortcut Reference
///
/// Professional keyboard reference dialog showing:
/// - All active shortcuts grouped by category
/// - Function keys section
/// - Navigation keys section
/// - Context-specific shortcuts
/// - Search/filter capability
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';

import '../../core/keyboard/global_keyboard_handler.dart';
import '../../core/theme/futuristic_colors.dart';

/// F1 Help Overlay - Tally-style keyboard reference
class KeyboardHelpOverlay extends ConsumerWidget {
  const KeyboardHelpOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboardState = ref.watch(keyboardStateProvider);

    if (!keyboardState.isHelpOverlayVisible) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: () =>
                ref.read(keyboardStateProvider.notifier).hideHelpOverlay(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
          ),

          // Help Panel
          Center(
            child: Container(
              width: 900,
              height: 650,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FuturisticColors.primary.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: FuturisticColors.primary.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(context, ref),
                  Expanded(child: _buildShortcutGrid()),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FuturisticColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.keyboard,
              color: FuturisticColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keyboard Shortcuts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Press F1 anytime to toggle this help • ESC to close',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                ref.read(keyboardStateProvider.notifier).hideHelpOverlay(),
            icon: const Icon(Icons.close, color: Colors.white54),
            tooltip: 'Close (ESC)',
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutGrid() {
    final shortcuts = getAllShortcuts();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Function Keys Row
          _buildSectionTitle('⌨️ Function Keys (Tally Standard)'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: shortcuts
                .where((s) => s.key.startsWith('F') && s.key.length <= 3)
                .map((s) => _ShortcutChip(shortcut: s))
                .toList(),
          ),
          const SizedBox(height: 24),

          // Common Shortcuts
          _buildSectionTitle('⚡ Common Shortcuts'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: shortcuts
                .where((s) => s.category == 'Common')
                .map((s) => _ShortcutChip(shortcut: s))
                .toList(),
          ),
          const SizedBox(height: 24),

          // Navigation
          _buildSectionTitle('🧭 Navigation'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: shortcuts
                .where((s) => s.category == 'Navigation')
                .map((s) => _ShortcutChip(shortcut: s))
                .toList(),
          ),
          const SizedBox(height: 24),

          // System
          _buildSectionTitle('🔧 System'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: shortcuts
                .where((s) => s.category == 'System')
                .map((s) => _ShortcutChip(shortcut: s))
                .toList(),
          ),
          const SizedBox(height: 24),

          // Billing Flow
          _buildSectionTitle('🧾 Billing Flow'),
          const SizedBox(height: 12),
          _buildBillingFlowGuide(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: Colors.white.withOpacity(0.1)),
        ),
      ],
    );
  }

  Widget _buildBillingFlowGuide() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FuturisticColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FuturisticColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice Entry Keyboard Flow (No Mouse Required)',
            style: TextStyle(
              color: FuturisticColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFlowStep('1', 'F8', 'Open Sales'),
              _buildFlowArrow(),
              _buildFlowStep('2', 'Type', 'Customer'),
              _buildFlowArrow(),
              _buildFlowStep('3', 'ENTER', 'Select'),
              _buildFlowArrow(),
              _buildFlowStep('4', '↑↓', 'Pick Item'),
              _buildFlowArrow(),
              _buildFlowStep('5', 'ENTER', 'Qty/Rate'),
              _buildFlowArrow(),
              _buildFlowStep('6', 'Ctrl+S', 'Save'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStep(String step, String key, String action) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            key,
            style: const TextStyle(
              color: FuturisticColors.success,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          action,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildFlowArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.arrow_forward,
        color: Colors.white.withOpacity(0.3),
        size: 16,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white.withOpacity(0.4),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Shortcuts respect your user role permissions',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual shortcut chip
class _ShortcutChip extends StatelessWidget {
  final ShortcutInfo shortcut;

  const _ShortcutChip({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getCategoryColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getCategoryColor().withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getCategoryColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcut.key,
              style: TextStyle(
                color: _getCategoryColor(),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            shortcut.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor() {
    switch (shortcut.category) {
      case 'Navigation':
        return FuturisticColors.primary;
      case 'Common':
        return FuturisticColors.success;
      case 'System':
        return FuturisticColors.warning;
      case 'Billing':
        return FuturisticColors.accent1;
      default:
        return FuturisticColors.textSecondary;
    }
  }
}
