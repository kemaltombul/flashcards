import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_logger.dart';

const _adminUid = 'CQk9Sf8MK4VwyBkQNjYK3ZdlzL13';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final AppLogger _logger = AppLogger.instance;

  // ── Filters ────────────────────────────────
  LogLevel? _selectedLevel;
  LogCategory? _selectedCategory;

  // ── Design tokens (CollectionsPage ile aynı) ─
  final Color _cardColor = const Color(0xFF252525).withOpacity(0.9);
  final Color _accentColor = const Color(0xFFD0BCFF);
  final TextStyle _textStyle = const TextStyle(
    fontFamily: 'Roboto',
    color: Colors.white,
    letterSpacing: 0.5,
  );

  // ─────────────────────────────────────────────
  // Level helpers
  // ─────────────────────────────────────────────

  Color _levelColor(LogLevel level) => switch (level) {
    LogLevel.info => const Color(0xFF64B5F6),
    LogLevel.warning => const Color(0xFFFFB74D),
    LogLevel.error => const Color(0xFFEF5350),
    LogLevel.critical => const Color(0xFFCE93D8),
  };

  IconData _levelIcon(LogLevel level) => switch (level) {
    LogLevel.info => Icons.info_outline_rounded,
    LogLevel.warning => Icons.warning_amber_rounded,
    LogLevel.error => Icons.error_outline_rounded,
    LogLevel.critical => Icons.crisis_alert_rounded,
  };

  Color _categoryColor(LogCategory cat) => switch (cat) {
    LogCategory.firestore => const Color(0xFFFF8A65),
    LogCategory.auth => const Color(0xFF81C784),
    LogCategory.ai => const Color(0xFFD0BCFF),
    LogCategory.navigation => const Color(0xFF4DD0E1),
    LogCategory.general => Colors.white38,
  };

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear All Logs',
          style: _textStyle.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will permanently delete all log entries. Are you sure?',
          style: _textStyle.copyWith(color: Colors.white60, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _logger.clearAllLogs();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'All logs cleared.',
                      style: TextStyle(color: Colors.black),
                    ),
                    backgroundColor: _accentColor,
                  ),
                );
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogDetail(AppLogEntry log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.97),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),

                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _levelColor(log.level).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _levelIcon(log.level),
                          color: _levelColor(log.level),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.operation,
                              style: _textStyle.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              log.timestamp
                                  .toIso8601String()
                                  .replaceFirst('T', '  ')
                                  .substring(0, 22),
                              style: _textStyle.copyWith(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // delete button
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _logger.deleteLog(log.id);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  _detailRow(
                    'Level',
                    log.level.name.toUpperCase(),
                    _levelColor(log.level),
                  ),
                  _detailRow(
                    'Category',
                    log.category.name,
                    _categoryColor(log.category),
                  ),
                  if (log.userId != null)
                    _detailRow('User ID', log.userId!, Colors.white54),

                  const SizedBox(height: 16),
                  _detailSection('Message', log.message),

                  if (log.meta != null && log.meta!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _detailSection(
                      'Meta',
                      log.meta!.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                    ),
                  ],

                  if (log.detail != null && log.detail!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _detailSection(
                      'Stack Trace / Detail',
                      log.detail!,
                      isCode: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color valueColor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: _textStyle.copyWith(color: Colors.white38, fontSize: 12),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _detailSection(String title, String content, {bool isCode = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _textStyle.copyWith(
              color: Colors.white38,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Text(
              content,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isCode ? 11 : 13,
                fontFamily: isCode ? 'monospace' : 'Roboto',
                height: 1.5,
              ),
            ),
          ),
        ],
      );

  // ─────────────────────────────────────────────
  // Filter chips
  // ─────────────────────────────────────────────

  Widget _filterBar() => SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Level filters
        ...LogLevel.values.map(
          (l) => _chip(
            label: l.name,
            color: _levelColor(l),
            selected: _selectedLevel == l,
            onTap: () =>
                setState(() => _selectedLevel = _selectedLevel == l ? null : l),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 1,
          color: Colors.white12,
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
        const SizedBox(width: 8),
        // Category filters
        ...LogCategory.values.map(
          (c) => _chip(
            label: c.name,
            color: _categoryColor(c),
            selected: _selectedCategory == c,
            onTap: () => setState(
              () => _selectedCategory = _selectedCategory == c ? null : c,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _chip({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? color.withOpacity(0.22)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? color.withOpacity(0.7)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? color : Colors.white54,
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    ),
  );

  // ─────────────────────────────────────────────
  // Log tile
  // ─────────────────────────────────────────────

  Widget _logTile(AppLogEntry log) {
    final color = _levelColor(log.level);
    return GestureDetector(
      onTap: () => _showLogDetail(log),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18)),
          color: Colors.white.withOpacity(0.03),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Level indicator bar
                  Container(
                    width: 3,
                    height: 44,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Icon
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 12),
                    child: Icon(_levelIcon(log.level), color: color, size: 18),
                  ),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                log.operation,
                                style: _textStyle.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatTime(log.timestamp),
                              style: _textStyle.copyWith(
                                fontSize: 11,
                                color: Colors.white30,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          log.message,
                          style: _textStyle.copyWith(
                            fontSize: 12,
                            color: Colors.white60,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Category pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _categoryColor(
                              log.category,
                            ).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            log.category.name,
                            style: TextStyle(
                              color: _categoryColor(log.category),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chevron
                  const Padding(
                    padding: EdgeInsets.only(top: 10, left: 8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white12,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Admin değilse erişim engeli
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != _adminUid) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: Colors.white12,
              ),
              const SizedBox(height: 16),
              Text(
                'Access denied.',
                style: _textStyle.copyWith(color: Colors.white30, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App Bar ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'App Logs',
                    style: _textStyle.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                    tooltip: 'Clear All',
                    onPressed: _confirmClearAll,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Filter bar ───────────────────────
            _filterBar(),

            const SizedBox(height: 14),

            // ── Log list ─────────────────────────
            Expanded(
              child: StreamBuilder<List<AppLogEntry>>(
                stream: _logger.logsStream(
                  level: _selectedLevel,
                  category: _selectedCategory,
                  limit: 150,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 56,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load logs:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: _textStyle.copyWith(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final logs = snapshot.data ?? [];

                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.checklist_rounded,
                            size: 64,
                            color: Colors.white.withOpacity(0.07),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedLevel != null || _selectedCategory != null
                                ? 'No logs match the current filter.'
                                : 'No logs yet.',
                            style: _textStyle.copyWith(
                              color: Colors.white30,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: logs.length,
                    padding: const EdgeInsets.only(bottom: 40),
                    itemBuilder: (_, i) => _logTile(logs[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
