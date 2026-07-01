import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/service_locator.dart';
import '../../services/customer_link_service.dart';

class CustomerQrDialog extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerQrDialog({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  static Future<void> show(
    BuildContext context, {
    required String customerId,
    required String customerName,
  }) async {
    await showDialog(
      context: context,
      builder: (context) =>
          CustomerQrDialog(customerId: customerId, customerName: customerName),
    );
  }

  @override
  State<CustomerQrDialog> createState() => _CustomerQrDialogState();
}

class _CustomerQrDialogState extends State<CustomerQrDialog> {
  String? _linkUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateOrFetchLink();
  }

  Future<void> _generateOrFetchLink() async {
    try {
      final service = sl<CustomerLinkService>();
      // Always regenerate for security on new open, or check existing?
      // For simplicity/security, let's generate a new one if expired, or fetch existing.
      // But for "Show QR", we usually want the CURRENT valid one.

      final status = await service.getLinkStatus(widget.customerId);
      String? url;

      if (status['token'] != null && status['isExpired'] == false) {
        url =
            "https://dukanx.com/connect?id=${widget.customerId}&token=${status['token']}";
      } else {
        url = await service.generateLink(widget.customerId);
      }

      if (mounted) {
        setState(() {
          _linkUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _regenerateLink() async {
    setState(() => _isLoading = true);
    final service = sl<CustomerLinkService>();
    final url = await service.generateLink(widget.customerId);
    if (mounted) {
      setState(() {
        _linkUrl = url;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Basic styling
    const textColor = Colors.black87;
    const bgColor = Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Connect ${widget.customerName}",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    "Error: $_error",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (_linkUrl != null) ...[
              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _linkUrl!,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Scan this QR on Customer's Device",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icons.copy,
                    label: "Copy Link",
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _linkUrl!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Link copied to clipboard"),
                        ),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.share,
                    label: "Share",
                    color: Colors.blue,
                    onTap: () {
                      Share.share(
                        "Connect with ${widget.customerName} on DukanX: $_linkUrl",
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.refresh,
                    label: "Regenerate",
                    color: Colors.orange,
                    onTap: _regenerateLink,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
