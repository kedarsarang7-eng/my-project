// ============================================================================
// DECORATION & CATERING — BOOKING FORM (Create / Edit Dialog)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';

class DcBookingForm extends ConsumerStatefulWidget {
  final EventBooking? existing;
  final void Function(EventBooking) onSaved;

  const DcBookingForm({super.key, this.existing, required this.onSaved});

  @override
  ConsumerState<DcBookingForm> createState() => _DcBookingFormState();
}

class _DcBookingFormState extends ConsumerState<DcBookingForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  late TabController _tabs;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _venueCtrl;
  late TextEditingController _venueAddrCtrl;
  late TextEditingController _guestCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _advanceCtrl;
  late TextEditingController _notesCtrl;

  EventType _eventType = EventType.wedding;
  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  DateTime? _eventEndDate;
  bool _includesDecoration = true;
  bool _includesCatering = true;
  String? _decorationThemeId;
  String? _cateringPackageId;
  final Set<String> _selectedStaffIds = {};
  String? _eventEndDateError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.customerName ?? '');
    _phoneCtrl = TextEditingController(text: e?.customerPhone ?? '');
    _emailCtrl = TextEditingController(text: e?.customerEmail ?? '');
    _titleCtrl = TextEditingController(text: e?.eventTitle ?? '');
    _venueCtrl = TextEditingController(text: e?.venue ?? '');
    _venueAddrCtrl = TextEditingController(text: e?.venueAddress ?? '');
    _guestCtrl = TextEditingController(text: e?.guestCount.toString() ?? '');
    _amountCtrl = TextEditingController(
      text: e?.quotedAmount.toStringAsFixed(0) ?? '',
    );
    _advanceCtrl = TextEditingController(
      text: e?.advancePaid.toStringAsFixed(0) ?? '0',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    if (e != null) {
      _eventType = e.eventType;
      _eventDate = e.eventDate;
      _eventEndDate = e.eventEndDate;
      _includesDecoration = e.includesDecoration;
      _includesCatering = e.includesCatering;
      _decorationThemeId = e.decorationThemeId;
      _cateringPackageId = e.cateringPackageId;
      _selectedStaffIds.addAll(e.assignedStaffIds);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _titleCtrl,
      _venueCtrl,
      _venueAddrCtrl,
      _guestCtrl,
      _amountCtrl,
      _advanceCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final themesAsync = ref.watch(dcThemesProvider);
    final pkgsAsync = ref.watch(dcPackagesProvider);
    final staffAsync = ref.watch(dcStaffProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.event_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit Booking' : 'New Event Booking',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isEdit
                                ? 'Update booking details'
                                : 'Fill in details to create a booking',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Close form',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabs,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'Customer'),
                      Tab(text: 'Event'),
                      Tab(text: 'Services'),
                      Tab(text: 'Staff'),
                    ],
                  ),
                ],
              ),
            ),
            // ── Body ──
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    // Tab 0: Customer
                    _TabPage(
                      children: [
                        _section('Customer Information'),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                _nameCtrl,
                                'Customer Name',
                                required: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                _phoneCtrl,
                                'Phone Number',
                                required: true,
                                keyboard: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _emailCtrl,
                          'Email (optional)',
                          keyboard: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        _section('Billing'),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                _amountCtrl,
                                'Quoted Amount (₹)',
                                required: true,
                                keyboard: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                _advanceCtrl,
                                'Advance Paid (₹)',
                                keyboard: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _notesCtrl,
                          'Notes / Special Requirements',
                          maxLines: 3,
                        ),
                      ],
                    ),
                    // Tab 1: Event
                    _TabPage(
                      children: [
                        _section('Event Details'),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<EventType>(
                                value: _eventType,
                                decoration: _inputDec('Event Type'),
                                items: EventType.values
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(_eventLabel(t)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _eventType = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _eventDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 730),
                                    ),
                                  );
                                  if (d != null)
                                    setState(() {
                                      _eventDate = d;
                                      // Re-validate end date
                                      if (_eventEndDate != null &&
                                          _eventEndDate!.isBefore(_eventDate)) {
                                        _eventEndDateError =
                                            'End date must be on or after start date';
                                      } else {
                                        _eventEndDateError = null;
                                      }
                                    });
                                },
                                child: InputDecorator(
                                  decoration: _inputDec('Event Start Date'),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 14,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat(
                                          'd MMM yyyy',
                                        ).format(_eventDate),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Event End Date (optional — for multi-day events)
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _eventEndDate ?? _eventDate,
                              firstDate: _eventDate,
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                            );
                            if (d != null) {
                              setState(() {
                                if (d.isBefore(_eventDate)) {
                                  _eventEndDateError =
                                      'End date must be on or after start date';
                                  _eventEndDate = null;
                                } else {
                                  _eventEndDate = d;
                                  _eventEndDateError = null;
                                }
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration:
                                _inputDec(
                                  'Event End Date (optional — multi-day)',
                                ).copyWith(
                                  errorText: _eventEndDateError,
                                  suffixIcon: _eventEndDate != null
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                            size: 16,
                                          ),
                                          tooltip: 'Clear end date',
                                          onPressed: () => setState(() {
                                            _eventEndDate = null;
                                            _eventEndDateError = null;
                                          }),
                                        )
                                      : null,
                                ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.date_range_rounded,
                                  size: 14,
                                  color: Color(0xFF9CA3AF),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _eventEndDate != null
                                      ? DateFormat(
                                          'd MMM yyyy',
                                        ).format(_eventEndDate!)
                                      : 'Single-day event',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _eventEndDate != null
                                        ? null
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _field(_titleCtrl, 'Event Title', required: true),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                _venueCtrl,
                                'Venue Name',
                                required: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                _guestCtrl,
                                'Guest Count',
                                required: true,
                                keyboard: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(_venueAddrCtrl, 'Venue Address'),
                      ],
                    ),
                    // Tab 2: Services
                    _TabPage(
                      children: [
                        _section('Services Included'),
                        Row(
                          children: [
                            Expanded(
                              child: _toggleCard(
                                Icons.celebration_rounded,
                                'Decoration',
                                _includesDecoration,
                                const Color(0xFF7C3AED),
                                () => setState(
                                  () => _includesDecoration =
                                      !_includesDecoration,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _toggleCard(
                                Icons.restaurant_rounded,
                                'Catering',
                                _includesCatering,
                                const Color(0xFFD97706),
                                () => setState(
                                  () => _includesCatering = !_includesCatering,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_includesDecoration) ...[
                          const SizedBox(height: 16),
                          _section('Decoration Theme'),
                          themesAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, st) => const SizedBox(),
                            data: (themes) => DropdownButtonFormField<String>(
                              value: _decorationThemeId,
                              decoration: _inputDec('Select Theme (optional)'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('No theme selected'),
                                ),
                                ...themes.map(
                                  (t) => DropdownMenuItem(
                                    value: t.id,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.palette_rounded,
                                          size: 14,
                                          color: Color(0xFF7C3AED),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(t.name),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _decorationThemeId = v),
                            ),
                          ),
                        ],
                        if (_includesCatering) ...[
                          const SizedBox(height: 16),
                          _section('Catering Package'),
                          pkgsAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, st) => const SizedBox(),
                            data: (pkgs) => DropdownButtonFormField<String>(
                              value: _cateringPackageId,
                              decoration: _inputDec(
                                'Select Package (optional)',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('No package selected'),
                                ),
                                ...pkgs.map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.restaurant_menu_rounded,
                                          size: 14,
                                          color: Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${p.name} — ₹${p.pricePerPlate.round()}/plate',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _cateringPackageId = v),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Tab 3: Staff Assignment
                    staffAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (staff) => _buildStaffTab(staff),
                    ),
                  ],
                ),
              ),
            ),
            // ── Footer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                color: Color(0xFFFAFAFB),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  if (_selectedStaffIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_rounded,
                            size: 14,
                            color: Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_selectedStaffIds.length} staff assigned',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7C3AED),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isEdit ? Icons.save_rounded : Icons.add_rounded,
                            size: 16,
                          ),
                    label: Text(isEdit ? 'Update Booking' : 'Create Booking'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffTab(List<DcStaff> allStaff) {
    final eventDate = _eventDate;
    if (allStaff.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 10),
            Text(
              'No staff members found',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
            Text(
              'Add staff in the Staff module first',
              style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
            ),
          ],
        ),
      );
    }

    final byRole = <String, List<DcStaff>>{};
    for (final s in allStaff) {
      final role = s.role.name;
      byRole.putIfAbsent(role, () => []).add(s);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _section('Assign Staff'),
              const Spacer(),
              Text(
                'Event: ${DateFormat('d MMM yyyy').format(eventDate)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Staff already assigned to another event on this date are flagged with ⚠️ (conflict).',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5B21B6)),
                  ),
                ),
              ],
            ),
          ),
          ...byRole.entries.map(
            (entry) => _buildRoleSection(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection(String role, List<DcStaff> staff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF7C3AED),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                role[0].toUpperCase() + role.substring(1),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: staff.map((s) {
            final isSelected = _selectedStaffIds.contains(s.id);
            final hasConflict =
                s.assignedEventIds.isNotEmpty &&
                s.assignedEventIds.any(
                  (eid) => eid != (widget.existing?.id ?? ''),
                );
            return InkWell(
              onTap: () => setState(() {
                if (isSelected) {
                  _selectedStaffIds.remove(s.id);
                } else {
                  _selectedStaffIds.add(s.id);
                }
              }),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF7C3AED) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF7C3AED)
                        : (hasConflict
                              ? Colors.orange.shade300
                              : const Color(0xFFE5E7EB)),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF7C3AED,
                            ).withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      child: Text(
                        s.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                            if (hasConflict) ...[
                              const SizedBox(width: 4),
                              const Text('⚠️', style: TextStyle(fontSize: 11)),
                            ],
                          ],
                        ),
                        Text(
                          s.phone,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white70
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: _inputDec(label),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );

  Widget _toggleCard(
    IconData icon,
    String label,
    bool enabled,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.08)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? color : const Color(0xFFE5E7EB),
            width: enabled ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled ? color : const Color(0xFF9CA3AF),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: enabled ? color : const Color(0xFF9CA3AF),
              ),
            ),
            const Spacer(),
            Icon(
              enabled
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: enabled ? color : const Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Validate eventEndDate < eventDate
    if (_eventEndDate != null && _eventEndDate!.isBefore(_eventDate)) {
      setState(
        () => _eventEndDateError = 'End date must be on or after start date',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final booking = EventBooking(
        id:
            widget.existing?.id ??
            'EVT${DateTime.now().millisecondsSinceEpoch}',
        customerId:
            widget.existing?.customerId ??
            'C${DateTime.now().millisecondsSinceEpoch}',
        customerName: _nameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        customerEmail: _emailCtrl.text.trim(),
        eventType: _eventType,
        eventTitle: _titleCtrl.text.trim(),
        eventDate: _eventDate,
        eventEndDate: _eventEndDate,
        venue: _venueCtrl.text.trim(),
        venueAddress: _venueAddrCtrl.text.trim(),
        guestCount: int.tryParse(_guestCtrl.text) ?? 0,
        status: widget.existing?.status ?? EventStatus.inquiry,
        quotedAmount: double.tryParse(_amountCtrl.text) ?? 0,
        advancePaid: double.tryParse(_advanceCtrl.text) ?? 0,
        notes: _notesCtrl.text.trim(),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        includesDecoration: _includesDecoration,
        includesCatering: _includesCatering,
        decorationThemeId: _decorationThemeId,
        cateringPackageId: _cateringPackageId,
        assignedStaffIds: _selectedStaffIds.toList(),
      );
      final repo = ref.read(dcRepositoryProvider);
      if (widget.existing == null) {
        await repo.createBooking(booking);
      } else {
        await repo.updateBooking(booking);
      }
      widget.onSaved(booking);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _eventLabel(EventType t) {
    switch (t) {
      case EventType.wedding:
        return 'Wedding';
      case EventType.birthday:
        return 'Birthday';
      case EventType.corporate:
        return 'Corporate';
      case EventType.engagement:
        return 'Engagement';
      case EventType.babyShower:
        return 'Baby Shower';
      case EventType.anniversary:
        return 'Anniversary';
      case EventType.conference:
        return 'Conference';
      case EventType.other:
        return 'Other';
    }
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _TabPage extends StatelessWidget {
  final List<Widget> children;
  const _TabPage({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
