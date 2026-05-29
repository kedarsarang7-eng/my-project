import 'package:flutter/material.dart';
import 'screens/chef_dashboard_screen.dart';
import 'screens/completed_orders_screen.dart';
import 'screens/main_kds_screen.dart';
import 'screens/station_view_screen.dart';
import 'state/chef_state.dart';

void main() {
  runApp(const ChefApp());
}

class ChefApp extends StatelessWidget {
  const ChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restro Chef KDS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEA580C),
          secondary: Color(0xFFEA580C),
          surface: Color(0xFF1A1A1A),
        ),
      ),
      home: const ChefHome(),
    );
  }
}

class ChefHome extends StatefulWidget {
  const ChefHome({super.key});

  @override
  State<ChefHome> createState() => _ChefHomeState();
}

class _ChefHomeState extends State<ChefHome> {
  final ChefState _state = ChefState();
  int _tab = 0;

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MainKdsScreen(state: _state),
      StationViewScreen(state: _state),
      CompletedOrdersScreen(state: _state),
      ChefDashboardScreen(state: _state),
    ];
    return AnimatedBuilder(
      animation: _state,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: const Text('Chef KDS'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _state.refresh,
            ),
          ],
        ),
        body: pages[_tab],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.kitchen),
              label: 'KDS',
            ),
            NavigationDestination(
              icon: Icon(Icons.filter_alt_outlined),
              label: 'Stations',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              label: 'Completed',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: 'Dashboard',
            ),
          ],
          onDestinationSelected: (v) => setState(() => _tab = v),
        ),
      ),
    );
  }
}
