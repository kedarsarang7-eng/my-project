// ============================================================================
// DC Quote to Booking Conversion Screen
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../../utils/dc_money_math.dart';
import '../../utils/decoration_catering_business_rules.dart';
import '../widgets/dc_ui_kit.dart';

class DcQuoteConversionScreen extends ConsumerStatefulWidget {
  final DcQuote quote;
  const DcQuoteConversionScreen({super.key, required this.quote});

  @override
  ConsumerState<DcQuoteConversionScreen> createState() =>
      _DcQuoteConversionScreenState();
}

class _DcQuoteConversionScreenState
    extends ConsumerState<DcQuoteConversionScreen> {
  final _advanceCtrl = TextEditingController();
  String _selectedThemeId = '';
  String _selectedPackageId = '';
  bool _converting = false;

  /// Configurable advance percentage — default 50%, range [30, 50].
  AdvanceConfig _advanceConfig = const AdvanceConfig();

  static const _teal = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    // Default advance = 50% of quote total (per Requirement 11.1)
    final totalPaise = DcMoneyMath.rupeesToPaise(widget.quote.total);
    final advancePaise = _advanceConfig.computeAdvancePaise(totalPaise);
    if (advancePaise != null) {
      _advanceCtrl.text = DcMoneyMath.paiseToRupees(
        advancePaise,
      ).toStringAsFixed(0);
    } else {
      _advanceCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _advanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(dcThemesProvider);
    final packagesAsync = ref.watch(dcPackagesProvider);

    return Scaffold(
      backgroundColor: DcColors.tealLight,
      appBar: AppBar(
        title: const Text('Convert Quote to Booking'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuoteSummary(),
            const SizedBox(height: 24),
            _buildConversionForm(themesAsync, packagesAsync),
          ],
        ),
      ),
      bottomNavigationBar: _buildConvertButton(),
    );
  }

  Widget _buildQuoteSummary() {
    final fmt = NumberFormat('#,##,###');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description, color: _teal),
              const SizedBox(width: 8),
              Text(
                'Quote #${widget.quote.quoteNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('Customer', widget.quote.customerName),
          _buildInfoRow('Event Type', widget.quote.eventType),
          if (widget.quote.eventDate != null)
            _buildInfoRow('Event Date', widget.quote.eventDate!),
          if (widget.quote.venue != null && widget.quote.venue!.isNotEmpty)
            _buildInfoRow('Venue', widget.quote.venue!),
          _buildInfoRow('Guests', '${widget.quote.guestCount}'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${fmt.format(widget.quote.total.round())}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Color(0xFF6B7280))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildConversionForm(
    AsyncValue<List<DecorationTheme>> themesAsync,
    AsyncValue<List<CateringPackage>> packagesAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Booking Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),

        // Advance percentage configuration
        _buildAdvancePctSelector(),
        const SizedBox(height: 16),

        // Advance amount (read-only, computed from percentage)
        TextFormField(
          controller: _advanceCtrl,
          keyboardType: TextInputType.number,
          readOnly: true,
          decoration: InputDecoration(
            labelText:
                'Advance Amount (₹) — ${_advanceConfig.advancePct}% of total',
            border: const OutlineInputBorder(),
            prefixText: '₹ ',
            helperText:
                'Computed as ${_advanceConfig.advancePct}% of quote total',
          ),
        ),
        const SizedBox(height: 16),

        // Decoration Theme selection
        themesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Failed to load themes'),
          data: (themes) => DropdownButtonFormField<String>(
            value: _selectedThemeId.isEmpty && themes.isNotEmpty
                ? null
                : _selectedThemeId.isEmpty
                ? null
                : _selectedThemeId,
            decoration: const InputDecoration(
              labelText: 'Decoration Theme (Optional)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('None')),
              ...themes.map(
                (t) => DropdownMenuItem(
                  value: t.id,
                  child: Text(
                    '${t.name} (₹${NumberFormat('#,##,###').format(t.basePrice.round())})',
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedThemeId = v ?? ''),
          ),
        ),
        const SizedBox(height: 16),

        // Catering Package selection
        packagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Failed to load packages'),
          data: (packages) => DropdownButtonFormField<String>(
            value: _selectedPackageId.isEmpty && packages.isNotEmpty
                ? null
                : _selectedPackageId.isEmpty
                ? null
                : _selectedPackageId,
            decoration: const InputDecoration(
              labelText: 'Catering Package (Optional)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('None')),
              ...packages.map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    '${p.name} (₹${NumberFormat('#,##,###').format(p.pricePerPlate.round())}/plate)',
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedPackageId = v ?? ''),
          ),
        ),
      ],
    );
  }

  /// Builds the advance percentage selector (30–50% inclusive, default 50%).
  Widget _buildAdvancePctSelector() {
    return Row(
      children: [
        const Text(
          'Advance %: ',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: _advanceConfig.advancePct,
          items: List.generate(21, (i) => 30 + i)
              .where((pct) => pct >= 30 && pct <= 50)
              .map((pct) => DropdownMenuItem(value: pct, child: Text('$pct%')))
              .toList(),
          onChanged: (newPct) {
            if (newPct == null) return;
            final newConfig = AdvanceConfig.tryCreate(newPct);
            if (newConfig == null) {
              // Out of range — reject, retain previous (Requirement 11.2)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Advance percentage must be between 30% and 50%',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            setState(() {
              _advanceConfig = newConfig;
              // Recompute advance amount
              final totalPaise = DcMoneyMath.rupeesToPaise(widget.quote.total);
              final advancePaise = _advanceConfig.computeAdvancePaise(
                totalPaise,
              );
              _advanceCtrl.text = advancePaise != null
                  ? DcMoneyMath.paiseToRupees(advancePaise).toStringAsFixed(0)
                  : '0';
            });
          },
        ),
        const SizedBox(width: 12),
        Text(
          '(30–50%)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildConvertButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _converting ? null : _convertToBooking,
          icon: _converting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle),
          label: Text(_converting ? 'Converting...' : 'Convert to Booking'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ),
    );
  }

  Future<void> _convertToBooking() async {
    // --- Advance validation (Requirements 11.3, 11.4, 11.5) ---
    final totalPaise = DcMoneyMath.rupeesToPaise(widget.quote.total);
    final advancePaise = _advanceConfig.computeAdvancePaise(totalPaise);

    if (advancePaise == null) {
      // Out of bounds — reject conversion, create no booking, leave quote
      // unchanged (Requirement 11.5)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Advance amount is outside allowed bounds (0 to total). '
              'Cannot convert.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Convert advance back to rupee-double for the existing model boundary
    final advanceRupees = DcMoneyMath.paiseToRupees(advancePaise);

    setState(() => _converting = true);
    try {
      final repo = ref.read(dcRepositoryProvider);

      // 1. Update quote status to accepted
      await repo.updateQuoteStatus(widget.quote.id, QuoteStatus.accepted);

      // 2. Create event booking from quote
      final booking = EventBooking(
        id: '', // Will be generated by backend
        customerId: '',
        customerName: widget.quote.customerName,
        customerPhone: widget.quote.customerPhone,
        customerEmail: '',
        eventType: _parseEventType(widget.quote.eventType),
        eventTitle: widget.quote.eventType,
        eventDate: widget.quote.eventDate != null
            ? DateTime.parse(widget.quote.eventDate!)
            : DateTime.now().add(const Duration(days: 7)),
        venue: widget.quote.venue ?? '',
        venueAddress: '',
        guestCount: widget.quote.guestCount,
        status: EventStatus.confirmed,
        quotedAmount: widget.quote.total,
        advancePaid: advanceRupees,
        decorationThemeId: _selectedThemeId.isEmpty ? null : _selectedThemeId,
        cateringPackageId: _selectedPackageId.isEmpty
            ? null
            : _selectedPackageId,
        createdAt: DateTime.now(),
      );

      final createdBooking = await repo.createBooking(booking);

      // 3. Record payment via DcRepository.recordPayment against
      //    /dc/events/{id}/payments (Requirement 11.6)
      //    If this fails → reject conversion, create no booking, leave ledger
      //    unchanged, present "could not record advance" error (Requirement 11.7)
      try {
        await repo.recordPayment(
          DcPayment(
            id: '', // Will be generated by backend
            eventId: createdBooking.id,
            customerName: widget.quote.customerName,
            amount: advanceRupees,
            method: PaymentMethod.cash,
            date: DateTime.now(),
          ),
        );
      } catch (paymentError) {
        // recordPayment failed — reject conversion:
        // Attempt to undo the booking creation and revert quote status.
        try {
          await repo.deleteBooking(createdBooking.id);
        } catch (_) {
          // Best effort cleanup; the critical error is the payment failure.
        }
        try {
          // Revert quote status back to its original state (pre-conversion)
          await repo.updateQuoteStatus(widget.quote.id, widget.quote.status);
        } catch (_) {
          // Best effort revert
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not record advance payment. '
                'Conversion rejected — no booking created.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote converted to booking successfully!'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Conversion failed at booking/quote-status level — quote is left
      // in pre-conversion state (if quote status update failed) or partially
      // reverted. Present generic error.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  EventType _parseEventType(String? type) {
    switch (type?.toLowerCase()) {
      case 'wedding':
        return EventType.wedding;
      case 'birthday':
        return EventType.birthday;
      case 'corporate':
        return EventType.corporate;
      case 'engagement':
        return EventType.engagement;
      case 'babyshower':
        return EventType.babyShower;
      case 'anniversary':
        return EventType.anniversary;
      case 'conference':
        return EventType.conference;
      default:
        return EventType.other;
    }
  }
}
