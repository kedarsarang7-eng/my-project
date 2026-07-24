/// Mobile Bill IMEI Field — Responsive Billing Widget for MobileShop
///
/// Provides [MobileBillImeiField], a TextFormField-based widget with:
/// - Required field indicator (asterisk)
/// - Inline validation error from [ImeiFieldController]
/// - Scan button (camera icon) with 48x48 minimum touch target
/// - Manual entry fallback when scanner is unavailable
/// - Busy-state indicator to prevent double-tap
/// - Responsive layout adapting to phone/tablet/desktop viewports
/// - Accessibility semantics (required field, error state)
///
/// Responsive breakpoints (per design):
/// - Phone (<600dp): full-width field, scan button below
/// - Tablet (600-1024dp): field takes 60% width, scan button inline
/// - Desktop (>1024dp): constrained max-width 400dp, scan button inline
///
/// Requirements: 2.5, 3.1–3.2, 10.3, 11.7–11.8, 12.1–12.2
/// Audit: AF-20
library;

import 'package:flutter/material.dart';

import 'imei_field_controller.dart';
import 'imei_scan_handler.dart';

// ─── Breakpoints ─────────────────────────────────────────────────────────────

/// Viewport width breakpoints for responsive layout.
class _Breakpoints {
  static const double phone = 600.0;
  static const double tablet = 1024.0;
}

// ─── Widget ──────────────────────────────────────────────────────────────────

/// A responsive IMEI input field for the mobileShop billing form.
///
/// Integrates with [ImeiFieldController] for validation and
/// [ImeiScanHandler] for barcode/QR scan-to-bill behavior.
///
/// The field is always required for mobileShop tenants and displays
/// an asterisk indicator. Validation errors are shown inline below the field.
class MobileBillImeiField extends StatefulWidget {
  /// The controller managing IMEI field validation state.
  final ImeiFieldController fieldController;

  /// The handler for scan-to-bill integration.
  final ImeiScanHandler scanHandler;

  /// Existing IMEIs in the current bill (for duplicate detection).
  final List<String> existingImeis;

  /// Called when a valid IMEI is accepted (via scan or manual entry).
  final ValueChanged<String>? onImeiAccepted;

  /// Called when the scan button is pressed.
  /// The parent should invoke the platform scanner and pass the result
  /// to [ImeiScanHandler.handleScanResult].
  final VoidCallback? onScanPressed;

  /// Optional initial value for the text field.
  final String? initialValue;

  /// Whether the field is enabled for input.
  final bool enabled;

  const MobileBillImeiField({
    super.key,
    required this.fieldController,
    required this.scanHandler,
    this.existingImeis = const [],
    this.onImeiAccepted,
    this.onScanPressed,
    this.initialValue,
    this.enabled = true,
  });

  @override
  State<MobileBillImeiField> createState() => _MobileBillImeiFieldState();
}

