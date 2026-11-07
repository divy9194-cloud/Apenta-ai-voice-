import 'package:flutter/material.dart';
import '../local_store.dart';
import '../widgets/common.dart';

/// Permission disclosure. Shown once after login (with onDone) and from Settings.
class DisclosureScreen extends StatelessWidget {
  const DisclosureScreen({super.key, this.onDone});
  final VoidCallback? onDone;

  static const List<List<String>> _rows = <List<String>>[
    ['Microphone', 'To hear your voice commands and the wake phrase. Audio is used only while Penta is listening. Recognised text may be sent to Google speech services and your AI provider to answer you.'],
    ['Camera', 'Only inside the Camera assistant. A picture is sent to the AI when you ask a question about what the camera sees. Photos you take are saved on your device.'],
    ['Contacts', 'Only when you ask Penta to call or message someone, to find that person\'s number. Contacts are never uploaded or stored.'],
    ['Phone', 'Only to place a call after you confirm it.'],
    ['Notifications', 'Required by Android to show a visible notice while optional background listening is on.'],
    ['Modify system settings', 'Only to change screen brightness when you ask.'],
        ['Accessibility (optional)', 'Only when you ask: take a screenshot, lock the screen, or type or search in another app. Penta reads the open screen only to find the text box or button you asked for.'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions & privacy')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Penta asks for each permission only when a feature needs it. It does not read your messages, contacts or microphone unless you use a feature that requires it.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                for (final List<String> row in _rows)
                  Card(child: ListTile(title: Text(row[0]), subtitle: Text(row[1]))),
                const Center(child: CreditLine()),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    if (onDone != null) {
                      await LocalStore.setFlag('disclosed', true);
                      onDone!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(onDone != null ? 'I understand, continue' : 'Close'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Penta by Divyanshu Kumar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          Text(
            'Account: your name, email and a user ID are stored with Firebase Authentication and Cloud Firestore.\n\n'
            'Voice: speech is recognised by Android\'s speech service. The text of your questions is sent to the AI provider (Google Gemini) to create answers and images. Penta does not record or keep audio.\n\n'
            'Contacts and calls: contacts are read only on your request, to find a number. They are not uploaded.\n\n'
            'Chat history and generated images are stored on your device. Syncing chat to Firestore is off unless you turn it on in Settings.\n\n'
            'Background listening is off by default. When enabled, a persistent notification is shown.\n\n'
            'You can delete chat history in the Chat tab and request account deletion by contacting the developer.\n\n'
            'Replace this text with your final policy and host it at a public URL before publishing on Google Play.',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}
