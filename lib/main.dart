import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'assistant_brain.dart';
import 'env.dart';
import 'firebase_auth_service.dart';
import 'local_store.dart';
import 'permission_helper.dart';
import 'screens/apps_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/images_screen.dart';
import 'screens/login_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();
  String? problem;
  if (AppEnv.fbApiKey.isEmpty || AppEnv.fbAppId.isEmpty || AppEnv.fbProjectId.isEmpty) {
    problem = 'Firebase keys are missing. Build with the FIREBASE_* secrets (see README).';
  } else {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: AppEnv.fbApiKey,
          appId: AppEnv.fbAppId,
          messagingSenderId: AppEnv.fbSenderId,
          projectId: AppEnv.fbProjectId,
        ),
      );
    } catch (e) {
      problem = 'Firebase start-up failed: $e';
    }
  }
  runApp(PentaApp(problem: problem));
}

class PentaApp extends StatelessWidget {
  const PentaApp({super.key, this.problem});
  final String? problem;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Penta',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNav,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05060F),
        colorScheme: const ColorScheme.dark(primary: neonCyan, onPrimary: Colors.black, secondary: neonViolet),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF0B0E1F),
          indicatorColor: Color(0x3322D3EE),
        ),
      ),
      home: problem != null
          ? Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(problem!))))
          : const Gate(),
    );
  }
}

/// Login -> permission disclosure (once) -> main app.
class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: PentaAuth.changes,
      builder: (BuildContext context, AsyncSnapshot<User?> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) return const LoginScreen();
        if (!LocalStore.flag('disclosed')) {
          return DisclosureScreen(onDone: () => setState(() {}));
        }
        return const Shell();
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final AssistantBrain _brain = AssistantBrain();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _brain.start();
  }

  @override
  void dispose() {
    _brain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
         HomeScreen(
  brain: _brain,
  onOpenTab: (int index) => setState(() => _tab = index),
), 
          const AppsScreen(),
          ChatScreen(brain: _brain),
          ImagesScreen(brain: _brain),
          SettingsScreen(brain: _brain),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Apps'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.image_outlined), selectedIcon: Icon(Icons.image), label: 'Images'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
