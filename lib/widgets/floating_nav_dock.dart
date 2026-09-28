import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Apple-Style Hardware-Grade Frosted Glass Floating Bottom Navigation Dock
class FloatingNavDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingNavDock({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    final tabs = [
      _NavTabItem(
        icon: Icons.play_circle_outline_rounded,
        activeIcon: Icons.play_circle_fill_rounded,
        label: 'Listen Now',
      ),
      _NavTabItem(
        icon: Icons.search_rounded,
        activeIcon: Icons.saved_search_rounded,
        label: 'Search',
      ),
      _NavTabItem(
        icon: Icons.library_music_outlined,
        activeIcon: Icons.library_music_rounded,
        label: 'Library',
      ),
    ];

    return RepaintBoundary(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xDD0D0D14),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.85,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tabWidth = constraints.maxWidth / tabs.length;
                    return Stack(
                      children: [
                        // Fluid Apple-style sliding indicator pill with spring ease
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.fastLinearToSlowEaseIn,
                          left: selectedIndex * tabWidth,
                          top: 0,
                          bottom: 0,
                          width: tabWidth,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primaryColor.withValues(alpha: 0.28),
                                  primaryColor.withValues(alpha: 0.16),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.55),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Interactive tabs with spring-scale bounce
                        Row(
                          children: List.generate(tabs.length, (index) {
                            final tab = tabs[index];
                            final isSelected = selectedIndex == index;

                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (!isSelected) {
                                    HapticFeedback.lightImpact();
                                    onTabSelected(index);
                                  }
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: isSelected ? 1.12 : 1.0,
                                        duration: const Duration(milliseconds: 260),
                                        curve: Curves.easeOutBack,
                                        child: Icon(
                                          isSelected ? tab.activeIcon : tab.icon,
                                          color: isSelected ? Colors.white : Colors.white60,
                                          size: 23,
                                        ),
                                      ),
                                      AnimatedCrossFade(
                                        duration: const Duration(milliseconds: 220),
                                        crossFadeState: isSelected
                                            ? CrossFadeState.showFirst
                                            : CrossFadeState.showSecond,
                                        firstChild: Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: Text(
                                            tab.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ),
                                        secondChild: const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
