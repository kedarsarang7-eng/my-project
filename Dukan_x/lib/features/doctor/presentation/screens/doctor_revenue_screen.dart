import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/owner_id_resolver.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../data/repositories/doctor_dashboard_repository.dart';
import '../../data/repositories/doctor_repository.dart';
import '../../models/doctor_profile_model.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/monthly_analytics_chart.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DoctorRevenueScreen extends StatefulWidget {
  const DoctorRevenueScreen({super.key});

  @override
  State<DoctorRevenueScreen> createState() => _DoctorRevenueScreenState();
}

class _DoctorRevenueScreenState extends State<DoctorRevenueScreen> {
  final DoctorDashboardRepository _repository = sl<DoctorDashboardRepository>();
  final DoctorRepository _doctorRepo = sl<DoctorRepository>();

  Map<String, double> _stats = {'today': 0, 'week': 0, 'month': 0};
  Map<String, int> _chartData = {};

  // Additional metrics
  int _todayVisits = 0;
  int _weekVisits = 0;
  int _monthVisits = 0;

  // Doctor Selection
  List<DoctorProfileModel> _doctors = [];
  String? _selectedDoctorId;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadDoctors();
    if (_selectedDoctorId == null) {
      try {
        // Fail safe: default the selected doctor to the authenticated owner
        // id; never fall back to a 'SYSTEM' bucket.
        _selectedDoctorId = resolveOwnerId(operation: 'doctor revenue');
      } on OwnerIdMissingException {
        // Leave null so _loadData() shows an empty state instead of issuing a
        // cross-tenant revenue query.
      }
    }
    _loadData();
  }

  Future<void> _loadDoctors() async {
    final doctors = await _doctorRepo.getAllDoctors();
    if (mounted) setState(() => _doctors = doctors);
  }

  Future<void> _loadData() async {
    if (_selectedDoctorId == null) {
      // Fail safe: no authenticated owner — stop the spinner and show the
      // empty state rather than querying across tenants.
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    final docId = _selectedDoctorId!;

    // Load revenue stats
    final stats = await _repository.getRevenueStats(docId);

    // Load chart data
    final chartDataDouble = await _repository.getRevenueChartData(docId);
    final Map<String, int> chartDataInt = {};
    chartDataDouble.forEach((key, value) {
      chartDataInt[key] = value.round();
    });

    // Load visit counts
    final visitStats = await _repository.getVisitCounts(docId);

    if (mounted) {
      setState(() {
        _stats = stats;
        _chartData = chartDataInt;
        _todayVisits = visitStats['today'] ?? 0;
        _weekVisits = visitStats['week'] ?? 0;
        _monthVisits = visitStats['month'] ?? 0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Revenue Reports',
      subtitle: 'Financial insights and analytics',
      actions: [
        // Doctor Selector
        if (_doctors.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: FuturisticColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: FuturisticColors.primary.withOpacity(0.3),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDoctorId,
                dropdownColor: FuturisticColors.surface,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                items: _doctors.map((d) {
                  return DropdownMenuItem(
                    value: d.vendorId,
                    child: Text(
                      d.clinicName ?? 'Dr. ${d.specialization ?? "Unknown"}',
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedDoctorId = val);
                    _loadData();
                  }
                },
              ),
            ),
          ),
        const SizedBox(width: 8),
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(
                  responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 20,
                    desktop: 24,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Revenue Cards
                    Text(
                      'Revenue Overview',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRevenueCards(),
                    const SizedBox(height: 24),

                    // Visit Statistics
                    Text(
                      'Patient Visits',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildVisitCards(),
                    const SizedBox(height: 24),

                    // Quick Stats Row
                    _buildQuickStats(),
                    const SizedBox(height: 32),

                    // Monthly Chart
                    Text(
                      'Monthly Revenue Trend',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 300,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FuturisticColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: MonthlyAnalyticsChart(monthlyData: _chartData),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRevenueCards() {
    return Row(
      children: [
        Expanded(
          child: _buildRevenueCard(
            'Today',
            _stats['today']!,
            Icons.today,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRevenueCard(
            'This Week',
            _stats['week']!,
            Icons.date_range,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRevenueCard(
            'This Month',
            _stats['month']!,
            Icons.calendar_month,
            FuturisticColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_formatAmount(amount)}',
            style: GoogleFonts.inter(
              fontSize: responsiveValue<double>(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCards() {
    return Row(
      children: [
        Expanded(child: _buildVisitCard('Today', _todayVisits, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildVisitCard('This Week', _weekVisits, Colors.purple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildVisitCard('This Month', _monthVisits, Colors.teal),
        ),
      ],
    );
  }

  Widget _buildVisitCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.people, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                ' patients',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final avgBillToday = _todayVisits > 0
        ? _stats['today']! / _todayVisits
        : 0.0;
    final avgBillMonth = _monthVisits > 0
        ? _stats['month']! / _monthVisits
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStatItem(
            'Avg Bill (Today)',
            '₹${avgBillToday.toStringAsFixed(0)}',
            Icons.receipt,
          ),
          Container(width: 1, height: 40, color: Colors.white10),
          _buildQuickStatItem(
            'Avg Bill (Month)',
            '₹${avgBillMonth.toStringAsFixed(0)}',
            Icons.assessment,
          ),
          Container(width: 1, height: 40, color: Colors.white10),
          _buildQuickStatItem('Total Patients', '$_monthVisits', Icons.group),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: FuturisticColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
