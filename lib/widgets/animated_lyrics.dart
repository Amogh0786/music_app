import 'package:flutter/material.dart';

class LyricLine {
  final Duration time;
  final String text;
  LyricLine(this.time, this.text);
}

class AnimatedLyrics extends StatefulWidget {
  final String rawLyrics;
  final Stream<Duration> positionStream;

  const AnimatedLyrics({
    super.key,
    required this.rawLyrics,
    required this.positionStream,
  });

  @override
  State<AnimatedLyrics> createState() => _AnimatedLyricsState();
}

class _AnimatedLyricsState extends State<AnimatedLyrics> {
  final ScrollController _scrollController = ScrollController();
  List<LyricLine> _lyrics = [];
  bool _isSynced = false;
  int _currentIndex = -1;

  @override
  void initState() {
    super.initState();
    _parseLyrics();
  }

  @override
  void didUpdateWidget(covariant AnimatedLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawLyrics != widget.rawLyrics) {
      _parseLyrics();
    }
  }

  void _parseLyrics() {
    _lyrics.clear();
    _isSynced = false;
    _currentIndex = -1;

    if (widget.rawLyrics.isEmpty) return;

    final lines = widget.rawLyrics.split('\n');
    final timeRegExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (var line in lines) {
      final match = timeRegExp.firstMatch(line);
      if (match != null) {
        _isSynced = true;
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        
        String msStr = match.group(3)!;
        if (msStr.length == 2) msStr += '0';
        final milliseconds = int.parse(msStr);
        
        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
        final text = match.group(4)?.trim() ?? '';
        
        // Skip empty timestamped lines to keep UI clean
        if (text.isNotEmpty) {
          _lyrics.add(LyricLine(duration, text));
        }
      }
    }

    if (!_isSynced) {
      // If no valid timestamps were found, it's plain text.
      // We will clean out any malformed tags just in case.
      final cleanRegex = RegExp(r'\[\d+:\d+(\.\d+)?\]');
      final cleanedLines = lines
          .map((l) => l.replaceAll(cleanRegex, '').trim())
          .where((l) => l.isNotEmpty)
          .toList();

      _lyrics = cleanedLines
          .map((l) => LyricLine(Duration.zero, l))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lyrics.isEmpty) {
      return const Center(
        child: Text(
          'No lyrics available.',
          style: TextStyle(color: Colors.white54, fontSize: 18),
        ),
      );
    }

    if (!_isSynced) {
      // Plain text view fallback
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Text(
          _lyrics.map((l) => l.text).join('\n'),
          textAlign: TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: widget.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;

        // Find the current active line
        int newIndex = -1;
        for (int i = 0; i < _lyrics.length; i++) {
          if (position >= _lyrics[i].time) {
            newIndex = i;
          } else {
            break;
          }
        }

        if (newIndex != _currentIndex && newIndex != -1) {
          _currentIndex = newIndex;
          // Auto-scroll logic
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final double offset = (_currentIndex * 42.0) - (MediaQuery.of(context).size.height * 0.2);
              _scrollController.animateTo(
                offset.clamp(0.0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }

        return ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          itemCount: _lyrics.length,
          padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.3),
          itemBuilder: (context, index) {
            final isCurrent = index == _currentIndex;
            final isPassed = index < _currentIndex;
            
            return AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              style: TextStyle(
                color: isCurrent 
                    ? Theme.of(context).primaryColor 
                    : (isPassed ? Colors.white70 : Colors.white24),
                fontSize: isCurrent ? 26 : 22,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                height: 1.5,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Text(_lyrics[index].text),
              ),
            );
          },
        );
      },
    );
  }
}
