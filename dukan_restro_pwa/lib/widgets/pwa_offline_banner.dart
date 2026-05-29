import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class PwaOfflineBanner extends StatefulWidget {
  const PwaOfflineBanner({super.key});

  @override
  State<PwaOfflineBanner> createState() => _PwaOfflineBannerState();
}

class _PwaOfflineBannerState extends State<PwaOfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final current = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => _offline = current.every((r) => r == ConnectivityResult.none));

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final nowOffline = results.every((r) => r == ConnectivityResult.none);
      if (mounted && nowOffline != _offline) {
        setState(() => _offline = nowOffline);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: const Color(0xFF7C2D12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No internet. Showing cached data where possible.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
