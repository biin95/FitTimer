import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'template_screen.dart';
import 'exercise_catalog_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // Cache screen instances so state is preserved across tab switches
  late final List<Widget> _screens;

  /// 当训练数据发生变化时刷新统计页面
  void _onWorkoutDataChanged() {
    statsScreenKey.currentState?.refresh();
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onDataChanged: _onWorkoutDataChanged),
      const TemplateScreen(),
      const ExerciseCatalogScreen(),
      StatsScreen(key: statsScreenKey),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '主页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: '模板',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_gymnastics),
            label: '动作',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
