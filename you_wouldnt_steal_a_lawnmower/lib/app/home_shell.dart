import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/add_appliance_page.dart';
import '../pages/browse_page.dart';
import '../pages/my_reservations_page.dart';
import '../pages/owner_dashboard_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    BrowsePage(),
    AddAppliancePage(),
    MyReservationsPage(),
    OwnerDashboardPage(),
  ];

  final List<String> _titles = const [
    'Zoeken',
    'Toestel aanbieden',
    'Mijn reserveringen',
    'Dashboard verhuurder',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Uitloggen',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Zoeken'),
          NavigationDestination(icon: Icon(Icons.add_box), label: 'Aanbieden'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Reservaties'),
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        ],
      ),
    );
  }
}
