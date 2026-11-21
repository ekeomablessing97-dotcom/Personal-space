import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'screens/ideas/ideas_screen.dart';
import 'screens/journal/journal_screen.dart';
import 'screens/memory_lane/memory_lane_screen.dart';
import 'screens/notes/notes_screen.dart';
import 'screens/private_space/private_space_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/tasks/tasks_screen.dart';
import 'screens/voice_notes/voice_notes_screen.dart';
import 'services/app_state_controller.dart';
import 'utils/formatters.dart';

class PersonalSpaceApp extends StatefulWidget {
  final AppStateController controller;

  const PersonalSpaceApp({super.key, required this.controller});

  @override
  State<PersonalSpaceApp> createState() => _PersonalSpaceAppState();
}

class _PersonalSpaceAppState extends State<PersonalSpaceApp>
    with WidgetsBindingObserver {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = widget.controller.authService;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      auth.recordBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      auth.checkAutoLock(widget.controller.settings.autoLockSeconds);
    }
  }

  ThemeMode _resolveThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final seed = AppFormatters.hexToColor(ctrl.settings.accentHex);

        final lightTheme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.light,
            surface: const Color(0xFFFFFFFF),
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F5F0),
          cardTheme: CardThemeData(
            color: const Color(0xFFFFFFFF),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
        );

        final darkTheme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
            surface: const Color(0xFF1A1D21),
          ),
          scaffoldBackgroundColor: const Color(0xFF111315),
          cardTheme: CardThemeData(
            color: const Color(0xFF1A1D21),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
        );

        final pages = <Widget>[
          HomeScreen(
            controller: ctrl,
            onNavigateTab: (idx) => setState(() => _navIndex = idx),
          ),
          NotesScreen(controller: ctrl),
          JournalScreen(controller: ctrl),
          IdeasScreen(controller: ctrl),
          TasksScreen(controller: ctrl),
          VoiceNotesScreen(controller: ctrl),
          MemoryLaneScreen(controller: ctrl),
          PrivateSpaceScreen(controller: ctrl),
          SettingsScreen(controller: ctrl),
        ];

        const destinations = [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Notes'),
          NavigationDestination(
              icon: Icon(Icons.book_outlined),
              selectedIcon: Icon(Icons.book),
              label: 'Journal'),
          NavigationDestination(
              icon: Icon(Icons.lightbulb_outline),
              selectedIcon: Icon(Icons.lightbulb),
              label: 'Ideas'),
          NavigationDestination(
              icon: Icon(Icons.check_circle_outline),
              selectedIcon: Icon(Icons.check_circle),
              label: 'Tasks'),
          NavigationDestination(
              icon: Icon(Icons.mic_none),
              selectedIcon: Icon(Icons.mic),
              label: 'Voice'),
          NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history),
              label: 'Memory'),
          NavigationDestination(
              icon: Icon(Icons.lock_outline),
              selectedIcon: Icon(Icons.lock),
              label: 'Private'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ];

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(ctrl.settings.textScale),
          ),
          child: MaterialApp(
            title: 'PERSONAL SPACE',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: _resolveThemeMode(ctrl.settings.themeMode),
            home: Scaffold(
              body: IndexedStack(
                index: _navIndex,
                children: pages,
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _navIndex,
                onDestinationSelected: (idx) => setState(() => _navIndex = idx),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: destinations,
              ),
            ),
          ),
        );
      },
    );
  }
}