class _MobileBillImeiFieldState extends State<MobileBillImeiField> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialValue ?? '');
    widget.fieldController.addListener(_onControllerUpdate);
    widget.scanHandler.addListener(_onScanHandlerUpdate);
  }

  @override
  void dispose() {
    widget.fieldController.removeListener(_onControllerUpdate);
    widget.scanHandler.removeListener(_onScanHandlerUpdate);
    _textController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onScanHandlerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return _buildResponsiveLayout(context, width);
      },
    );
  }

  Widget _buildResponsiveLayout(BuildContext context, double availableWidth) {
    if (availableWidth < _Breakpoints.phone) {
      // Phone: full-width field, scan button below
      return _buildPhoneLayout(context);
    } else if (availableWidth < _Breakpoints.tablet) {
      // Tablet: field 60% width, scan button inline
      return _buildTabletLayout(context, availableWidth);
    } else {
      // Desktop: constrained max-width 400, scan button inline
      return _buildDesktopLayout(context);
    }
  }

  // ─── Phone layout ──────────────────────────────────────────────────────

  Widget _buildPhoneLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTextField(context),
        const SizedBox(height: 8),
        _buildScanButton(context),
        if (_hasError) ...[const SizedBox(height: 4), _buildErrorText(context)],
      ],
    );
  }

  // ─── Tablet layout ─────────────────────────────────────────────────────

  Widget _buildTabletLayout(BuildContext context, double availableWidth) {
    final fieldWidth = availableWidth * 0.6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: fieldWidth, child: _buildTextField(context)),
            const SizedBox(width: 12),
            _buildScanButton(context),
          ],
        ),
        if (_hasError) ...[const SizedBox(height: 4), _buildErrorText(context)],
      ],
    );
  }

  // ─── Desktop layout ────────────────────────────────────────────────────

  Widget _buildDesktopLayout(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTextField(context)),
              const SizedBox(width: 12),
              _buildScanButton(context),
            ],
          ),
          if (_hasError) ...[
            const SizedBox(height: 4),
            _buildErrorText(context),
          ],
        ],
      ),
    );
  }

  // ─── Shared components ─────────────────────────────────────────────────

  Widget _buildTextField(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = widget.fieldController.busyState;

    return Semantics(
      label: 'IMEI number, required',
      textField: true,
      enabled: widget.enabled && !isBusy,
      child: TextFormField(
        controller: _textController,
        enabled: widget.enabled && !isBusy,
        keyboardType: TextInputType.number,
        maxLength: 17, // 15 digits + possible separators
        decoration: InputDecoration(
          labelText: 'IMEI *',
          hintText: 'Enter 15-digit IMEI',
          counterText: '', // Hide character counter
          prefixIcon: const Icon(Icons.smartphone),
          suffixIcon: isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          border: const OutlineInputBorder(),
          errorText: widget.fieldController.fieldError,
          errorMaxLines: 2,
          filled: !widget.enabled,
          fillColor: widget.enabled
              ? null
              : theme.colorScheme.surfaceContainerHighest,
        ),
        onChanged: (value) {
          widget.fieldController.onChanged(value);
        },
        validator: (value) {
          // Form-level validation (on submit)
          final error = widget.fieldController.validate(value);
          if (error != null) return error;

          // Check for duplicates
          final duplicateError = widget.fieldController.preventDuplicateScan(
            value ?? '',
            widget.existingImeis,
          );
          return duplicateError;
        },
        onFieldSubmitted: (value) {
          if (widget.fieldController.validate(value) == null) {
            final duplicateError = widget.fieldController.preventDuplicateScan(
              value,
              widget.existingImeis,
            );
            if (duplicateError == null) {
              widget.onImeiAccepted?.call(value);
            }
          }
        },
      ),
    );
  }

  Widget _buildScanButton(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy =
        widget.fieldController.busyState || widget.scanHandler.isBusy;
    final isEnabled = widget.enabled && !isBusy;

    return Semantics(
      button: true,
      label: isBusy ? 'Scanning, please wait' : 'Scan IMEI barcode',
      enabled: isEnabled,
      child: SizedBox(
        width: ImeiScanHandler.minTouchTarget,
        height: ImeiScanHandler.minTouchTarget,
        child: Material(
          color: isEnabled
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isEnabled ? _handleScanTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: isBusy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : Icon(
                      Icons.qr_code_scanner,
                      color: isEnabled
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorText(BuildContext context) {
    final theme = Theme.of(context);
    final error = _effectiveError;
    if (error == null) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      child: Text(
        error,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  bool get _hasError => _effectiveError != null;

  /// Returns the most relevant error: scan error takes priority over
  /// field validation error (scan errors are more actionable).
  String? get _effectiveError {
    return widget.scanHandler.lastScanError ??
        widget.fieldController.fieldError;
  }

  void _handleScanTap() {
    if (widget.onScanPressed != null) {
      widget.onScanPressed!();
    } else {
      // No scanner callback — show manual fallback
      widget.scanHandler.showManualFallback();
    }
  }

  /// Updates the text field value programmatically (e.g., after a scan).
  void setImeiValue(String value) {
    _textController.text = value;
    widget.fieldController.onChanged(value);
  }
}
