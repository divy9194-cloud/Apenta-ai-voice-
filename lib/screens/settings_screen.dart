import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../assistant_brain.dart';
import '../firebase_auth_service.dart';
import '../local_store.dart';
import '../native_bridge.dart';
import '../widgets/common.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.brain});
  final AssistantBrain brain;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return SafeArea(
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(user?.displayName ?? 'Penta user'),
            subtitle: Text(user?.email ?? ''),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.repeat),
            title: const Text('Continuous listening'),
            subtitle: const Text(
                'Keeps the mic open for many commands in a row. Android plays a "ding" each time the mic restarts, so this is off by default.'),
            value: widget.brain.continuous,
            onChanged: (bool on) async {
              await widget.brain.setContinuous(on);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mic),
            title: const Text('"Hey Penta" background mode'),
            subtitle: const Text(
                'Keeps listening for the wake phrase, also after screen lock, with a visible notification. Off by default. This will ding often.'),
            value: widget.brain.background,
            onChanged: (bool on) async {
              final String? error = await widget.brain.setBackground(on);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              }
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_sync),
            title: const Text('Sync chat history to cloud'),
            value: LocalStore.flag('sync'),
            onChanged: (bool on) async {
              await LocalStore.setFlag('sync', on);
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Allow brightness control'),
            onTap: () {
              Device.askWriteSettings();
            },
          ),
          ListTile(
            leading: const Icon(Icons.screenshot),
            title: const Text('Allow screenshots (Accessibility)'),
            onTap: () {
              Device.askScreenshotAccess();
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Permission disclosure'),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DisclosureScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy policy'),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PrivacyScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () {
              PentaAuth.logout();
            },
          ),
          const Center(child: CreditLine()),
        ],
      ),
    );
  }
}
