import 'package:flutter/material.dart';
import '../../layouts/desktop_layout_state.dart';
import '../../services/preferences_service.dart';

/// Interactive vertical resize splitter for Desktop Left Sidebar or Right Panel.
///
/// Provides a 6px wide hit area with column resize cursor, hover highlight with theme accent,
/// and smooth drag physics.
class DesktopResizeDivider extends StatefulWidget {
  final bool isRightSide;

  const DesktopResizeDivider({super.key, this.isRightSide = false});

  @override
  State<DesktopResizeDivider> createState() => _DesktopResizeDividerState();
}

class _DesktopResizeDividerState extends State<DesktopResizeDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _isHovered || _isDragging;
    final themeColor = PreferencesService().themeColor;

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
          if (widget.isRightSide) {
            // Dragging left increases right panel width, dragging right decreases it
            final currentWidth = DesktopLayoutState.rightPanelWidth.value;
            final targetWidth = currentWidth - details.delta.dx;
            DesktopLayoutState.updateRightPanelWidth(targetWidth);
          } else {
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
            color: active ? themeColor : Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }
}
