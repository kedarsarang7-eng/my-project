import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../services/gstr1_service.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class TaxReportScreen extends StatefulWidget {
  const TaxReportScreen({super.key});

  @override
  State<TaxReportScreen> createState() => _TaxReportScreenState();
}

class _TaxReportScreenState extends State<TaxReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GSTR1Service _service = sl<GSTR1Service>();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  GSTR1Data? _data;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _error = "User not logged in";
            _isLoading = false;
          });
        }
        return;
      }

      final report = await _service.generateReport(
        userId,
        _startDate,
        _endDate,
      );

      if (mounted) {
        setState(() {
          _data = report;
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

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: "Tax Reports (GSTR-1)",
      subtitle: "B2B, B2C and HSN Summary",
      actions: [
        DesktopIconButton(
          icon: Icons.calendar_today,
          tooltip: 'Select Date Range',
          onPressed: _selectDateRange,
        ),
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _fetchData,
        ),
        DesktopIconButton(
          icon: Icons.download,
          tooltip: 'Download',
          onPressed: () {
            context.push('/gst-reports');
          },
        ),
      ],
      child: Column(
        children: [
          // Custom TabBar
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: FuturisticColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: FuturisticColors.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: "B2B Invoices"),
                Tab(text: "B2C Small"),
                Tab(text: "HSN Summary"),
              ],
            ),
          ),

          // Date Display
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              "${_startDate.toLocal().toString().split(' ')[0]}  to  ${_endDate.toLocal().toString().split(' ')[0]}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text("Error: $_error"))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildB2BTable(),
                      _buildB2CSTable(),
                      _buildHSNTable(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildB2BTable() {
    if (_data == null || _data!.b2bInvoices.isEmpty) {
      return const Center(child: Text("No B2B Invoices found for this period"));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("GSTIN")),
            DataColumn(label: Text("Name")),
            DataColumn(label: Text("Inv No")),
            DataColumn(label: Text("Date")),
            DataColumn(label: Text("Value")),
            DataColumn(label: Text("POS")),
            DataColumn(label: Text("Tax Rate")),
            DataColumn(label: Text("Taxable")),
            DataColumn(label: Text("IGST")),
            DataColumn(label: Text("CGST")),
            DataColumn(label: Text("SGST")),
          ],
          rows: _data!.b2bInvoices.map((inv) {
            return DataRow(
              cells: [
                DataCell(Text(inv.gstIn)),
                DataCell(Text(inv.customerName)),
                DataCell(Text(inv.invoiceNumber)),
                DataCell(Text(inv.date.toString().split(' ')[0])),
                DataCell(Text(inv.invoiceValue.toStringAsFixed(2))),
                DataCell(Text(inv.placeOfSupply)),
                DataCell(Text("${inv.taxRate}%")),
                DataCell(Text(inv.taxableValue.toStringAsFixed(2))),
                DataCell(Text(inv.igst.toStringAsFixed(2))),
                DataCell(Text(inv.cgst.toStringAsFixed(2))),
                DataCell(Text(inv.sgst.toStringAsFixed(2))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildB2CSTable() {
    if (_data == null || _data!.b2cSmallInvoices.isEmpty) {
      return const Center(child: Text("No B2C Small invoices"));
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Place of Supply")),
          DataColumn(label: Text("Tax Rate")),
          DataColumn(label: Text("Taxable Value")),
          DataColumn(label: Text("Cess")),
          DataColumn(label: Text("Type")),
        ],
        rows: _data!.b2cSmallInvoices.map((inv) {
          return DataRow(
            cells: [
              DataCell(Text(inv.placeOfSupply)),
              DataCell(Text("${inv.taxRate}%")),
              DataCell(Text(inv.taxableValue.toStringAsFixed(2))),
              DataCell(Text(inv.cess.toStringAsFixed(2))),
              DataCell(Text(inv.type)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHSNTable() {
    if (_data == null || _data!.hsnSummary.isEmpty) {
      return const Center(child: Text("No HSN Summary available"));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("HSN")),
            DataColumn(label: Text("Description")),
            DataColumn(label: Text("UQC")),
            DataColumn(label: Text("Total Qty")),
            DataColumn(label: Text("Total Value")),
            DataColumn(label: Text("Taxable")),
            DataColumn(label: Text("IGST")),
            DataColumn(label: Text("CGST")),
            DataColumn(label: Text("SGST")),
          ],
          rows: _data!.hsnSummary.map((hsn) {
            return DataRow(
              cells: [
                DataCell(Text(hsn.hsn)),
                DataCell(Text(hsn.description)),
                DataCell(Text(hsn.uqc)),
                DataCell(Text(hsn.totalQuantity.toStringAsFixed(2))),
                DataCell(Text(hsn.totalValue.toStringAsFixed(2))),
                DataCell(Text(hsn.taxableValue.toStringAsFixed(2))),
                DataCell(Text(hsn.igst.toStringAsFixed(2))),
                DataCell(Text(hsn.cgst.toStringAsFixed(2))),
                DataCell(Text(hsn.sgst.toStringAsFixed(2))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
