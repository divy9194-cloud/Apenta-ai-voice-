import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'assistant_brain.dart';
import 'env.dart';
import 'firebase_auth_service.dart';
import 'floating.dart';
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

  // Pages: 0 Home, 1 Apps, 2 Chat, 3 Images, 4 Settings
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

  /// Back on the main screen: show the floating Penta box (if switched on), otherwise leave the app.
  Future<void> _onBack() async {
    if (_tab != 0) {
      setState(() => _tab = 0);
      return;
    }
    if (FloatingHub.enabled && await Floating.canOverlay()) {
      final bool shown = await Floating.showOverlay();
      await Floating.minimizeApp();
      if (shown) await FloatingHub.greet();
    } else {
      await SystemNavigator.pop();
    }
  }

  Widget _navItem(IconData icon, String label, int index) {
    final bool selected = _tab == index;
    final Color color = selected ? neonCyan : Colors.white54;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _micButton() {
    return ListenableBuilder(
      listenable: _brain,
      builder: (BuildContext context, Widget? child) {
        final bool on = _brain.active && !_brain.sleeping;
        return GestureDetector(
          onTap: _brain.toggle,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFFFFB347), Color(0xFFFF7A18)]),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7A18).withAlpha(on ? 190 : 110),
                  blurRadius: on ? 26 : 16,
                  spreadRadius: on ? 4 : 1,
                ),
              ],
            ),
            child: Icon(on ? Icons.graphic_eq : Icons.mic, color: Colors.white, size: 30),
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    return Container(
      color: const Color(0xFF0B0E1F),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _navItem(Icons.home_rounded, 'Home', 0),
              _navItem(Icons.chat_bubble_rounded, 'Chat', 2),
              SizedBox(
                width: 84,
                child: Transform.translate(offset: const Offset(0, -14), child: Center(child: _micButton())),
              ),
              _navItem(Icons.image_rounded, 'Images', 3),
              _navItem(Icons.settings_rounded, 'Settings', 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            HomeScreen(brain: _brain, onOpenTab: (int i) => setState(() => _tab = i)),
            const AppsScreen(),
            ChatScreen(brain: _brain),
            ImagesScreen(brain: _brain),
            SettingsScreen(brain: _brain),
          ],
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }
}
