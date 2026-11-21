import 'package:flutter/material.dart';
import '../../services/app_state_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  final AppStateController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;

  static const List<(String label, String hex)> _accents = [
    ('Terracotta', '#C85A32'),
    ('Forest Sage', '#2E7D6B'),
    ('Cobalt', '#355C9A'),
    ('Plum Dusk', '#6D4C7D'),
    ('Ochre', '#A8791F'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.controller.settings.userName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCustomPromptDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Reflection Question'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. What gave me energy today?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await widget.controller.addCustomReflectionPrompt(ctrl.text);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final s = ctrl.settings;
    final completedCount = ctrl.completedTasks.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Statistics'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const SectionHeader(title: 'Personal Statistics'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StatPill(
                label: 'Notes',
                value: '${ctrl.allNotes.where((n) => !n.isDeleted).length}',
                icon: Icons.description_outlined,
              ),
              StatPill(
                label: 'Journal Entries',
                value: '${ctrl.journalEntries.length}',
                icon: Icons.book_outlined,
              ),
              StatPill(
                label: 'Ideas Saved',
                value: '${ctrl.ideas.length}',
                icon: Icons.lightbulb_outline,
              ),
              StatPill(
                label: 'Tasks Done',
                value: '$completedCount',
                icon: Icons.check_circle_outline,
              ),
              StatPill(
                label: 'Voice Notes',
                value: '${ctrl.voiceRecordings.length}',
                icon: Icons.mic_none,
              ),
            ],
          ),
          const SizedBox(height: 12),
          WeeklyActivityChart(dailyCounts: ctrl.getWeeklyActivityCounts()),
          const SectionHeader(title: 'Profile & Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        ctrl.updateSettings(s.copyWith(userName: v.trim())),
                  ),
                  const SizedBox(height: 14),
                  const Text('Theme Mode'),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'system', label: Text('System')),
                      ButtonSegment(value: 'light', label: Text('Light')),
                      ButtonSegment(value: 'dark', label: Text('Dark')),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (sel) =>
                        ctrl.updateSettings(s.copyWith(themeMode: sel.first)),
                  ),
                  const SizedBox(height: 14),
                  const Text('Accent Color'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _accents.map((a) {
                      final active = s.accentHex == a.$2;
                      return ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: AppFormatters.hexToColor(a.$2),
                          radius: 8,
                        ),
                        label: Text(a.$1),
                        selected: active,
                        onSelected: (_) =>
                            ctrl.updateSettings(s.copyWith(accentHex: a.$2)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Text Scale: ${s.textScale.toStringAsFixed(2)}x'),
                  Slider(
                    min: 0.85,
                    max: 1.25,
                    divisions: 8,
                    value: s.textScale,
                    onChanged: (v) =>
                        ctrl.updateSettings(s.copyWith(textScale: v)),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Privacy & Private Space Lock'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Allow Biometrics / Device Lock'),
                  value: s.biometricsEnabled,
                  onChanged: (v) =>
                      ctrl.updateSettings(s.copyWith(biometricsEnabled: v)),
                ),
                ListTile(
                  title: const Text('Auto-lock Timeout'),
                  subtitle: Text(s.autoLockSeconds == 0
                      ? 'Immediately when leaving'
                      : 'After ${s.autoLockSeconds} seconds in background'),
                  trailing: DropdownButton<int>(
                    value: s.autoLockSeconds,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Immediate')),
                      DropdownMenuItem(value: 30, child: Text('30s')),
                      DropdownMenuItem(value: 60, child: Text('60s')),
                      DropdownMenuItem(value: 300, child: Text('5m')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ctrl.updateSettings(s.copyWith(autoLockSeconds: v));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Daily Reflection Prompts'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...ctrl.reflectionPrompts.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              p.isCustom ? Icons.star_outline : Icons.help_outline,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p.question)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addCustomPromptDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Custom Question'),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Backup & Export (Local First)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final file = await ctrl.backupService
                            .createFullBackup(shareAfter: true);
                        await ctrl.refreshAll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Backup saved: ${file.path}')),
                          );
                        }
                      },
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text('Create & Share Local JSON Backup'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final count =
                              await ctrl.backupService.restoreFromBackupFile();
                          await ctrl.refreshAll();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Restored $count record(s) safely.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Restore failed: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore Backup (Non-Destructive Merge)'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final buf = StringBuffer('PERSONAL SPACE NOTES\n\n');
                            for (final n in ctrl.publicActiveNotes) {
                              buf.writeln('=== ${n.title} ===');
                              buf.writeln(n.plainText);
                              buf.writeln('');
                            }
                            await ctrl.backupService.exportAsText(
                              fileNamePrefix: 'personal_space_notes',
                              content: buf.toString(),
                            );
                            await ctrl.refreshAll();
                          },
                          icon: const Icon(Icons.text_snippet_outlined),
                          label: const Text('Export .TXT'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final sections = ctrl.publicActiveNotes
                                .map((n) => (
                                      heading: n.title.isEmpty
                                          ? 'Untitled Note'
                                          : n.title,
                                      meta: AppFormatters.dateTime(n.updatedAt),
                                      body: n.plainText,
                                    ))
                                .toList();
                            await ctrl.backupService.exportAsPdf(
                              documentTitle: 'Personal Space Notes Export',
                              sections: sections.isEmpty
                                  ? [
                                      (
                                        heading: 'Empty Export',
                                        meta: '',
                                        body: 'No active notes available.'
                                      )
                                    ]
                                  : sections,
                            );
                            await ctrl.refreshAll();
                          },
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Export .PDF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
