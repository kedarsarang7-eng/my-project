import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/core/utils/amount_converter.dart';
import 'package:dukanx/services/websocket_service.dart';
import 'package:dukanx/features/shared/presentation/screens/no_internet_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Staff Sale Entry Screen
///
/// Used by petrol pump staff to record fuel sales.
/// Supports Cash and Online (UPI QR) payment modes.
class StaffSaleEntryScreen extends StatefulWidget {
  const StaffSaleEntryScreen({super.key});

  @override
  State<StaffSaleEntryScreen> createState() => _StaffSaleEntryScreenState();
}

class _StaffSaleEntryScreenState extends State<StaffSaleEntryScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = sl<ApiClient>();
  final SessionManager _sessionManager = sl<SessionManager>();

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _customerController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedProduct = 'petrol';
  String _paymentMode = 'cash';
  bool _isSubmitting = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _products = [
    {
      'key': 'petrol',
      'label': 'Petrol',
      'icon': Icons.local_gas_station,
      'color': Colors.orange,
    },
    {
      'key': 'diesel',
      'label': 'Diesel',
      'icon': Icons.local_gas_station,
      'color': Colors.amber,
    },
    {
      'key': 'lub_oil',
      'label': 'Lub Oil',
      'icon': Icons.oil_barrel,
      'color': Colors.blue,
    },
    {
      'key': 'cng',
      'label': 'CNG',
      'icon': Icons.propane_tank,
      'color': Colors.green,
    },
    {
      'key': 'other',
      'label': 'Other',
      'icon': Icons.category,
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _amountController.dispose();
    _vehicleController.dispose();
    _customerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('New Sale'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Product Type ──
                _buildSectionLabel('Product Type', isDark),
                const SizedBox(height: 8),
                _buildProductSelector(isDark),
                const SizedBox(height: 20),

                // ── Amount ──
                _buildSectionLabel('Amount (₹)', isDark),
                const SizedBox(height: 8),
                _buildAmountField(isDark),
                const SizedBox(height: 20),

                // ── Payment Mode ──
                _buildSectionLabel('Payment Mode', isDark),
                const SizedBox(height: 8),
                _buildPaymentModeSelector(isDark, theme),
                const SizedBox(height: 20),

                // ── Optional Fields ──
                _buildSectionLabel('Vehicle Number (optional)', isDark),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _vehicleController,
                  hint: 'e.g. MH-12-AB-1234',
                  icon: Icons.directions_car,
                  isDark: isDark,
                  maxLength: 20,
                ),
                const SizedBox(height: 12),

                _buildSectionLabel('Customer Name (optional)', isDark),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _customerController,
                  hint: 'Customer name',
                  icon: Icons.person_outline,
                  isDark: isDark,
                  maxLength: 100,
                ),
                const SizedBox(height: 12),

                _buildSectionLabel('Notes (optional)', isDark),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _notesController,
                  hint: 'Any additional notes',
                  icon: Icons.notes,
                  isDark: isDark,
                  maxLength: 255,
                  maxLines: 2,
                ),
                const SizedBox(height: 32),

                // ── Submit ──
                _buildSubmitButton(isDark, theme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white60 : Colors.grey[700],
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildProductSelector(bool isDark) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final p = _products[i];
          final isSelected = p['key'] == _selectedProduct;
          final color = p['color'] as Color;

          return GestureDetector(
            onTap: () => setState(() => _selectedProduct = p['key']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    p['icon'],
                    size: 24,
                    color: isSelected ? color : Colors.grey,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p['label'],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? color
                          : (isDark ? Colors.white54 : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmountField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: TextFormField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        style: TextStyle(
          fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Text(
              sl<CurrencyService>().symbol,
              style: TextStyle(
                fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(),
          hintText: '0.00',
          hintStyle: TextStyle(
            fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Enter amount';
          final val = double.tryParse(v);
          if (val == null || val <= 0) return 'Enter valid amount';
          return null;
        },
      ),
    );
  }

  Widget _buildPaymentModeSelector(bool isDark, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildModeCard(
            label: 'Cash',
            icon: Icons.money,
            isSelected: _paymentMode == 'cash',
            color: Colors.green,
            isDark: isDark,
            onTap: () => setState(() => _paymentMode = 'cash'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildModeCard(
            label: 'Online (UPI)',
            icon: Icons.qr_code_2,
            isSelected: _paymentMode == 'online',
            color: Colors.blue,
            isDark: isDark,
            onTap: () => setState(() => _paymentMode = 'online'),
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? color : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white54 : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    int? maxLength,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20),
          hintText: hint,
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark, ThemeData theme) {
    final color = _paymentMode == 'cash' ? Colors.green : Colors.blue;

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _paymentMode == 'cash'
                        ? Icons.check_circle
                        : Icons.qr_code_2,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _paymentMode == 'cash'
                        ? 'Record Cash Sale'
                        : 'Generate Payment QR',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text);
      final amountCents = AmountConverter.rupeesToPaise(amount);

      // Basic online check for online-payment mode
      if (_paymentMode == 'online') {
        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity.contains(ConnectivityResult.none)) {
          if (!mounted) return;
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NoInternetScreen()));
          return;
        }
      }

      // Cash: POST /staff/sale
      // Online: POST /staff/sale/generate-qr
      final endpoint = _paymentMode == 'cash'
          ? '/staff/sale'
          : '/staff/sale/generate-qr';

      final response = await _apiClient.post(
        endpoint,
        body: {
          'amountCents': amountCents,
          'product': _selectedProduct,
          'vehicle': _vehicleController.text,
          'customer': _customerController.text,
          'notes': _notesController.text,
          if (_sessionManager.currentSession.odId.isNotEmpty)
            'staffId': _sessionManager.currentSession.odId,
        },
      );

      if (!mounted) return;

      if (!response.isSuccess || response.data == null) {
        throw Exception(response.userMessage);
      }

      final data = response.data!;

      if (_paymentMode == 'online') {
        final txId = data['transactionId'] as String?;
        final orderId = data['orderId'] as String?;
        if (txId == null || txId.isEmpty) {
          throw Exception('Missing transactionId from server response');
        }
        if (orderId == null || orderId.isEmpty) {
          throw Exception('Missing orderId from server response');
        }
        final invNum =
            data['invoiceNumber'] ??
            'STAFF-QR-${DateTime.now().millisecondsSinceEpoch}';
        final qrPay =
            data['qrPayload'] ??
            data['qrUrl'] ??
            'upi://pay?pa=owner@upi&pn=PetrolPump&am=${amount.toStringAsFixed(2)}&tn=FuelPayment';

        // Navigate to QR screen with response data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StaffPaymentQrScreen(
              transactionId: txId,
              orderId: orderId,
              invoiceNumber: invNum,
              amountCents: amountCents,
              productType: _selectedProduct,
              qrPayload: qrPay,
            ),
          ),
        );
      } else {
        // Cash sale recorded
        _showSuccess('Sale recorded successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to record sale: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// ============================================================================
// Staff Payment QR Screen
// ============================================================================
// Shown when the staff selects Online payment mode.
// Displays the dynamic UPI QR code and polls for payment confirmation.

class StaffPaymentQrScreen extends StatefulWidget {
  final String transactionId;
  final String orderId;
  final String invoiceNumber;
  final int amountCents;
  final String productType;
  final String? qrPayload;

  const StaffPaymentQrScreen({
    super.key,
    required this.transactionId,
    required this.orderId,
    required this.invoiceNumber,
    required this.amountCents,
    required this.productType,
    this.qrPayload,
  });

  @override
  State<StaffPaymentQrScreen> createState() => _StaffPaymentQrScreenState();
}

class _StaffPaymentQrScreenState extends State<StaffPaymentQrScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = sl<ApiClient>();

  String _status = 'pending'; // pending, success, failed, expired
  bool _isPolling = true;
  bool _paymentReceived = false;
  int _secondsRemaining = 600; // 10 minutes
  Timer? _countdownTimer;
  StreamSubscription<WSConnectionStatus>? _wsStatusSub;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WakelockPlus.enable();
    _startCountdown();
    _listenToWebSocket();
    _startPolling();
  }

  @override
  void dispose() {
    _isPolling = false;
    _wsStatusSub?.cancel();
    _countdownTimer?.cancel();
    WebSocketService.instance.unsubscribe(
      WSEventName.paymentSuccess,
      _onPaymentSuccessEvent,
    );
    _pulseController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _paymentReceived) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _isPolling = false;
        setState(() => _status = 'expired');
      }
    });
  }

  void _listenToWebSocket() {
    WebSocketService.instance.subscribe(
      WSEventName.paymentSuccess,
      _onPaymentSuccessEvent,
    );

    _wsStatusSub = WebSocketService.instance.statusStream.listen((_) {
      // Polling fallback already active every 3 seconds.
      // Status stream is observed for future UX hooks.
    });
  }

  void _onPaymentSuccessEvent(WSEvent event) {
    if (!mounted || _paymentReceived) return;
    final eventTxId = event.data['transactionId']?.toString();
    if (eventTxId == widget.transactionId) {
      _onPaymentSuccess();
    }
  }

  void _onPaymentSuccess() {
    if (_paymentReceived || !mounted) return;
    _paymentReceived = true;
    _isPolling = false;
    _countdownTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _status = 'success');
  }

  Future<void> _startPolling() async {
    // Poll payment status every 3 seconds
    while (_isPolling && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || !_isPolling || _paymentReceived) break;

      if (_secondsRemaining <= 0) {
        _isPolling = false;
        break;
      }

      try {
        final response = await _apiClient.get(
          '/payment/status',
          queryParams: {'orderId': widget.orderId},
        );

        if (response.isSuccess && response.data != null) {
          final statusValue =
              (response.data!['data']?['status'] ?? response.data!['status'])
                  ?.toString()
                  .toLowerCase();
          final txId =
              (response.data!['data']?['transactionId'] ??
                      response.data!['transactionId'])
                  ?.toString();

          if (statusValue == 'success' && txId == widget.transactionId) {
            _onPaymentSuccess();
            break;
          } else if (statusValue == 'failed') {
            _countdownTimer?.cancel();
            setState(() {
              _status = 'failed';
              _isPolling = false;
            });
            break;
          }
        }
      } catch (e) {
        // Ignore network errors and keep polling
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amount = AmountConverter.paiseToRupees(
      widget.amountCents,
    ).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Payment QR'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Amount display
              Text(
                '₹$amount',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.productType.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 24),

              // QR Code placeholder
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) {
                  return Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 
                            0.1 + (_pulseController.value * 0.1),
                          ),
                          blurRadius: 20 + (_pulseController.value * 10),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: _status == 'success'
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 120,
                          )
                        : _status == 'failed'
                        ? const Icon(Icons.error, color: Colors.red, size: 120)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.qr_code_2,
                                size: 160,
                                color: Colors.grey[800],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Scan to Pay',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Status indicator
              _buildStatusIndicator(isDark),
              const SizedBox(height: 16),

              // Invoice number
              Text(
                widget.invoiceNumber,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white24 : Colors.grey,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 32),

              // Action buttons
              if (_status == 'pending') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isPolling = false;
                        _status = 'failed';
                      });
                      Navigator.pop(context, false);
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel Payment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              if (_status == 'success') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isDark) {
    switch (_status) {
      case 'success':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
          ],
        );
      case 'failed':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              'Payment Failed',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
          ],
        );
      case 'expired':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_off, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            Text(
              'QR Expired — Try Again',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
            ),
          ],
        );
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  isDark ? Colors.white38 : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Waiting for payment... (${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')})',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        );
    }
  }
}
