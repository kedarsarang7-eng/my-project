// ============================================================================
// DUNNING CONFIGURATION SCREEN - PAYMENT REMINDER RULES
// ============================================================================
// Manage dunning rules (escalation schedule) and view reminder history.
// Uses sl<DunningService> for CRUD and processing.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/di/service_locator.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/billing/dunning_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../../../widgets/modern_ui_components.dart';
import '../../../widgets/glass_morphism.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DunningConfigScreen extends StatefulWidget {
  const DunningConfigScreen({super.key});

  @override
  State<DunningConfigScreen> createState() => _DunningConfigScreenState();
}

class _DunningConfigScreenState extends State<DunningConfigScreen>
    with SingleTickerProviderStateMixin {
  final _dunningService = sl<DunningService>();
  final _session = sl<SessionManager>();
  late TabController _tabController;

  List<DunningRuleEntity> _rules = [];
  List<DunningLogEntity> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final userId = _session.ownerId;
    if (userId == null) return;

    final rules = await _dunningService.getRules(userId);
    final logs = await _dunningService.getRecentLogs(userId);

    if (!mounted) return;
    setState(() {
      _rules = rules;
      _logs = logs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: _buildAppBar(isDark),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  FuturisticColors.primary,
                ),
              ),
            )
          : BoundedBox(
              maxWidth: 800,
              child: TabBarView(
                controller: _tabController,
                children: [_buildRulesTab(isDark), _buildLogsTab(isDark)],
              ),
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark
          ? FuturisticColors.darkSurface
          : FuturisticColors.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF9800)],
              ),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              boxShadow: AppShadows.glowShadow(const Color(0xFFFF6B35)),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Payment Reminders',
            style: AppTypography.headlineMedium.copyWith(
              color: isDark
                  ? FuturisticColors.darkTextPrimary
                  : FuturisticColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: FuturisticColors.primary,
        labelColor: FuturisticColors.primary,
        unselectedLabelColor: isDark
            ? FuturisticColors.darkTextSecondary
            : FuturisticColors.textSecondary,
        tabs: const [
          Tab(icon: Icon(Icons.rule), text: 'Rules'),
          Tab(icon: Icon(Icons.history), text: 'Activity Log'),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: AppSpacing.md),
          decoration: BoxDecoration(
            color: FuturisticColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(
              color: FuturisticColors.success.withValues(alpha: 0.3),
            ),
          ),
          child: IconButton(
            icon: Icon(Icons.play_arrow, color: FuturisticColors.success),
            tooltip: 'Run Dunning Now',
            onPressed: _runDunning,
          ),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF9800)],
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: AppShadows.glowShadow(const Color(0xFFFF6B35)),
      ),
      child: FloatingActionButton.extended(
        onPressed: _addRule,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'ADD RULE',
          style: AppTypography.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  // ============================================
  // RULES TAB
  // ============================================

  Widget _buildRulesTab(bool isDark) {
    if (_rules.isEmpty) {
      return Center(
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          borderRadius: AppBorderRadius.xxl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF9800)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.glowShadow(const Color(0xFFFF6B35)),
                ),
                child: const Icon(
                  Icons.notifications_off,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No Dunning Rules',
                style: AppTypography.headlineMedium.copyWith(
                  color: isDark
                      ? FuturisticColors.darkTextPrimary
                      : FuturisticColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Set up automated payment reminders\nor tap below to use defaults.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? FuturisticColors.darkTextSecondary
                      : FuturisticColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _seedDefaults,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('USE DEFAULT RULES'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FuturisticColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _rules.length,
      itemBuilder: (context, index) => _buildRuleCard(_rules[index], isDark),
    );
  }

  Widget _buildRuleCard(DunningRuleEntity rule, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ModernCard(
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: FuturisticColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                      child: Center(
                        child: Text(
                          '${rule.sortOrder}',
                          style: AppTypography.headlineMedium.copyWith(
                            color: FuturisticColors.warning,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.name,
                          style: AppTypography.labelLarge.copyWith(
                            color: isDark
                                ? FuturisticColors.darkTextPrimary
                                : FuturisticColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${rule.daysAfterDue} days after due date',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? FuturisticColors.darkTextSecondary
                                : FuturisticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: FuturisticColors.error,
                    size: 20,
                  ),
                  onPressed: () => _deleteRule(rule.id),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: [
                if (rule.sendWhatsapp)
                  Chip(
                    avatar: const Icon(Icons.chat, size: 16),
                    label: const Text('WhatsApp'),
                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                    labelStyle: const TextStyle(fontSize: 12),
                  ),

                if (rule.sendNotification)
                  Chip(
                    avatar: const Icon(Icons.notifications, size: 16),
                    label: const Text('In-App'),
                    backgroundColor: FuturisticColors.primary.withValues(alpha: 0.15),
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                if (rule.autoEscalate)
                  Chip(
                    avatar: Icon(
                      Icons.warning,
                      size: 16,
                      color: FuturisticColors.error,
                    ),
                    label: Text('→ ${rule.escalateToStatus ?? "ESCALATE"}'),
                    backgroundColor: FuturisticColors.error.withValues(alpha: 0.15),
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // LOGS TAB
  // ============================================

  Widget _buildLogsTab(bool isDark) {
    if (_logs.isEmpty) {
      return Center(
        child: Text(
          'No reminder activity yet.',
          style: AppTypography.bodyMedium.copyWith(
            color: isDark
                ? FuturisticColors.darkTextSecondary
                : FuturisticColors.textSecondary,
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final currencyFormat = NumberFormat.currency(symbol: sl<CurrencyService>().symbol, decimalDigits: 2);

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final isSuccess = log.status == 'SENT';

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ModernCard(
            backgroundColor: isDark
                ? FuturisticColors.darkSurface
                : FuturisticColors.surface,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        (isSuccess
                                ? FuturisticColors.success
                                : FuturisticColors.error)
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: Icon(
                    isSuccess ? Icons.check : Icons.close,
                    color: isSuccess
                        ? FuturisticColors.success
                        : FuturisticColors.error,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${log.channel} — ${log.status}',
                        style: AppTypography.labelMedium.copyWith(
                          color: isDark
                              ? FuturisticColors.darkTextPrimary
                              : FuturisticColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${currencyFormat.format(log.amountDue)} overdue (${log.daysOverdue}d)',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? FuturisticColors.darkTextSecondary
                              : FuturisticColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  dateFormat.format(log.createdAt),
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark
                        ? FuturisticColors.darkTextSecondary
                        : FuturisticColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // ACTIONS
  // ============================================

  Future<void> _seedDefaults() async {
    final userId = _session.ownerId;
    if (userId == null) return;
    await _dunningService.seedDefaultRules(userId);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Default dunning rules created!'),
        backgroundColor: FuturisticColors.success,
      ),
    );
  }

  Future<void> _runDunning() async {
    final userId = _session.ownerId;
    if (userId == null) return;

    final count = await _dunningService.processOverdueBills(userId);
    await _loadData(); // Refresh logs
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0 ? '✅ Sent $count reminder(s)!' : 'No overdue bills found.',
        ),
        backgroundColor: count > 0
            ? FuturisticColors.success
            : FuturisticColors.surface,
      ),
    );
  }

  Future<void> _deleteRule(String id) async {
    await _dunningService.deleteRule(id);
    await _loadData();
  }

  void _addRule() {
    final userId = _session.ownerId;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _AddRuleDialog(userId: userId, onSaved: _loadData),
    );
  }
}

// ============================================================================
// ADD RULE DIALOG
// ============================================================================

class _AddRuleDialog extends StatefulWidget {
  final String userId;
  final VoidCallback onSaved;

  const _AddRuleDialog({required this.userId, required this.onSaved});

  @override
  State<_AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends State<_AddRuleDialog> {
  final _nameController = TextEditingController();
  final _daysController = TextEditingController();
  final _templateController = TextEditingController();
  bool _sendWhatsapp = true;
  bool _sendNotification = true;
  bool _autoEscalate = false;

  @override
  void dispose() {
    _nameController.dispose();
    _daysController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_alert, color: FuturisticColors.warning),
          const SizedBox(width: 8),
          const Text('New Dunning Rule'),
        ],
      ),
      content: SizedBox(
        width: responsiveValue<double>(context, mobile: 300, tablet: 420, desktop: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Rule Name *',
                  hintText: 'e.g. "Gentle Reminder"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Days After Due Date *',
                  hintText: 'e.g. 3',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _templateController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Template',
                  hintText:
                      'Use {{customer_name}}, {{amount}}, {{invoice_number}}, {{shop_name}}',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Send WhatsApp'),
                value: _sendWhatsapp,
                onChanged: (v) => setState(() => _sendWhatsapp = v),
                dense: true,
              ),
              SwitchListTile(
                title: const Text('In-App Notification'),
                value: _sendNotification,
                onChanged: (v) => setState(() => _sendNotification = v),
                dense: true,
              ),
              SwitchListTile(
                title: const Text('Auto-Escalate to PAST_DUE'),
                value: _autoEscalate,
                onChanged: (v) => setState(() => _autoEscalate = v),
                dense: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: FuturisticColors.primary,
          ),
          onPressed: _save,
          child: const Text('SAVE RULE', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final days = int.tryParse(_daysController.text) ?? 0;
    if (name.isEmpty || days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and days are required.')),
      );
      return;
    }

    final now = DateTime.now();
    final rule = DunningRulesCompanion(
      id: Value(const Uuid().v4()),
      userId: Value(widget.userId),
      name: Value(name),
      daysAfterDue: Value(days),
      sortOrder: Value(days), // Use days as natural sort order
      sendWhatsapp: Value(_sendWhatsapp),
      sendNotification: Value(_sendNotification),
      autoEscalate: Value(_autoEscalate),
      escalateToStatus: _autoEscalate
          ? const Value('PAST_DUE')
          : const Value.absent(),
      whatsappTemplate: _templateController.text.trim().isNotEmpty
          ? Value(_templateController.text.trim())
          : const Value.absent(),
      isActive: const Value(true),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await sl<DunningService>().saveRule(rule);
    widget.onSaved();
    if (!mounted) return;
    Navigator.pop(context);
  }
}
