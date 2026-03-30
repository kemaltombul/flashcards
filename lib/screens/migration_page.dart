import 'package:flutter/material.dart';
import '../tools/word_migration_service.dart';

/// Geliştirici aracı: Tüm kelimeleri AI lemmatization pipeline'ından geçirir.
/// Bu sayfaya uygulama içinden erişmek için Settings veya benzeri bir yerden
/// gizli bir route ile çağırın.
class MigrationPage extends StatefulWidget {
  const MigrationPage({super.key});

  @override
  State<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends State<MigrationPage> {
  final _service = WordMigrationService();
  final _logs = <String>[];
  final _scrollController = ScrollController();

  bool _running = false;
  bool _dryRun = true;
  int _done = 0;
  int _total = 0;
  MigrationReport? _report;

  void _addLog(String msg) {
    setState(() => _logs.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _done = 0;
      _total = 0;
      _logs.clear();
      _report = null;
    });

    final report = await _service.run(
      dryRun: _dryRun,
      delayMs: 1200,
      onProgress: (done, total, log) {
        setState(() {
          _done = done;
          _total = total;
        });
        _addLog(log);
      },
    );

    setState(() {
      _running = false;
      _report = report;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠️ Word Migration'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dry-run toggle
            Card(
              child: SwitchListTile(
                title: const Text('Dry-Run Modu'),
                subtitle: Text(
                  _dryRun
                      ? 'Sadece önizleme — Firestore\'a yazma yapılmaz.'
                      : '⚠️ CANLI MOD — Firestore\'a yazılacak!',
                  style: TextStyle(
                    color: _dryRun ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                value: _dryRun,
                onChanged: _running ? null : (v) => setState(() => _dryRun = v),
                activeColor: Colors.green,
              ),
            ),
            const SizedBox(height: 12),

            // Progress bar
            if (_total > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _total > 0 ? _done / _total : null,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_done / $_total kelime',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Log output
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (_, i) => Text(
                    _logs[i],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Summary card
            if (_report != null)
              Card(
                color: _report!.failed > 0
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊 Sonuç${_report!.dryRun ? " (Dry-Run)" : ""}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('✅ Başarılı : ${_report!.success}'),
                      Text('⏭️ Atlandı  : ${_report!.skipped}'),
                      Text('❌ Hatalı   : ${_report!.failed}'),
                      if (_report!.errors.isNotEmpty) ...[
                        const Divider(),
                        const Text(
                          'Hatalı kelimeler:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...(_report!.errors.map(
                          (e) => Text(
                            e,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Start button
            ElevatedButton.icon(
              onPressed: _running ? null : _start,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _running
                    ? 'Çalışıyor...'
                    : (_dryRun ? 'Dry-Run Başlat' : '🚀 Migrasyon Başlat'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _dryRun ? Colors.blueGrey : Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
