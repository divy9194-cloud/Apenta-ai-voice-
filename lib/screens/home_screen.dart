import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../assistant_brain.dart';
import '../local_store.dart';
import '../widgets/boy_avatar.dart';
import '../widgets/character_view.dart';
import '../widgets/common.dart';
import 'camera_assist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.brain, required this.onOpenTab});
  final AssistantBrain brain;
  final void Function(int index) onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _streak = 1;
  String _weatherValue = '–°';
  String _weatherNote = 'Tap to load';
  bool _loadingWeather = false;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _updateStreak();
  }

  void _updateStreak() {
    final DateTime now = DateTime.now();
    final String today = '${now.year}-${now.month}-${now.day}';
    final String? last = LocalStore.prefs.getString('streakDay');
    int streak = LocalStore.prefs.getInt('streak') ?? 0;
    if (last != today) {
      final DateTime y = now.subtract(const Duration(days: 1));
      final String yesterday = '${y.year}-${y.month}-${y.day}';
      streak = (last == yesterday) ? streak + 1 : 1;
      LocalStore.prefs.setString('streakDay', today);
      LocalStore.prefs.setInt('streak', streak);
    }
    _streak = streak == 0 ? 1 : streak;
  }

  String _greeting() {
    final int h = DateTime.now().hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  String _weatherText(int code) {
    if (code == 0) return 'Clear sky';
    if (code <= 3) return 'Cloudy';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Weather';
  }

  Future<void> _loadWeather() async {
    if (_loadingWeather) return;
    setState(() {
      _loadingWeather = true;
      _weatherNote = 'Loading…';
    });
    try {
      final http.Response loc = await http.get(Uri.parse('https://ipwho.is/')).timeout(const Duration(seconds: 10));
      final Map<String, dynamic> l = jsonDecode(loc.body) as Map<String, dynamic>;
      final double lat = (l['latitude'] as num).toDouble();
      final double lon = (l['longitude'] as num).toDouble();
      final http.Response w = await http
          .get(Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code'))
          .timeout(const Duration(seconds: 10));
      final Map<String, dynamic> data = jsonDecode(w.body) as Map<String, dynamic>;
      final Map<String, dynamic> cur = data['current'] as Map<String, dynamic>;
      final int temp = (cur['temperature_2m'] as num).round();
      final int code = (cur['weather_code'] as num).toInt();
      if (!mounted) return;
      setState(() {
        _weatherValue = '$temp°';
        _weatherNote = _weatherText(code);
        _loadingWeather = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherValue = '–°';
        _weatherNote = 'Could not load';
        _loadingWeather = false;
      });
    }
  }

  String _moodLabel(BoyMood m) {
    switch (m) {
      case BoyMood.listening:
        return 'Listening';
      case BoyMood.thinking:
        return 'Thinking';
      case BoyMood.speaking:
        return 'Chatty';
      case BoyMood.waving:
        return 'Excited';
      case BoyMood.sleeping:
        return 'Sleepy';
      case BoyMood.idle:
        return 'Happy';
    }
  }

  String _statusLine(AssistantBrain b) {
    if (b.sleeping) return 'Zzz… tap me to wake me up';
    if (b.thinking) return 'Thinking…';
    if (b.speaking) return 'Talking…';
    if (b.active) return 'Listening…';
    if (b.background) return 'Ready, say "Hey Penta"';
    return 'Ready when you are';
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF11162A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: neonCyan),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String title, Widget value, String note, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 84,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF11162A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.white54)),
              value,
              Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AssistantBrain brain = widget.brain;
    return ListenableBuilder(
      listenable: brain,
      builder: (BuildContext context, Widget? child) {
        final BoyMood mood = brain.mood;
        final DateTime now = DateTime.now();
        String lastReply = '';
        if (brain.entries.isNotEmpty && !brain.entries.last.fromUser) {
          lastReply = brain.entries.last.text;
        }
        final String caption = brain.liveText.isNotEmpty ? brain.liveText : lastReply;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A1030), Color(0xFF05060F)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greeting()}, ${brain.callName} 😎',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: brain.active ? const Color(0xFF22C55E) : neonCyan,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _statusLine(brain),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Apps',
                        onPressed: () => widget.onOpenTab(1),
                        icon: const Icon(Icons.apps, color: Colors.white70),
                      ),
                      IconButton(
                        tooltip: 'Camera assistant',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(builder: (BuildContext c) => CameraAssistScreen(brain: brain)),
                          );
                        },
                        icon: const Icon(Icons.center_focus_strong, color: neonCyan),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1B1B),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department, size: 16, color: Color(0xFFFF8A3D)),
                            const SizedBox(width: 3),
                            Text('$_streak', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // The character with his board
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints cs) {
                        final double w = cs.maxWidth;
                        final double h = math.min(cs.maxHeight, w * 0.95);
                        return Center(
                          child: SizedBox(
                            width: w,
                            height: h,
                            child: Stack(
                              children: [
                                Positioned.fill(child: CharacterView(brain: brain)),
                                Positioned(
                                  left: 10,
                                  bottom: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xDD2A1B4D),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: neonViolet.withAlpha(120)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.auto_awesome, size: 13, color: Color(0xFFF472B6)),
                                        const SizedBox(width: 5),
                                        Text(_moodLabel(mood), style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Full text of what Penta heard or said
                Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 4),
                  alignment: Alignment.center,
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: brain.liveText.isNotEmpty ? Colors.white : Colors.white60),
                  ),
                ),
                if (brain.lastEvent.contains('error'))
                  Text(brain.lastEvent, style: const TextStyle(fontSize: 10, color: Colors.white38)),

                // Quick buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                  child: Row(
                    children: [
                      _chip(Icons.music_note, 'Music', () => brain.runCommand('play relaxing music', spoken: true)),
                      _chip(
                        Icons.menu_book,
                        'Study',
                        () => brain.runCommand(
                          'Help me study. Ask me which subject I want to study today and then quiz me like a friendly tutor.',
                          spoken: true,
                        ),
                      ),
                      _chip(
                        Icons.favorite_border,
                        'Vent',
                        () => brain.runCommand(
                          'I want to talk about my day and how I feel. Please listen like a caring friend and ask me what happened.',
                          spoken: true,
                        ),
                      ),
                      _chip(Icons.photo_camera, 'Photo', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (BuildContext c) => CameraAssistScreen(brain: brain)),
                        );
                      }),
                    ],
                  ),
                ),

                // Info cards
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Row(
                    children: [
                      _card(
                        'WEATHER',
                        Text(_weatherValue, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        _weatherNote,
                        onTap: _loadWeather,
                      ),
                      _card(
                        'TODAY',
                        Text('${now.day}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        '${_months[now.month - 1]} ${_days[now.weekday - 1]}',
                      ),
                      _card(
                        'MOOD',
                        const Icon(Icons.favorite, color: Color(0xFFF472B6), size: 24),
                        _moodLabel(mood),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
