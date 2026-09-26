import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'lokasi_list_screen.dart';
import 'pegawai_list_screen.dart';
import 'spt_list_screen.dart';

/// Beranda Admin Kepegawaian: CRUD Pegawai, Lokasi, dan SPT dalam satu shell tab.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tabIndex = 0;

  static const _titles = ['Data Pegawai', 'Data Lokasi', 'Data SPT'];
  static const _tabs = [
    PegawaiListScreen(),
    LokasiListScreen(),
    SptListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tabIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Pegawai'),
          NavigationDestination(icon: Icon(Icons.place_outlined), label: 'Lokasi'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'SPT'),
        ],
      ),
    );
  }
}
