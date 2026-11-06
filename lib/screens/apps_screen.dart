import 'package:flutter/material.dart';
import '../native_bridge.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  late final Future<List<String>> _apps = Device.appNames();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (String v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search installed apps',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _apps,
              builder: (BuildContext context, AsyncSnapshot<List<String>> snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final List<String> names = snap.data!.where((n) => n.toLowerCase().contains(_query)).toList();
                return ListView.builder(
                  itemCount: names.length,
                  itemBuilder: (BuildContext context, int i) {
                    final String name = names[i];
                    return ListTile(
                      leading: const Icon(Icons.apps),
                      title: Text(name),
                      subtitle: Text('Say: "Open $name"', style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        Device.openApp(name);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
