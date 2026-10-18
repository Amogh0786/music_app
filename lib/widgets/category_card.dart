import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme_tokens.dart';

class CategoryCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String query;
  final List<Color> colors;
  final IconData icon;
  final String? badgeText;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.colors,
    required this.icon,
    this.badgeText,
    required this.onTap,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.96 : (_isHovered ? 1.025 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.colors.first.withValues(
                    alpha: _isHovered ? 0.38 : 0.26,
                  ),
                  AppThemeTokens.surfaceCard,
                ],
              ),
              borderRadius: BorderRadius.circular(AppThemeTokens.radiusCard),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.24)
                    : AppThemeTokens.surfaceBorder,
                width: 1.0,
              ),
              boxShadow: AppThemeTokens.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppThemeTokens.radiusCard),
              child: Stack(
                children: [
                  // Subtle translucent hover highlight
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _isHovered ? 0.06 : 0.0,
                      child: Container(color: Colors.white),
                    ),
                  ),

                  // Stylized Angled Watermark Symbol
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: AnimatedScale(
                      scale: _isHovered ? 1.16 : 1.0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: AnimatedRotation(
                        turns: _isHovered ? -0.06 : -0.04,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          widget.icon,
                          size: 78,
                          color: Colors.white.withValues(
                            alpha: _isHovered ? 0.14 : 0.08,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Card Content
                  LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final isVeryCompact = cardConstraints.maxHeight < 68;
                      final isCompact = cardConstraints.maxHeight < 85;
                      final isNarrow = cardConstraints.maxWidth < 130;
                      final padH = isNarrow ? 8.0 : 14.0;
                      final padV = isVeryCompact
                          ? 4.0
                          : (isCompact ? 6.0 : 12.0);

                      return ClipRect(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: padH,
                            vertical: padV,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Header: Badge + Hover Play Micro-Button
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Frosted Category Pill
                                  Flexible(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isNarrow ? 6 : 8,
                                        vertical: isCompact ? 2 : 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.28,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.18,
                                          ),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            widget.icon,
                                            size: isCompact ? 9 : 11,
                                            color: Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                          ),
                                          if (widget.badgeText != null &&
                                              widget.badgeText!.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                widget.badgeText!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: isCompact
                                                      ? 8.5
                                                      : 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!isNarrow) ...[
                                    const SizedBox(width: 4),
                                    // Micro Hover Play Trigger
                                    AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      opacity: _isHovered ? 1.0 : 0.0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              // Bottom Titles
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isCompact ? 13 : 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    if (!isCompact ||
                                        cardConstraints.maxHeight > 65) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        widget.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.82,
                                          ),
                                          fontSize: isCompact ? 9.5 : 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
