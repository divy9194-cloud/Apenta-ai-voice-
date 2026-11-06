import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

final GlobalKey<NavigatorState> rootNav = GlobalKey<NavigatorState>();

/// Explains why, then asks for the permission. Called only when a feature needs it.
Future<bool> askPermission(Permission permission, String reason) async {
  if (await permission.isGranted) return true;
  final BuildContext? ctx = rootNav.currentContext;
  if (ctx != null) {
    final bool? go = await showDialog<bool>(
      context: ctx,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Permission needed'),
          content: Text(reason),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Continue')),
          ],
        );
      },
    );
    if (go != true) return false;
  }
  final PermissionStatus status = await permission.request();
  return status.isGranted;
}
