import 'package:flutter/material.dart';
import '../../layouts/desktop_layout_state.dart';

/// Interactive vertical resize splitter between the Left Sidebar and Center Viewport.
///
/// Provides a 4px wide hit area with column resize cursor, hover highlight (#FA2D48),
/// and drag physics that snap the sidebar to collapsed icon mode (72px) when dragged < 120px.
class DesktopResizeDivider extends StatefulWidget {
  const DesktopResizeDivider({super.key});

  @override
  State<DesktopResizeDivider> createState() => _DesktopResizeDividerState();
}

class _DesktopResizeDividerState extends State<DesktopResizeDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _isHovered || _isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
        onHorizontalDragCancel: () => setState(() => _isDragging = false),
        onHorizontalDragUpdate: (details) {
          final currentWidth = DesktopLayoutState.leftSidebarWidth.value;
          final targetWidth = currentWidth + details.delta.dx;

          if (currentWidth <= 72.0 && details.delta.dx > 0) {
            // Dragging out of collapsed mode: snap straight to expanded starting width
            if (targetWidth > 120.0) {
              DesktopLayoutState.updateLeftSidebarWidth(280.0);
            }
          } else {
            DesktopLayoutState.updateLeftSidebarWidth(targetWidth);
          }
        },
        child: Container(
          width: 6.0,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            width: active ? 2.0 : 1.0,
            color: active
                ? const Color(0xFFFA2D48)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }
}
