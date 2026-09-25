import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LyricLine {
  final Duration time;
  final String text;
  LyricLine(this.time, this.text);
}

class AnimatedLyrics extends StatefulWidget {
  final String rawLyrics;
  final Stream<Duration> positionStream;
  final void Function(Duration)? onSeek;

  const AnimatedLyrics({
    super.key,
    required this.rawLyrics,
    required this.positionStream,
    this.onSeek,
  });

  @override
  State<AnimatedLyrics> createState() => _AnimatedLyricsState();
}

class _AnimatedLyricsState extends State<AnimatedLyrics> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  StreamSubscription<Duration>? _positionSubscription;

  List<LyricLine> _lyrics = [];
  bool _isSynced = false;
  int _currentIndex = -1;

  // Auto-scroll control
  bool _isUserScrolling = false;
  Timer? _userScrollResumeTimer;

  @override
  void initState() {
    super.initState();
    _parseLyrics();
    _subscribeToPosition();
  }

  void _subscribeToPosition() {
    _positionSubscription?.cancel();
    _positionSubscription = widget.positionStream.listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Duration position) {
    if (!mounted || !_isSynced || _lyrics.isEmpty) return;

    // Fast binary search for active index
    int activeIndex = -1;
    int low = 0;
    int high = _lyrics.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (_lyrics[mid].time <= position) {
        activeIndex = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (activeIndex != _currentIndex) {
      setState(() {
        _currentIndex = activeIndex;
      });
      if (!_isUserScrolling) {
        _scrollToActiveLine(_currentIndex);
      }
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionStream != widget.positionStream) {
      _subscribeToPosition();
    }
    if (oldWidget.rawLyrics != widget.rawLyrics) {
      _lineKeys.clear();
      setState(() {
        _currentIndex = -1;
        _parseLyrics();
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _userScrollResumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _parseLyrics() {
    _lyrics.clear();
    _lineKeys.clear();
    _isSynced = false;
    _currentIndex = -1;

    if (widget.rawLyrics.trim().isEmpty) return;

    final lines = widget.rawLyrics.split('\n');
    // Flexible regex matching: [01:23.45], [1:23.456], [01:23:45], [01:23]
    final tagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');

    final parsedSynced = <LyricLine>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Ignore LRC header metadata tags: [ar:...], [al:...], [ti:...], [length:...]
      if (RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(line)) continue;

      final matches = tagRegex.allMatches(line);
      if (matches.isNotEmpty) {
        final text = line.replaceAll(tagRegex, '').trim();
        if (text.isEmpty) continue;

        for (final m in matches) {
          final minutes = int.parse(m.group(1)!);
          final seconds = int.parse(m.group(2)!);
          int milliseconds = 0;
          final msGroup = m.group(3);
          if (msGroup != null) {
            if (msGroup.length == 1) {
              milliseconds = int.parse(msGroup) * 100;
            } else if (msGroup.length == 2) {
              milliseconds = int.parse(msGroup) * 10;
            } else {
              milliseconds = int.parse(msGroup.substring(0, 3));
            }
          }

          final duration = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          );
          parsedSynced.add(LyricLine(duration, text));
        }
      }
    }

    if (parsedSynced.isNotEmpty) {
      _isSynced = true;
      parsedSynced.sort((a, b) => a.time.compareTo(b.time));
      _lyrics = parsedSynced;
    } else {
      // Unsynced Plain Text fallback
      _isSynced = false;
      final cleanRegex = RegExp(r'\[\d+:\d+(?:[.:]\d+)?\]');
      final cleaned = <LyricLine>[];
      bool prevWasEmpty = false;

      for (final rawLine in lines) {
        final line = rawLine.replaceAll(cleanRegex, '').trim();
        if (RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(line)) continue;

        if (line.isEmpty) {
          if (!prevWasEmpty && cleaned.isNotEmpty) {
            cleaned.add(LyricLine(Duration.zero, ''));
            prevWasEmpty = true;
          }
        } else {
          cleaned.add(LyricLine(Duration.zero, line));
          prevWasEmpty = false;
        }
      }
      _lyrics = cleaned;
    }
  }

  void _scrollToActiveLine(int index) {
    if (_isUserScrolling || index < 0 || index >= _lyrics.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isUserScrolling) return;

      final key = _lineKeys[index];
      final targetContext = key?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.35,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      } else if (_scrollController.hasClients) {
        final screenH = MediaQuery.of(context).size.height;
        final targetOffset = (index * 56.0) - (screenH * 0.20);
        final clampedOffset = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

        _scrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if empty or standard info placeholder
    final isInfoMessage = _lyrics.isEmpty ||
        (_lyrics.length <= 2 &&
            _lyrics.any((l) =>
                l.text.toLowerCase().contains('no lyrics') ||
                l.text.toLowerCase().contains('temporarily unavailable')));

    if (isInfoMessage) {
      final msg = _lyrics.isNotEmpty ? _lyrics.first.text : 'No lyrics available for this song';
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Icon(Icons.lyrics_outlined, color: Colors.white38, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Unsynced Lyrics: Beautiful reading layout with edge gradient dissolve
    if (!_isSynced) {
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.06, 0.94, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unsynced Lyrics Pill Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notes_rounded, size: 14, color: Colors.white70),
                      SizedBox(width: 6),
                      Text(
                        'Unsynced Lyrics',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...List.generate(_lyrics.length, (idx) {
                final line = _lyrics[idx].text;
                if (line.isEmpty) {
                  return const SizedBox(height: 18);
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.55,
                      letterSpacing: 0.2,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 48),
            ],
          ),
        ),
      );
    }

    // Synced Lyrics: Smooth auto-scrolling with edge fade & interactive tap-to-seek
    final themeColor = Theme.of(context).primaryColor;

    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.08, 0.92, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is UserScrollNotification) {
            _isUserScrolling = true;
            _userScrollResumeTimer?.cancel();
            _userScrollResumeTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) {
                _isUserScrolling = false;
                _scrollToActiveLine(_currentIndex);
              }
            });
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          itemCount: _lyrics.length,
          padding: EdgeInsets.symmetric(
            vertical: MediaQuery.of(context).size.height * 0.22,
            horizontal: 4,
          ),
          itemBuilder: (context, index) {
            final isCurrent = index == _currentIndex;
            final isPassed = index < _currentIndex;
            final item = _lyrics[index];

            final key = _lineKeys.putIfAbsent(index, () => GlobalKey());

            return GestureDetector(
              key: key,
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onSeek?.call(item.time);
                _isUserScrolling = false;
                _scrollToActiveLine(index);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: isCurrent
                        ? themeColor
                        : (isPassed
                            ? Colors.white.withValues(alpha: 0.72)
                            : Colors.white.withValues(alpha: 0.28)),
                    fontSize: isCurrent ? 24 : 19.5,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    height: 1.45,
                    shadows: isCurrent
                        ? [
                            Shadow(
                              color: themeColor.withValues(alpha: 0.55),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(item.text),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
