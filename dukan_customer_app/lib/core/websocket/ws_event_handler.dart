import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/data/home_repository.dart';
import '../../features/invoices/data/invoice_repository.dart';
import '../../features/ledger/data/ledger_repository.dart';
import '../../features/notifications/data/notifications_repository.dart';
import 'customer_ws_service.dart';

/// Bridges WebSocket events to Riverpod provider invalidations so screens
/// refresh automatically when the backend pushes new data.
class WsEventHandler {
  final WidgetRef _ref;
  final CustomerWsService _ws;

  WsEventHandler(this._ref, this._ws) {
    _ws.subscribe('INVOICE_CREATED', _onInvoiceEvent);
    _ws.subscribe('INVOICE_UPDATED', _onInvoiceEvent);
    _ws.subscribe('PAYMENT_RECORDED', _onPaymentEvent);
    _ws.subscribe('PAYMENT_APPLIED', _onPaymentEvent);
    _ws.subscribe('INVOICE_CHARGED', _onLedgerEvent);
  }

  void dispose() {
    _ws.unsubscribe('INVOICE_CREATED', _onInvoiceEvent);
    _ws.unsubscribe('INVOICE_UPDATED', _onInvoiceEvent);
    _ws.unsubscribe('PAYMENT_RECORDED', _onPaymentEvent);
    _ws.unsubscribe('PAYMENT_APPLIED', _onPaymentEvent);
    _ws.unsubscribe('INVOICE_CHARGED', _onLedgerEvent);
  }

  void _onInvoiceEvent(Map<String, dynamic> _) {
    _ref.invalidate(invoiceListProvider(null));
    _ref.invalidate(homeSummaryProvider);
    _ref.invalidate(notificationsProvider);
  }

  void _onPaymentEvent(Map<String, dynamic> _) {
    _ref.invalidate(ledgerEntriesProvider(null));
    _ref.invalidate(ledgerBalanceProvider(null));
    _ref.invalidate(homeSummaryProvider);
    _ref.invalidate(notificationsProvider);
  }

  void _onLedgerEvent(Map<String, dynamic> _) {
    _ref.invalidate(ledgerEntriesProvider(null));
    _ref.invalidate(ledgerBalanceProvider(null));
    _ref.invalidate(homeSummaryProvider);
    _ref.invalidate(notificationsProvider);
  }
}
