import 'package:flutter/material.dart';

import 'product_page.dart';
import 'profile_screen.dart';

/// Provides navigation between Part 1's product catalogue and Part 2's profile.
/// AuthGate owns access to this entire widget.
class SignedInHome extends StatefulWidget {
  const SignedInHome({super.key});

  @override
  State<SignedInHome> createState() => _SignedInHomeState();
}

class _SignedInHomeState extends State<SignedInHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          ProductPage(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
