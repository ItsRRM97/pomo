import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pomo/services/android_notification_service.dart';

class AndroidBatteryOptTile extends StatefulWidget {
  const AndroidBatteryOptTile({
    super.key,
    this.isAndroidOverride,
    this.isIgnoringBatteryOptimizations,
    this.requestIgnoreBatteryOptimizations,
  });

  final bool? isAndroidOverride;
  final Future<bool> Function()? isIgnoringBatteryOptimizations;
  final Future<bool> Function()? requestIgnoreBatteryOptimizations;

  @override
  State<AndroidBatteryOptTile> createState() => _AndroidBatteryOptTileState();
}

class _AndroidBatteryOptTileState extends State<AndroidBatteryOptTile> {
  bool? _isIgnoring;
  final _service = AndroidNotificationService();

  bool get _isAndroid =>
      widget.isAndroidOverride ?? (!kIsWeb && Platform.isAndroid);

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<bool> _fetchIgnoringStatus() {
    final fetch = widget.isIgnoringBatteryOptimizations;
    if (fetch != null) return fetch();
    return _service.isIgnoringBatteryOptimizations();
  }

  Future<bool> _requestIgnore() {
    final request = widget.requestIgnoreBatteryOptimizations;
    if (request != null) return request();
    return _service.requestIgnoreBatteryOptimizations();
  }

  Future<void> _refreshStatus() async {
    final ignoring = await _fetchIgnoringStatus();
    if (mounted) {
      setState(() => _isIgnoring = ignoring);
    }
  }

  Future<void> _onTap() async {
    await _requestIgnore();
    await _refreshStatus();
  }

  String _subtitleFor(bool? ignoring) {
    if (ignoring == null) return 'Checking...';
    // ignoring == true means OS is not applying battery optimization.
    if (ignoring) return 'Allowed (unrestricted)';
    return 'Optimized (may delay reminders)';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAndroid) {
      return const SizedBox.shrink();
    }

    return ListTile(
      title: const Text('Unrestricted battery'),
      subtitle: Text(_subtitleFor(_isIgnoring)),
      onTap: _onTap,
    );
  }
}
