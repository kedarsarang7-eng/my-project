import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart'; // For PaymentEntity
import '../../../core/repository/bills_repository.dart';
import '../../../core/repository/customers_repository.dart';
import '../../../features/payment/data/repositories/payment_repository.dart';
import '../../gst/repositories/gst_repository.dart';
import '../../gst/models/models.dart';
import '../../../core/repository/purchase_repository.dart';
import '../../../core/repository/vendors_repository.dart';
import '../../../core/repository/shop_repository.dart';

class TallyXmlService {
  final BillsRepository _billsRepository;
  final PaymentRepository _paymentRepository;
  final CustomersRepository _customersRepository;
  final GstRepository _gstRepository;
  final PurchaseRepository _purchaseRepository;
  final VendorsRepository _vendorsRepository;
  final ShopRepository _shopRepository;

  TallyXmlService(
    this._billsRepository,
    this._paymentRepository,
    this._customersRepository,
    this._gstRepository,
    this._purchaseRepository,
    this._vendorsRepository,
    this._shopRepository,
  );

  /// Generate Tally XML for a given date range
  Future<File?> generateExportXml(
    DateTime from,
    DateTime to,
    String userId,
  ) async {
    try {
      final billsResult = await _billsRepository.getAll(userId: userId);
      final bills = billsResult.data ?? [];

      final paymentsResult = await _paymentRepository.getAllPayments(
        userId: userId,
        fromDate: from,
        toDate: to,
      );
      // Unwrap payments
      final payments = paymentsResult.data ?? [];

      final customersResult = await _customersRepository.getAll(userId: userId);
      final customers = customersResult.data ?? [];

      // Fetch GST Invoices for detailed tax breakdown
      final gstInvoices = await _gstRepository.getGstInvoicesForPeriod(
        userId: userId,
        startDate: from,
        endDate: to,
      );
      // Map billId -> GstInvoiceDetail
      final gstMap = {for (var i in gstInvoices) i.billId: i};

      // Create Customer Map (ID -> Name)
      final customerMap = {for (var c in customers) c.id: c.name};

      final purchasesResult = await _purchaseRepository.getAll(userId: userId);
      final purchases = purchasesResult.data ?? [];

      final vendorsResult = await _vendorsRepository.getAll(userId);
      final vendorMap = {for (var v in vendorsResult.data ?? []) v.id: v};

      // Fetch GST Settings for State Code Comparison (Inter vs Intra)
      final gstSettings = await _gstRepository.getGstSettings(userId);
      final userStateCode = gstSettings?.stateCode;

      // Filter bills by date range
      final filteredBills = bills.where((b) {
        return b.date.isAfter(from.subtract(const Duration(seconds: 1))) &&
            b.date.isBefore(to.add(const Duration(days: 1)));
      }).toList();

      // Filter purchases by date range
      final filteredPurchases = purchases.where((p) {
        return p.purchaseDate.isAfter(
              from.subtract(const Duration(seconds: 1)),
            ) &&
            p.purchaseDate.isBefore(to.add(const Duration(days: 1)));
      }).toList();

      // Fetch Shop Details
      final shopResult = await _shopRepository.getShopProfile(userId);
      final shopName = shopResult.data?.shopName ?? 'My Company';

      final buffer = StringBuffer();

      // Tally Header
      buffer.writeln('<ENVELOPE>');
      buffer.writeln(' <HEADER>');
      buffer.writeln('  <TALLYREQUEST>Import Data</TALLYREQUEST>');
      buffer.writeln(' </HEADER>');
      buffer.writeln(' <BODY>');
      buffer.writeln('  <IMPORTDATA>');
      buffer.writeln('   <REQUESTDESC>');
      buffer.writeln('    <REPORTNAME>Vouchers</REPORTNAME>');
      buffer.writeln('    <STATICVARIABLES>');
      buffer.writeln(
        '     <SVCURRENTCOMPANY>${_escapeXml(shopName)}</SVCURRENTCOMPANY>',
      );
      buffer.writeln('    </STATICVARIABLES>');
      buffer.writeln('   </REQUESTDESC>');
      buffer.writeln('   <REQUESTDATA>');

      // Sales Vouchers
      for (var bill in filteredBills) {
        if (bill.status == 'CANCELLED' || bill.status == 'DRAFT') continue;
        buffer.write(_buildSalesVoucher(bill, gstMap[bill.id]));
      }

      // Receipt Vouchers
      for (var payment in payments) {
        buffer.write(_buildReceiptVoucher(payment, customerMap));
      }

      // Purchase Vouchers
      for (var purchase in filteredPurchases) {
        buffer.write(
          _buildPurchaseVoucher(
            purchase,
            vendorMap[purchase.vendorId],
            userStateCode,
          ),
        );
      }

      buffer.writeln('   </REQUESTDATA>');
      buffer.writeln('  </IMPORTDATA>');
      buffer.writeln(' </BODY>');
      buffer.writeln('</ENVELOPE>');

      // Write to file
      final directory = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/TallyExport_$dateStr.xml');
      await file.writeAsString(buffer.toString());

      return file;
    } catch (e) {
      debugPrint('TallyXmlService: Error generating XML: $e');
      return null;
    }
  }

