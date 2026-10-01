import 'package:flutter/material.dart';

/// Centralized responsive layout container for DilSe.
///
/// - On mobile devices (width < [desktopBreakpoint]):
///   Renders 100% full-width, edge-to-edge with zero margins or letterboxing.
/// - On tablets/desktops/laptops (width >= [desktopBreakpoint]):
///   Centers the content with a constrained maximum width ([maxDesktopContentWidth])
///   to prevent ultra-wide CanvasKit WebGL rasterization overhead and card overdraw.
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  static const double desktopBreakpoint = 768.0;
  static const double maxDesktopContentWidth = 860.0;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = maxDesktopContentWidth,
  });

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < desktopBreakpoint;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth < desktopBreakpoint) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
