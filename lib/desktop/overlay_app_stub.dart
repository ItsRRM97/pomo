import 'package:flutter/widgets.dart';

/// Web fallback for the macOS overlay entrypoint.
class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
