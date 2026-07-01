// Gold Rate Management Screen - Jewellery
// Fully functional with offline support

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/models/jewellery_product_model.dart';
import '../../data/repositories/jewellery_repository_offline.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class GoldRateManagementScreen extends StatefulWidget {
  const GoldRateManagementScreen({super.key});

  @override
  State<GoldRateManagementScreen> createState() =>
      _GoldRateManagementScreenState();
}

class _GoldRateManagementScreenState extends State<GoldRateManagementScreen> {
  final JewelleryRepositoryOffline _repository = JewelleryRepositoryOffline(
    sl(),
    sl<SessionManager>(),
  );

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  GoldRateCard? _todayRate;
  List<GoldRateCard> _rateHistory = [];

  // Controllers for rate input
  final _gold24KController = TextEditingController();
  final _gold22KController = TextEditingController();
  final _gold18KController = TextEditingController();
  final _silverController = TextEditingController();
  final _platinumController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedSource = 'MANUAL';
  // TODO(BACKLOG): When live gold-rate market-feed is implemented (Requirement
  // 16.6), add a 'LIVE_FEED' source option and auto-refresh logic here. This
  // is a non-blocking backlog item — NOT implemented in this remediation.
  final List<String> _sourceOptions = ['MANUAL', 'API', 'BANK'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _gold24KController.dispose();
    _gold22KController.dispose();
    _gold18KController.dispose();
    _silverController.dispose();
    _platinumController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _repository.initialize();

      // Load today's rate
      final todayRate = await _repository.getTodayGoldRate();

      // Load history
      final history = await _repository.getGoldRateHistory(days: 30);

      setState(() {
        _todayRate = todayRate;
        _rateHistory = history;
        _isLoading = false;
      });

      // Populate controllers if today's rate exists
      if (todayRate != null) {
        _gold24KController.text = todayRate.displayGold24K.toStringAsFixed(0);
        _gold22KController.text = todayRate.displayGold22K.toStringAsFixed(0);
        _gold18KController.text = todayRate.displayGold18K.toStringAsFixed(0);
        _silverController.text = todayRate.displaySilver.toStringAsFixed(0);
        _platinumController.text = todayRate.displayPlatinum.toStringAsFixed(0);
        _selectedSource = todayRate.source;
        if (todayRate.notes != null) {
          _notesController.text = todayRate.notes!;
        }
      } else {
        // Auto-calculate derived rates if only 24K is entered
        _gold24KController.addListener(_autoCalculateRates);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load gold rates: $e';
        _isLoading = false;
      });
    }
  }

  void _autoCalculateRates() {
    final rate24K = double.tryParse(_gold24KController.text) ?? 0;
    if (rate24K > 0 && _gold22KController.text.isEmpty) {
      // 22K is typically 91.6% of 24K
      _gold22KController.text = (rate24K * 0.916).toStringAsFixed(0);
    }
    if (rate24K > 0 && _gold18KController.text.isEmpty) {
      // 18K is 75% of 24K
      _gold18KController.text = (rate24K * 0.75).toStringAsFixed(0);
    }
  }

  Future<void> _saveGoldRate() async {
    // Validate inputs
    final gold24K = double.tryParse(_gold24KController.text);
    final gold22K = double.tryParse(_gold22KController.text);
    final gold18K = double.tryParse(_gold18KController.text);
    final silver = double.tryParse(_silverController.text) ?? 0;
    final platinum = double.tryParse(_platinumController.text) ?? 0;

    if (gold24K == null || gold24K <= 0) {
      _showError('Please enter a valid 24K gold rate');
      return;
    }

    if (gold22K == null || gold22K <= 0) {
      _showError('Please enter a valid 22K gold rate');
      return;
    }

    if (gold18K == null || gold18K <= 0) {
      _showError('Please enter a valid 18K gold rate');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      await _repository.setGoldRate(
        date: today,
        gold24KPer10gPaisa: (gold24K * 100).round(),
        gold22KPer10gPaisa: (gold22K * 100).round(),
        gold18KPer10gPaisa: (gold18K * 100).round(),
        silverPerKgPaisa: (silver * 100).round(),
        platinumPerGramPaisa: (platinum * 100).round(),
        source: _selectedSource,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // Reload data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gold rates saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save gold rates: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      // R9.2: this screen is registered as a standalone GoRoute
      // (/jewellery/gold-rate, /jewellery/rates) and pushed full-screen, so it
      // must expose its own back affordance. The leading button is shown only
      // when the route can actually pop (a no-op safe `maybePop`).
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: const Text('Gold Rate Management'),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorWidget()
            : isDesktop
            ? _buildDesktopLayout()
            : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left panel - Rate input
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              responsiveValue<double>(
                context,
                mobile: 16,
                tablet: 20,
                desktop: 24,
              ),
            ),
            child: _buildRateInputCard(),
          ),
        ),
        // Right panel - History & Preview
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Today's rate preview
              if (_todayRate != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildTodayRateCard(),
                ),
              // History
              Expanded(child: _buildHistoryTable()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_todayRate != null) _buildTodayRateCard(),
          const SizedBox(height: 16),
          _buildRateInputCard(),
          const SizedBox(height: 16),
          _buildHistoryCard(),
        ],
      ),
    );
  }

  Widget _buildRateInputCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFD4AF37),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gold Rate Management',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Gold rates
            _buildRateInputField(
              label: '24K Gold (per 10g)',
              controller: _gold24KController,
              icon: Icons.looks_one,
              color: const Color(0xFFFFD700),
              hint: 'e.g., 65000',
            ),
            const SizedBox(height: 16),
            _buildRateInputField(
              label: '22K Gold (per 10g)',
              controller: _gold22KController,
              icon: Icons.looks_two,
              color: const Color(0xFFFFE55C),
              hint: 'e.g., 59590',
            ),
            const SizedBox(height: 16),
            _buildRateInputField(
              label: '18K Gold (per 10g)',
              controller: _gold18KController,
              icon: Icons.looks_3,
              color: const Color(0xFFE6C200),
              hint: 'e.g., 48750',
            ),
            const SizedBox(height: 24),

            // Other metals
            _buildRateInputField(
              label: 'Silver (per kg)',
              controller: _silverController,
              icon: Icons.star,
              color: const Color(0xFFC0C0C0),
              hint: 'e.g., 72000',
            ),
            const SizedBox(height: 16),
            _buildRateInputField(
              label: 'Platinum (per gram)',
              controller: _platinumController,
              icon: Icons.diamond,
              color: const Color(0xFFE5E4E2),
              hint: 'e.g., 3200',
            ),
            const SizedBox(height: 24),

            // Source dropdown
            DropdownButtonFormField<String>(
              value: _selectedSource,
              decoration: InputDecoration(
                labelText: 'Rate Source',
                prefixIcon: const Icon(Icons.source),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
              items: _sourceOptions.map((source) {
                return DropdownMenuItem(value: source, child: Text(source));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSource = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveGoldRate,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Gold Rates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
    required String hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: color),
        suffixText: sl<CurrencyService>().symbol,
        suffixStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
      ),
    );
  }

  Widget _buildTodayRateCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFD4AF37),
              const Color(0xFFD4AF37).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Gold Rates",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _todayRate?.source ?? 'MANUAL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildRateDisplay(
                    '24K Gold',
                    _todayRate?.displayGold24K ?? 0,
                    'per 10g',
                  ),
                ),
                Expanded(
                  child: _buildRateDisplay(
                    '22K Gold',
                    _todayRate?.displayGold22K ?? 0,
                    'per 10g',
                  ),
                ),
                Expanded(
                  child: _buildRateDisplay(
                    '18K Gold',
                    _todayRate?.displayGold18K ?? 0,
                    'per 10g',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateDisplay(String label, double value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: responsiveValue<double>(
              context,
              mobile: 18,
              tablet: 20,
              desktop: 24,
            ),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          unit,
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildHistoryTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.history, color: Color(0xFFD4AF37)),
                const SizedBox(width: 12),
                Text(
                  'Rate History (Last 30 Days)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _rateHistory.isEmpty
                ? _buildEmptyHistory()
                : ListView.builder(
                    itemCount: _rateHistory.length,
                    itemBuilder: (context, index) {
                      final rate = _rateHistory[index];
                      return _buildHistoryRow(rate, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No rate history yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(GoldRateCard rate, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = DateTime.parse(rate.date);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        color: index % 2 == 0
            ? (isDark ? Colors.grey[850] : Colors.grey[50])
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d').format(date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat('yyyy').format(date),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRateBadge(
                  '24K',
                  rate.displayGold24K,
                  const Color(0xFFFFD700),
                ),
                _buildRateBadge(
                  '22K',
                  rate.displayGold22K,
                  const Color(0xFFFFE55C),
                ),
                _buildRateBadge(
                  '18K',
                  rate.displayGold18K,
                  const Color(0xFFE6C200),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              rate.source,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateBadge(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
          Text(
            '₹${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.history, color: Color(0xFFD4AF37)),
                const SizedBox(width: 12),
                const Text(
                  'Rate History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rateHistory.take(5).length,
            itemBuilder: (context, index) {
              final rate = _rateHistory[index];
              final date = DateTime.parse(rate.date);
              return ListTile(
                title: Text(DateFormat('MMM d, yyyy').format(date)),
                subtitle: Text('Source: ${rate.source}'),
                trailing: Text(
                  '₹${rate.displayGold22K.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4AF37),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
