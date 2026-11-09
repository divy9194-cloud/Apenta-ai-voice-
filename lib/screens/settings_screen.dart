import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../assistant_brain.dart';
import '../firebase_auth_service.dart';
import '../floating.dart';
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

  Future<void> _pickVoice() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setInner) {
            return AlertDialog(
              title: const Text('Choose a voice'),
              content: SizedBox(
                width: double.maxFinite,
                height: 380,
                child: FutureBuilder<List<Map<String, String>>>(
                  future: VoiceHub.voices(),
                  builder: (BuildContext context, AsyncSnapshot<List<Map<String, String>>> snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final List<Map<String, String>> list = snap.data!;
                    if (list.isEmpty) {
                      return const Center(child: Text('No voices found. Install more voices in your phone\'s Text-to-speech settings.'));
                    }
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Map<String, String> v = list[i];
                        final bool chosen = VoiceHub.chosenFor(v) == v['name'];
                        return ListTile(
                          dense: true,
                          title: Text(v['name']!, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(v['locale']!),
                          trailing: chosen ? const Icon(Icons.check_circle, color: neonCyan) : const Icon(Icons.play_arrow),
                          onTap: () async {
                            await VoiceHub.choose(v);
                            setInner(() {});
                            await VoiceHub.preview(v);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await VoiceHub.reset();
                    setInner(() {});
                  },
                  child: const Text('Reset'),
                ),
                FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
              ],
            );
          },
        );
      },
    );
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
          ListTile(
            leading: const Icon(Icons.face_retouching_natural),
            title: const Text('Reset Penta\'s picture'),
            subtitle: const Text('Go back to the original boy picture. Change it any time in the Photo editor.'),
            onTap: () async {
              await LocalStore.prefs.remove('avatarPath');
              brain.refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Penta is back to the original picture.')));
              }
            },
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Voice', style: TextStyle(color: neonCyan, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: true, label: Text('Boy voice'), icon: Icon(Icons.face)),
                ButtonSegment<bool>(value: false, label: Text('Girl voice'), icon: Icon(Icons.face_3)),
              ],
              selected: <bool>{VoiceHub.boy},
              onSelectionChanged: (Set<bool> s) async {
                await VoiceHub.setBoy(s.first);
                setState(() {});
                await brain.speak(s.first ? 'Namaste, ab main aise bolunga.' : 'Namaste, ab main aise bolungi.');
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text('Choose a specific voice'),
            subtitle: const Text('Tap voices to hear them and keep the one that sounds male. Android does not tell which are male.'),
            onTap: _pickVoice,
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Floating Penta and screen share', style: TextStyle(color: neonCyan, fontWeight: FontWeight.w600)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.picture_in_picture_alt),
            title: const Text('Floating Penta box'),
            subtitle: const Text(
                'When you press Back or Home, a small Penta box stays over other apps and talks with you. Needs "Display over other apps".'),
            value: FloatingHub.enabled,
            onChanged: (bool on) async {
              final String? error = await FloatingHub.setFloating(on);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              }
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.layers),
            title: const Text('Allow display over other apps'),
            onTap: () {
              Floating.askOverlayPermission();
            },
          ),
          ListTile(
            leading: Icon(FloatingHub.sharing ? Icons.stop_screen_share : Icons.screen_share, color: neonCyan),
            title: Text(FloatingHub.sharing ? 'Stop sharing my screen' : 'Share my screen with Penta'),
            subtitle: const Text('Penta looks at a picture of your screen only when you ask a question while sharing.'),
            onTap: () async {
              if (FloatingHub.sharing) {
                await FloatingHub.stopShare();
              } else {
                await FloatingHub.startShare();
              }
              await Future<void>.delayed(const Duration(milliseconds: 600));
              if (mounted) setState(() {});
            },
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
