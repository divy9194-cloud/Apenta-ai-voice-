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
  Future<void> _editName() async {
    final TextEditingController c = TextEditingController(text: widget.brain.callName);
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('What should Penta call you?'),
          content: TextField(controller: c, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, c.text), child: const Text('Save')),
          ],
        );
      },
    );
    if (name != null) {
      await widget.brain.setSetting('callName', name);
      if (mounted) setState(() {});
    }
  }

  Future<void> _editIdle() async {
    final int? secs = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          title: const Text('Wait for how long?'),
          children: [
            for (final int s in <int>[10, 20, 30, 60])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, s),
                child: Text('$s seconds'),
              ),
          ],
        );
      },
    );
    if (secs != null) {
      await widget.brain.setSetting('idleSeconds', secs);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final AssistantBrain brain = widget.brain;
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
          ListTile(
            leading: const Icon(Icons.badge),
            title: const Text('What Penta calls you'),
            subtitle: Text(brain.callName),
            onTap: _editName,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Conversation', style: TextStyle(color: neonCyan, fontWeight: FontWeight.w600)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.forum),
            title: const Text('Stay in conversation'),
            subtitle: const Text('Keeps listening after each answer, so you can talk without tapping again.'),
            value: brain.conversation,
            onChanged: (bool on) async {
              await brain.setSetting('conversation', on);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bedtime),
            title: const Text('Sleep if I ignore Penta'),
            subtitle: const Text(
                'If you go quiet, Penta says "baat to kar na", and after a little more silence says goodbye, sleeps and closes its screen.'),
            value: brain.autoSleep,
            onChanged: (bool on) async {
              await brain.setSetting('autoSleep', on);
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('How long before the first nudge'),
            subtitle: Text('${brain.idleSeconds} seconds'),
            onTap: _editIdle,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Sounds', style: TextStyle(color: neonCyan, fontWeight: FontWeight.w600)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_off),
            title: const Text('Silence the mic sound'),
            subtitle: const Text(
                'Mutes notification and system sounds while the mic is open, and restores them after. Notification sounds are silent while Penta listens.'),
            value: brain.silenceBeeps,
            onChanged: (bool on) async {
              await brain.setSetting('silenceBeeps', on);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.music_off),
            title: const Text('Also mute media while listening'),
            subtitle: const Text('Turn this on only if your phone still dings. Music and videos go silent while the mic is open.'),
            value: brain.muteMedia,
            onChanged: (bool on) async {
              await brain.setSetting('muteMedia', on);
              setState(() {});
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Always on', style: TextStyle(color: neonCyan, fontWeight: FontWeight.w600)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mic),
            title: const Text('"Hey Penta" background mode'),
            subtitle: const Text(
                'Keeps listening for the wake phrase, also after screen lock, with a visible notification. Needed for hands-free control of other apps.'),
            value: brain.background,
            onChanged: (bool on) async {
              final String? error = await brain.setBackground(on);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              }
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver),
            title: const Text('Keep Penta alive (battery)'),
            subtitle: const Text('Set Penta to "Not optimised" or "Unrestricted" so Android does not stop it.'),
            onTap: () {
              Device.openBatterySettings();
            },
          ),
          ListTile(
            leading: const Icon(Icons.home_filled),
            title: const Text('Set Penta as default assistant'),
            subtitle: const Text(
                'Then a long press on Home opens Penta, like Gemini. Choose "Digital assistant app" and pick Penta.'),
            onTap: () {
              Device.openAssistantSettings();
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Phone control and privacy', style: TextStyle(color: neonCyan, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.accessibility_new),
            title: const Text('Allow Accessibility (full phone control)'),
            subtitle: const Text('Needed for lock, scroll, tap, type, read screen, home, back and screenshots.'),
            onTap: () {
              Device.askScreenshotAccess();
            },
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Allow brightness control'),
            onTap: () {
              Device.askWriteSettings();
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
