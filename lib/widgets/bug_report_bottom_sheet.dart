import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class BugReportBottomSheet extends StatefulWidget {
  final Video? song;
  final String appVersion;
  final String buildNumber;

  const BugReportBottomSheet({
    super.key,
    this.song,
    this.appVersion = '3.4.0',
    this.buildNumber = '',
  });

  static Future<void> show(
    BuildContext context, {
    Video? song,
    String appVersion = '3.4.0',
    String buildNumber = '',
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BugReportBottomSheet(
        song: song,
        appVersion: appVersion,
        buildNumber: buildNumber,
      ),
    );
  }

  @override
  State<BugReportBottomSheet> createState() => _BugReportBottomSheetState();
}

class _BugReportBottomSheetState extends State<BugReportBottomSheet> {
  final TextEditingController _notesController = TextEditingController();
  String _selectedCategory = 'Audio / Playback';
  bool _showDiagnostics = false;

  final List<String> _categories = [
    'Audio / Playback',
    'UI / Glitch',
    'Lyrics / Sync',
    'Search / Results',
    'App Crash',
    'Other',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _getPlatformInfo() {
    if (kIsWeb) return 'Web Browser';
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'Unknown Platform';
    }
  }

  String _buildReportText({bool isMarkdown = false}) {
    final osInfo = _getPlatformInfo();
    final userNotes = _notesController.text.trim();

    if (isMarkdown) {
      final buffer = StringBuffer();
      buffer.writeln('### Bug Description');
      buffer.writeln(userNotes.isNotEmpty ? userNotes : '_No description provided_');
      buffer.writeln();
      buffer.writeln('### Category');
      buffer.writeln('`$_selectedCategory`');
      buffer.writeln();
      buffer.writeln('### Diagnostics & Environment');
      buffer.writeln('- **App Version:** ${widget.appVersion} (${widget.buildNumber})');
      buffer.writeln('- **Platform:** $osInfo');
      if (widget.song != null) {
        buffer.writeln('- **Track Title:** ${widget.song!.title}');
        buffer.writeln('- **Artist:** ${widget.song!.author}');
        buffer.writeln('- **Song ID:** `${widget.song!.id.value}`');
        buffer.writeln('- **URL:** ${widget.song!.url}');
      }
      return buffer.toString();
    } else {
      final buffer = StringBuffer();
      buffer.writeln('Category: $_selectedCategory');
      buffer.writeln();
      buffer.writeln('Description:');
      buffer.writeln(userNotes.isNotEmpty ? userNotes : '(None)');
      buffer.writeln();
      buffer.writeln('--- System Diagnostics ---');
      buffer.writeln('DilSe Version: ${widget.appVersion} (${widget.buildNumber})');
      buffer.writeln('Platform: $osInfo');
      if (widget.song != null) {
        buffer.writeln('Song: "${widget.song!.title}" by ${widget.song!.author}');
        buffer.writeln('Song ID: ${widget.song!.id.value}');
        buffer.writeln('URL: ${widget.song!.url}');
      }
      return buffer.toString();
    }
  }

  Future<void> _sendEmail() async {
    HapticFeedback.lightImpact();
    final subject = '[$_selectedCategory] DilSe Music Bug Report (v${widget.appVersion})';
    final body = _buildReportText();

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'balaamoghraj@gmail.com',
      queryParameters: {
        'cc': 'charanteja.kondakalla030206@gmail.com',
        'subject': subject,
        'body': body,
      },
    );

    try {
      final launched = await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await _fallbackCopyAndAlert('Could not launch email app. Details copied to clipboard!');
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      await _fallbackCopyAndAlert('Could not launch email app. Details copied to clipboard!');
    }
  }

  Future<void> _openGitHub() async {
    HapticFeedback.lightImpact();
    final userNotes = _notesController.text.trim();
    final shortTitle = userNotes.isNotEmpty
        ? (userNotes.length > 50 ? '${userNotes.substring(0, 47)}...' : userNotes)
        : 'Bug Report';
    final title = '[$_selectedCategory] $shortTitle';
    final body = _buildReportText(isMarkdown: true);

    final Uri githubUri = Uri.parse(
      'https://github.com/charanteja-k/music_app/issues/new?title=${Uri.encodeComponent(title)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      final launched = await launchUrl(githubUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await _fallbackCopyAndAlert('Could not open browser. Details copied to clipboard!');
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      await _fallbackCopyAndAlert('Could not open browser. Details copied to clipboard!');
    }
  }

  Future<void> _copyDetails() async {
    HapticFeedback.selectionClick();
    final report = _buildReportText();
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bug report & diagnostics copied to clipboard!'),
          backgroundColor: Color(0xFFFA2D48),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _fallbackCopyAndAlert(String message) async {
    final report = _buildReportText();
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFFA2D48),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center Grabber
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFA2D48).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFA2D48).withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.bug_report_rounded,
                    color: Color(0xFFFA2D48),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report a Bug / Feedback',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Help us fix issues and elevate DilSe',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Issue Category Chips
            const Text(
              'ISSUE TYPE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    }
                  },
                  selectedColor: const Color(0xFFFA2D48),
                  backgroundColor: const Color(0xFF1E1E2C),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFFFA2D48)
                        : Colors.white.withValues(alpha: 0.10),
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Description Field
            const Text(
              'DESCRIPTION (OPTIONAL)',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _notesController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'What happened? What were you trying to do?',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Diagnostic Snapshot Card (Collapsible)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showDiagnostics = !_showDiagnostics);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white60, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'System Diagnostics (${widget.appVersion}, ${_getPlatformInfo().split(' ').first})',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Icon(
                      _showDiagnostics ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            if (_showDiagnostics) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  _buildReportText(),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Primary Actions: Email and GitHub
            Row(
              children: [
                // Send Email Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.email_rounded, size: 18),
                    label: const Text(
                      'Email Report',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA2D48),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // GitHub Issue Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openGitHub,
                    icon: const Icon(Icons.code_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'GitHub Issue',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Copy to Clipboard Fallback Action
            Center(
              child: TextButton.icon(
                onPressed: _copyDetails,
                icon: const Icon(Icons.copy_all_rounded, size: 16, color: Colors.white54),
                label: const Text(
                  'Copy Report & Diagnostics to Clipboard',
                  style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
