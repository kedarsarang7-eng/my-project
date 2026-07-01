// ============================================================================
// SCHOOL ERP — TRANSPORT MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcTransportScreen extends StatefulWidget {
  const AcTransportScreen({super.key});

  @override
  State<AcTransportScreen> createState() => _AcTransportScreenState();
}

class _AcTransportScreenState extends State<AcTransportScreen>
    with SingleTickerProviderStateMixin {
  late AcRepository _repository;
  late TabController _tabController;

  List<AcTransportRoute> _routes = [];
  List<AcVehicle> _vehicles = [];
  bool _isLoading = true;

  static const _teal = Color(0xFF0D9488);
  static const _bg = Color(0xFFF0FDFA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository = AcRepository(sl<ApiClient>());
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repository.listTransportRoutes(),
        _repository.listVehicles(),
      ]);
      setState(() {
        _routes = results[0] as List<AcTransportRoute>;
        _vehicles = results[1] as List<AcVehicle>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildSummaryRow(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [_buildRoutesTab(), _buildVehiclesTab()],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tabController.index == 0
            ? _showAddRouteDialog()
            : _showAddVehicleDialog(),
        backgroundColor: _teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Add Route' : 'Add Vehicle',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      color: _bg,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_bus_outlined,
              color: _teal,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transport',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${_routes.length} routes · ${_vehicles.length} vehicles',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: _teal),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final totalStudents = _routes.fold(0, (s, r) => s + r.studentCount);
    final activeVehicles = _vehicles.where((v) => v.isActive).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _statCard('Routes', '${_routes.length}', Icons.route_outlined, _teal),
          const SizedBox(width: 12),
          _statCard(
            'Vehicles',
            '${_vehicles.length}',
            Icons.directions_bus_outlined,
            Colors.blue,
          ),
          const SizedBox(width: 12),
          _statCard(
            'Students',
            '$totalStudents',
            Icons.people_outlined,
            Colors.purple,
          ),
          const SizedBox(width: 12),
          _statCard(
            'Active',
            '$activeVehicles',
            Icons.check_circle_outline,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          color: _teal,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(text: 'Routes'),
          Tab(text: 'Vehicles'),
        ],
      ),
    );
  }

  Widget _buildRoutesTab() {
    if (_routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 64, color: _teal.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text(
              'No transport routes yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddRouteDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Route'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: _routes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildRouteCard(_routes[i]),
    );
  }

  Widget _buildRouteCard(AcTransportRoute route) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.route_outlined,
                    color: _teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (route.vehicleNumber != null)
                        Text(
                          'Vehicle: ${route.vehicleNumber}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => _onRouteAction(v, route),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'add_stop',
                      child: Text('Add Stop'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _chipInfo(
                  Icons.people_outlined,
                  '${route.studentCount} Students',
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _chipInfo(
                  Icons.location_on_outlined,
                  '${route.stops.length} Stops',
                  Colors.green,
                ),
                if (route.driverName != null) ...[
                  const SizedBox(width: 8),
                  _chipInfo(
                    Icons.person_outline,
                    route.driverName!,
                    Colors.purple,
                  ),
                ],
              ],
            ),
            if (route.stops.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Stops',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: route.stops.length,
                  separatorBuilder: (_, _) => const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  itemBuilder: (_, si) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      route.stops[si].name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chipInfo(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesTab() {
    if (_vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 64,
              color: Colors.blue.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No vehicles registered',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddVehicleDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: _vehicles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildVehicleCard(_vehicles[i]),
    );
  }

  Widget _buildVehicleCard(AcVehicle vehicle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: vehicle.isActive
                ? Colors.blue.shade50
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.directions_bus_outlined,
            color: vehicle.isActive ? Colors.blue : Colors.grey,
            size: 26,
          ),
        ),
        title: Text(
          vehicle.number,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vehicle.driverName != null)
              Text(
                'Driver: ${vehicle.driverName}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            if (vehicle.driverPhone != null)
              Text(
                '📞 ${vehicle.driverPhone}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: vehicle.isActive
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                vehicle.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: vehicle.isActive ? Colors.green.shade700 : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${vehicle.capacity} seats',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _onRouteAction(String action, AcTransportRoute route) {
    switch (action) {
      case 'add_stop':
        _showAddStopDialog(route);
        break;
      case 'edit':
        _showEditRouteDialog(route);
        break;
      case 'delete':
        _confirmDeleteRoute(route);
        break;
    }
  }

  void _showAddRouteDialog() {
    final nameCtrl = TextEditingController();
    final driverCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Transport Route',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(nameCtrl, 'Route Name *', Icons.route_outlined),
            const SizedBox(height: 12),
            _field(driverCtrl, 'Driver Name', Icons.person_outline),
            const SizedBox(height: 12),
            _field(
              vehicleCtrl,
              'Vehicle Number',
              Icons.directions_bus_outlined,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _repository.createTransportRoute(
                  name: nameCtrl.text.trim(),
                  driverName: driverCtrl.text.trim().isEmpty
                      ? null
                      : driverCtrl.text.trim(),
                  vehicleNumber: vehicleCtrl.text.trim().isEmpty
                      ? null
                      : vehicleCtrl.text.trim(),
                );
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddStopDialog(AcTransportRoute route) {
    final stopCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Stop to ${route.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(stopCtrl, 'Stop Name *', Icons.location_on_outlined),
            const SizedBox(height: 12),
            _field(
              timeCtrl,
              'Pickup Time (e.g. 7:30 AM)',
              Icons.access_time_outlined,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (stopCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _repository.addTransportStop(
                  routeId: route.id,
                  stopName: stopCtrl.text.trim(),
                  pickupTime: timeCtrl.text.trim().isEmpty
                      ? null
                      : timeCtrl.text.trim(),
                );
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Add Stop'),
          ),
        ],
      ),
    );
  }

  void _showEditRouteDialog(AcTransportRoute route) {
    final nameCtrl = TextEditingController(text: route.name);
    final driverCtrl = TextEditingController(text: route.driverName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(nameCtrl, 'Route Name', Icons.route_outlined),
            const SizedBox(height: 12),
            _field(driverCtrl, 'Driver Name', Icons.person_outline),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.updateTransportRoute(
                  routeId: route.id,
                  name: nameCtrl.text.trim(),
                  driverName: driverCtrl.text.trim().isEmpty
                      ? null
                      : driverCtrl.text.trim(),
                );
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRoute(AcTransportRoute route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Route?', style: TextStyle(color: Colors.red)),
        content: Text('Delete route "${route.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.deleteTransportRoute(routeId: route.id);
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddVehicleDialog() {
    final numberCtrl = TextEditingController();
    final driverCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '40');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Vehicle',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(
              numberCtrl,
              'Vehicle Number *',
              Icons.directions_bus_outlined,
            ),
            const SizedBox(height: 12),
            _field(driverCtrl, 'Driver Name', Icons.person_outline),
            const SizedBox(height: 12),
            _field(
              phoneCtrl,
              'Driver Phone',
              Icons.phone_outlined,
              inputType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _field(
              capacityCtrl,
              'Seating Capacity',
              Icons.event_seat_outlined,
              inputType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (numberCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _repository.createVehicle(
                  number: numberCtrl.text.trim(),
                  driverName: driverCtrl.text.trim().isEmpty
                      ? null
                      : driverCtrl.text.trim(),
                  driverPhone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  capacity: int.tryParse(capacityCtrl.text) ?? 40,
                );
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? inputType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon),
      ),
    );
  }
}
