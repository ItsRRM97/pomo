import 'package:flutter/material.dart';

/// Web and non-desktop fallback that passes through the main app tree.
class DesktopShell extends StatelessWidget {
  const DesktopShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
