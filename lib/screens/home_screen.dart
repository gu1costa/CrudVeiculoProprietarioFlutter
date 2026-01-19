import 'package:flutter/material.dart';
import 'proprietarios/proprietarios_list_screen.dart';
import 'veiculos/veiculos_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  final pages = const [
    ProprietariosListScreen(),
    VeiculosListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Proprietários'),
          NavigationDestination(icon: Icon(Icons.directions_car), label: 'Veículos'),
        ],
      ),
    );
  }
}