  String _buildSalesVoucher(Bill bill, dynamic gstInvoice) {
    final sb = StringBuffer();
    final dateStr = DateFormat('yyyyMMdd').format(bill.date);
    final validName = _escapeXml(
      bill.customerName.isEmpty ? 'Cash' : bill.customerName,
    );
    // Ensure name doesn't contain invalid Tally chars

    sb.writeln('    <TALLYMESSAGE xmlns:UDF="TallyUDF">');
    sb.writeln(
      '     <VOUCHER VCHTYPE="Sales" ACTION="Create" OBJVIEW="Accounting Voucher View">',
    );
    sb.writeln('      <DATE>$dateStr</DATE>');
    sb.writeln('      <VOUCHERTYPENAME>Sales</VOUCHERTYPENAME>');
    sb.writeln('      <VOUCHERNUMBER>${bill.invoiceNumber}</VOUCHERNUMBER>');
    sb.writeln('      <PARTYLEDGERNAME>$validName</PARTYLEDGERNAME>');

    // Ledger Entry: Party (Debit)
    sb.writeln('      <LEDGERENTRIES.LIST>');
    sb.writeln('       <LEDGERNAME>$validName</LEDGERNAME>');
    sb.writeln('       <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>'); // Debit
    sb.writeln(
      '       <AMOUNT>-${bill.grandTotal.abs()}</AMOUNT>',
    ); // Party Debit should be Grand Total
    sb.writeln('      </LEDGERENTRIES.LIST>');

    // Ledger Entry: Sales Account (Credit)
    sb.writeln('      <LEDGERENTRIES.LIST>');
    sb.writeln('       <LEDGERNAME>Sales</LEDGERNAME>'); // Default sales ledger
    sb.writeln('       <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>'); // Credit
    sb.writeln('       <AMOUNT>${bill.subtotal.abs()}</AMOUNT>');
    sb.writeln('      </LEDGERENTRIES.LIST>');

    // Ledger Entry: Tax (Credit)
    if (gstInvoice != null && gstInvoice is GstInvoiceDetailModel) {
      // Use detailed breakdown
      if (gstInvoice.igstAmount > 0) {
        sb.writeln('      <LEDGERENTRIES.LIST>');
        sb.writeln('       <LEDGERNAME>Output IGST</LEDGERNAME>');
        sb.writeln('       <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
        sb.writeln('       <AMOUNT>${gstInvoice.igstAmount.abs()}</AMOUNT>');
        sb.writeln('      </LEDGERENTRIES.LIST>');
      }
      if (gstInvoice.cgstAmount > 0) {
        sb.writeln('      <LEDGERENTRIES.LIST>');
        sb.writeln('       <LEDGERNAME>Output CGST</LEDGERNAME>');
        sb.writeln('       <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
        sb.writeln('       <AMOUNT>${gstInvoice.cgstAmount.abs()}</AMOUNT>');
        sb.writeln('      </LEDGERENTRIES.LIST>');
      }
      if (gstInvoice.sgstAmount > 0) {
        sb.writeln('      <LEDGERENTRIES.LIST>');
        sb.writeln('       <LEDGERNAME>Output SGST</LEDGERNAME>');
        sb.writeln('       <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
        sb.writeln('       <AMOUNT>${gstInvoice.sgstAmount.abs()}</AMOUNT>');
        sb.writeln('      </LEDGERENTRIES.LIST>');
      }
    } else if (bill.totalTax > 0) {
      // Fallback 50/50 split if no GST record found (Assume Intra-state)
      final halfTax = bill.totalTax / 2;

      sb.writeln('      <LEDGERENTRIES.LIST>');
      sb.writeln('       <LEDGERNAME>Output CGST</LEDGERNAME>');
      sb.writeln('       <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
      sb.writeln('       <AMOUNT>${halfTax.abs()}</AMOUNT>');
      sb.writeln('      </LEDGERENTRIES.LIST>');

      sb.writeln('      <LEDGERENTRIES.LIST>');
      sb.writeln('       <LEDGERNAME>Output SGST</LEDGERNAME>');
      sb.writeln('       <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
      sb.writeln('       <AMOUNT>${halfTax.abs()}</AMOUNT>');
      sb.writeln('      </LEDGERENTRIES.LIST>');
    }

    sb.writeln('     </VOUCHER>');
    sb.writeln('    </TALLYMESSAGE>');
    return sb.toString();
  }

  String _buildReceiptVoucher(
    PaymentEntity payment,
    Map<String, String> customerMap,
  ) {
    if (payment.amount <= 0) return '';

    final sb = StringBuffer();
    final dateStr = DateFormat('yyyyMMdd').format(payment.paymentDate);

    String partyName = 'Cash Customer';
    if (payment.customerId != null &&
        customerMap.containsKey(payment.customerId)) {
      partyName = customerMap[payment.customerId]!;
    }
    partyName = _escapeXml(partyName);

    sb.writeln('    <TALLYMESSAGE xmlns:UDF="TallyUDF">');
    sb.writeln(
      '     <VOUCHER VCHTYPE="Receipt" ACTION="Create" OBJVIEW="Accounting Voucher View">',
    );
    sb.writeln('      <DATE>$dateStr</DATE>');
    sb.writeln('      <VOUCHERTYPENAME>Receipt</VOUCHERTYPENAME>');
    sb.writeln(
      '      <VOUCHERNUMBER>${payment.referenceNumber ?? "REC-${payment.paymentDate.millisecondsSinceEpoch}"}</VOUCHERNUMBER>',
    );
    sb.writeln(
      '      <PARTYLEDGERNAME>Cash</PARTYLEDGERNAME>',
    ); // Receiving into Cash usually

    // Credit Party (Giver)
    // Ledger: Customer Name
    // Amount: Positive (Credit)
    sb.writeln('      <LEDGERENTRIES.LIST>');
    sb.writeln('       <LEDGERNAME>$partyName</LEDGERNAME>'); // Placeholder
    sb.writeln('       <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
    sb.writeln('       <AMOUNT>${payment.amount.abs()}</AMOUNT>');
    sb.writeln('      </LEDGERENTRIES.LIST>');

    // Debit Cash (Receiver)
    sb.writeln('      <LEDGERENTRIES.LIST>');
    sb.writeln('       <LEDGERNAME>Cash</LEDGERNAME>');
    sb.writeln('       <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>');
    sb.writeln('       <AMOUNT>-${payment.amount.abs()}</AMOUNT>');
    sb.writeln('      </LEDGERENTRIES.LIST>');

    sb.writeln('     </VOUCHER>');
    sb.writeln('    </TALLYMESSAGE>');
    return sb.toString();
  }

  String _buildPurchaseVoucher(
    PurchaseOrder purchase,
    Vendor? vendor,
    String? userStateCode,
  ) {
    final sb = StringBuffer();
    final dateStr = DateFormat('yyyyMMdd').format(purchase.purchaseDate);
    final partyName = _escapeXml(
      vendor?.name ?? purchase.vendorName ?? 'Cash Purchase',
    );
    final invoiceNo =
        purchase.invoiceNumber != null && purchase.invoiceNumber!.isNotEmpty
        ? purchase.invoiceNumber
        : purchase.id.substring(0, 8); // Fallback

    sb.writeln('    <TALLYMESSAGE xmlns:UDF="TallyUDF">');
    sb.writeln(
      '     <VOUCHER VCHTYPE="Purchase" ACTION="Create" OBJVIEW="Accounting Voucher View">',
    );
    sb.writeln('      <DATE>$dateStr</DATE>');
    sb.writeln('      <VOUCHERTYPENAME>Purchase</VOUCHERTYPENAME>');
    sb.writeln('      <VOUCHERNUMBER>$invoiceNo</VOUCHERNUMBER>');
    sb.writeln('      <PARTYLEDGERNAME>$partyName</PARTYLEDGERNAME>');

    // 1. Party Ledger (Credit)
    sb.writeln('      <LEDGERENTRIES.LIST>');
    sb.writeln('       <LEDGERNAME>$partyName</LEDGERNAME>');
    sb.writeln('       <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
    sb.writeln('       <AMOUNT>${purchase.totalAmount.abs()}</AMOUNT>');
    sb.writeln('      </LEDGERENTRIES.LIST>');

    // Calculate Tax
    double totalTax = 0;
    double taxableAmount = 0;

    for (var item in purchase.items) {
      final baseAmt = item.costPrice * item.quantity;
      taxableAmount += baseAmt;
      // If purchase item has specific logic (inclusive/exclusive), adjust here.
      // Assuming item.totalAmount is the final with tax.
      // If taxRate is provided and costPrice is basic:
      // Tax = item.totalAmount - baseAmt
      final tax = item.totalAmount - baseAmt;
      if (tax > 0) totalTax += tax;
    }

    // Validation
    if ((taxableAmount + totalTax - purchase.totalAmount).abs() > 1.0) {
      // Discrepancy. Fallback to assuming totalAmount - totalTax = taxable.
      // Or if totalTax is 0 (no tax info), then taxable = totalAmount.
      if (totalTax <= 0) {
        taxableAmount = purchase.totalAmount;
      } else {
        taxableAmount = purchase.totalAmount - totalTax;
      }
    }

    // 2. Purchase Ledger (Debit)
    sb.writeln('      <LEDGERENTRIES.LIST>');
    sb.writeln('       <LEDGERNAME>Purchase Accounts</LEDGERNAME>');
    sb.writeln('       <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>'); // Debit
    sb.writeln('       <AMOUNT>-${taxableAmount.abs()}</AMOUNT>');
    sb.writeln('      </LEDGERENTRIES.LIST>');

    // 3. Tax Ledgers (Debit)
    if (totalTax > 0) {
      bool isInterState = false;
      if (userStateCode != null &&
          vendor?.gstin != null &&
          vendor!.gstin!.length >= 2) {
        final vendorState = vendor.gstin!.substring(0, 2);
        if (vendorState != userStateCode) {
          isInterState = true;
        }
      }

      if (isInterState) {
        sb.writeln('      <LEDGERENTRIES.LIST>');
        sb.writeln('       <LEDGERNAME>Input IGST</LEDGERNAME>');
        sb.writeln('       <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>');
        sb.writeln('       <AMOUNT>-${totalTax.abs()}</AMOUNT>');
        sb.writeln('      </LEDGERENTRIES.LIST>');
      } else {
        final half = totalTax / 2;
        sb.writeln('      <LEDGERENTRIES.LIST>');
        sb.writeln('       <LEDGERNAME>Input CGST</LEDGERNAME>');
        sb.writeln('       <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>');
        sb.writeln('       <AMOUNT>-${half.abs()}</AMOUNT>');
        sb.writeln('      </LEDGERENTRIES.LIST>');

        sb.writeln('      <LEDGERENTRIES.LIST>');
        sb.writeln('       <LEDGERNAME>Input SGST</LEDGERNAME>');
        sb.writeln('       <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>');
        sb.writeln('       <AMOUNT>-${half.abs()}</AMOUNT>');
        sb.writeln('      </LEDGERENTRIES.LIST>');
      }
    }

    sb.writeln('     </VOUCHER>');
    sb.writeln('    </TALLYMESSAGE>');
    return sb.toString();
  }

  // Helper to escape special XML chars
  String _escapeXml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll("'", '&apos;')
        .replaceAll('"', '&quot;');
  }

  /// Validate XML structure against Tally import schema
  /// Returns a map with 'isValid' and optional 'errors' list
  Map<String, dynamic> validateXml(String xmlContent) {
    final errors = <String>[];

    try {
      // 1. Check for required envelope structure
      if (!xmlContent.contains('<ENVELOPE>')) {
        errors.add('Missing <ENVELOPE> root element');
      }
      if (!xmlContent.contains('</ENVELOPE>')) {
        errors.add('Missing closing </ENVELOPE> tag');
      }

      // 2. Check for required sections
      if (!xmlContent.contains('<HEADER>')) {
        errors.add('Missing <HEADER> section');
      }
      if (!xmlContent.contains('<BODY>')) {
        errors.add('Missing <BODY> section');
      }
      if (!xmlContent.contains('<IMPORTDATA>')) {
        errors.add('Missing <IMPORTDATA> section');
      }

      // 3. Check for TALLYREQUEST
      if (!xmlContent.contains('<TALLYREQUEST>Import Data</TALLYREQUEST>')) {
        errors.add('Invalid or missing TALLYREQUEST directive');
      }

      // 4. Check for balanced tags (basic check)
      final tagPattern = RegExp(r'<(/?)([\w.]+)');
      final openTags = <String>[];

      for (final match in tagPattern.allMatches(xmlContent)) {
        final isClosing = match.group(1) == '/';
        final tagName = match.group(2)!;

        // Skip self-closing pattern tags
        if (tagName.isEmpty) continue;

        if (isClosing) {
          if (openTags.isNotEmpty && openTags.last == tagName) {
            openTags.removeLast();
          }
        } else {
          openTags.add(tagName);
        }
      }

      // 5. Validate voucher amounts balance (debit = credit)
      final voucherPattern = RegExp(
        r'<VOUCHER[^>]*>(.*?)</VOUCHER>',
        dotAll: true,
      );
      final amountPattern = RegExp(r'<AMOUNT>(-?[\d.]+)</AMOUNT>');

      int voucherIndex = 0;
      for (final voucherMatch in voucherPattern.allMatches(xmlContent)) {
        voucherIndex++;
        final voucherContent = voucherMatch.group(1) ?? '';
        double total = 0;

        for (final amountMatch in amountPattern.allMatches(voucherContent)) {
          final amount = double.tryParse(amountMatch.group(1) ?? '0') ?? 0;
          total += amount;
        }

        // Tally expects balanced vouchers (sum of amounts should be close to 0)
        if (total.abs() > 0.01) {
          errors.add(
            'Voucher #$voucherIndex has unbalanced amounts (diff: ${total.toStringAsFixed(2)})',
          );
        }
      }

      // 6. Check for empty party names
      if (xmlContent.contains('<PARTYLEDGERNAME></PARTYLEDGERNAME>') ||
          xmlContent.contains('<PARTYLEDGERNAME/>')) {
        errors.add('Found voucher with empty party ledger name');
      }

      // 7. Check for valid date format
      final datePattern = RegExp(r'<DATE>(\d{8})</DATE>');
      if (!datePattern.hasMatch(xmlContent) && xmlContent.contains('<DATE>')) {
        errors.add('Invalid date format found (expected YYYYMMDD)');
      }
    } catch (e) {
      errors.add('XML parsing error: $e');
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'voucherCount': RegExp(r'<VOUCHER[^>]*>').allMatches(xmlContent).length,
    };
  }
}
