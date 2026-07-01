import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/session/session_manager.dart';
import '../../../services/tank_service.dart';
import '../../../models/tank.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Density Report Screen for Petrol Pump
/// Tracks fuel density readings for dip calculation and compliance
class DensityReportScreen extends StatefulWidget {
  const DensityReportScreen({super.key});

  @override
  State<DensityReportScreen> createState() => _DensityReportScreenState();
}

class _DensityReportScreenState extends State<DensityReportScreen> {
  bool _isLoading = true;
  List<DensityRecordEntity> _records = [];
  String? _selectedTankId;
  List<Tank> _tanks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = sl<AppDatabase>();
      final tankService = sl<TankService>();

      // Load tanks (use Stream.first to get initial list)
      final tanks = await tankService.getTanks().first;

      // Load density records
      final records = await (db.select(
        db.densityRecords,
      )..orderBy([(d) => OrderingTerm.desc(d.recordDate)])).get();

      setState(() {
        _tanks = tanks;
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  List<DensityRecordEntity> get _filteredRecords {
    if (_selectedTankId == null) return _records;
    return _records.where((r) => r.tankId == _selectedTankId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Density Report'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDensityDialog,
        icon: const Icon(Icons.add),
        label: const Text('Record Density'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tank Filter
                if (_tanks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String?>(
                      value: _selectedTankId,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Tank',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Tanks'),
                        ),
                        ..._tanks.map(
                          (tank) => DropdownMenuItem(
                            value: tank.tankId,
                            child: Text(tank.tankName),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedTankId = value);
                      },
                    ),
                  ),

                // Records List
                Expanded(
                  child: _filteredRecords.isEmpty
                      ? const Center(child: Text('No density records found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredRecords.length,
                          itemBuilder: (context, index) {
                            return _buildDensityCard(_filteredRecords[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDensityCard(DensityRecordEntity record) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final tank = _tanks.firstWhere(
      (t) => t.tankId == record.tankId,
      orElse: () => throw StateError('Tank not found'),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tank.tankName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  dateFormat.format(record.recordDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMeasurement(
                    'Density',
                    '${record.density.toStringAsFixed(3)} kg/L',
                    Colors.blue,
                  ),
                  if (record.temperature != null)
                    _buildMeasurement(
                      'Temp',
                      '${record.temperature!.toStringAsFixed(1)}°C',
                      Colors.orange,
                    ),
                  if (record.dipReading != null)
                    _buildMeasurement(
                      'Dip',
                      '${record.dipReading!.toStringAsFixed(0)} mm',
                      Colors.green,
                    ),
                  if (record.calculatedVolume != null)
                    _buildMeasurement(
                      'Volume',
                      '${record.calculatedVolume!.toStringAsFixed(0)} L',
                      Colors.purple,
                    ),
                ],
              ),
            ),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record.notes!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurement(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  void _showAddDensityDialog() {
    final densityController = TextEditingController();
    final tempController = TextEditingController();
    final dipController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedTankId = _tanks.isNotEmpty ? _tanks.first.tankId : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Density Reading'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedTankId,
                decoration: const InputDecoration(labelText: 'Tank'),
                items: _tanks
                    .map(
                      (tank) => DropdownMenuItem(
                        value: tank.tankId,
                        child: Text(tank.tankName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => selectedTankId = value,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: densityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Density (kg/L)',
                  hintText: '0.755',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tempController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Temperature (°C)',
                  hintText: '30.0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dipController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dip Reading (mm)',
                  hintText: '1500',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final density = double.tryParse(densityController.text);
              if (density != null && selectedTankId != null) {
                await _addDensityRecord(
                  tankId: selectedTankId!,
                  density: density,
                  temperature: double.tryParse(tempController.text),
                  dipReading: double.tryParse(dipController.text),
                  notes: notesController.text,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDensityRecord({
    required String tankId,
    required double density,
    double? temperature,
    double? dipReading,
    String? notes,
  }) async {
    try {
      final db = sl<AppDatabase>();
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      await db
          .into(db.densityRecords)
          .insert(
            DensityRecordsCompanion.insert(
              id: id,
              ownerId: sl<SessionManager>().ownerId ?? 'unknown',
              tankId: tankId,
              recordDate: DateTime.now(),
              density: density,
              createdAt: DateTime.now(),
            ),
          );

      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Density recorded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error recording density: $e')));
      }
    }
  }
}
