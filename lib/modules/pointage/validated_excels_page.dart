import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/responsive.dart';
import 'data/excel_validation_repository.dart';

class ValidatedExcelsPage extends StatefulWidget {
  const ValidatedExcelsPage({super.key});

  @override
  State<ValidatedExcelsPage> createState() => _ValidatedExcelsPageState();
}

class _ValidatedExcelsPageState extends State<ValidatedExcelsPage> {
  final ExcelValidationRepository _repo = ExcelValidationRepository();
  DateTime _start = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _end = DateTime.now();
  String? _equipeFilter;
  bool _loading = true;
  List<ExcelValidationRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _repo.getRecentValidated(limit: 200);
    if (!mounted) return;
    setState(() {
      _records = all;
      _loading = false;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _end = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
  }

  Future<void> _openFile(String path) async {
    if (path.trim().isEmpty) return;
    try {
      final f = File(path);
      if (!f.existsSync()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fichier introuvable sur cet appareil.'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
        return;
      }
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le fichier.'),
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = pagePadding(context);
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    final filtered = _records.where((r) {
      final periodStart = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
      final periodEnd = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
      final inDate = !periodEnd.isBefore(_start) && !periodStart.isAfter(_end);
      final inEquipe = _equipeFilter == null ||
          _equipeFilter!.isEmpty ||
          (r.equipeId ?? '') == _equipeFilter;
      return inDate && inEquipe;
    }).toList();

    final equipeIds = _records
        .map((e) => e.equipeId ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rapports Excel validés',
            style: TextStyle(
              fontSize: isMobile(context) ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range),
                label: Text('${fmt(_start)} → ${fmt(_end)}'),
              ),
              DropdownButton<String?>(
                value: _equipeFilter,
                hint: const Text('Filtrer équipe'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Toutes les équipes'),
                  ),
                  ...equipeIds.map(
                    (id) => DropdownMenuItem<String?>(
                      value: id,
                      child: Text(id),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _equipeFilter = v),
              ),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (filtered.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun rapport validé pour ce filtre.'),
              ),
            )
          else
            ...filtered.map((r) {
              final by = r.createdByName.isEmpty ? r.createdById : r.createdByName;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.verified, color: Colors.green),
                  title: Text('${fmt(r.startDate)} → ${fmt(r.endDate)}'),
                  subtitle: Text(
                    'Par: $by • Scope: ${r.scope}${(r.equipeId ?? '').isNotEmpty ? ' • Équipe: ${r.equipeId}' : ''}',
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      IconButton(
                        tooltip: 'Copier chemin',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: r.filePath),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chemin copié.'),
                              behavior: SnackBarBehavior.fixed,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_all_outlined),
                      ),
                      IconButton(
                        tooltip: 'Ouvrir',
                        onPressed: () => _openFile(r.filePath),
                        icon: const Icon(Icons.open_in_new),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
