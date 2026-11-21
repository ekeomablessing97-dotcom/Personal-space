import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../models/feature_models.dart';
import '../../services/app_state_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../notes/note_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppStateController controller;
  final void Function(int navIndex) onNavigateTab;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.onNavigateTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openNewNote({String initialText = ''}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          controller: widget.controller,
          initialPlainText: initialText,
        ),
      ),
    );
  }

  void _openCustomizeDashboardSheet() {
    final allSections = [
      ('greeting', 'Greeting & Date'),
      ('quick_actions', 'Quick Actions & Sections'),
      ('stats', 'Activity Summary'),
      ('pinned_notes', 'Pinned Notes'),
      ('recent_notes', 'Recently Edited Notes'),
      ('upcoming_tasks', 'Upcoming Tasks & Reminders'),
      ('reflection', 'Daily Reflection Prompt'),
    ];
    final selected = List<String>.from(widget.controller.settings.homeSections);

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customize Home Dashboard',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: allSections.map((s) {
                        final active = selected.contains(s.$1);
                        return CheckboxListTile(
                          value: active,
                          title: Text(s.$2),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selected.add(s.$1);
                              } else if (selected.length > 1) {
                                selected.remove(s.$1);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await widget.controller.updateSettings(
                          widget.controller.settings.copyWith(
                            homeSections: selected,
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Layout'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final theme = Theme.of(context);
    final sections = ctrl.settings.homeSections;

    final matches = _query.trim().isEmpty
        ? const <NoteModel>[]
        : ctrl.publicActiveNotes.where((n) {
            final q = _query.toLowerCase();
            return n.title.toLowerCase().contains(q) ||
                n.plainText.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.auto_awesome_mosaic,
                  color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            const Text(
              'PERSONAL SPACE',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Customize Dashboard',
            icon: const Icon(Icons.tune),
            onPressed: _openCustomizeDashboardSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewNote(),
        icon: const Icon(Icons.edit_note),
        label: const Text('Quick Note'),
      ),
      body: RefreshIndicator(
        onRefresh: ctrl.refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search your notes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
            if (_query.isNotEmpty) ...[
              SectionHeader(title: 'Search Results (${matches.length})'),
              if (matches.isEmpty)
                const EmptyStateCard(
                  icon: Icons.search_off,
                  title: 'No matching notes',
                  subtitle: 'Try a different keyword or title.',
                )
              else
                ...matches.map((n) => _NotePreviewTile(
                      note: n,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NoteEditorScreen(controller: ctrl, existingNote: n),
                        ),
                      ),
                    )),
            ] else ...[
              if (sections.contains('greeting')) ...[
                const SizedBox(height: 14),
                Text(
                  '${AppFormatters.greetingForHour(DateTime.now().hour)}, ${ctrl.settings.userName}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatters.fullDate(DateTime.now()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (sections.contains('quick_actions')) ...[
                const SectionHeader(title: 'Quick Access'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickNavChip(
                      icon: Icons.book_outlined,
                      label: 'Journal',
                      onTap: () => widget.onNavigateTab(2),
                    ),
                    _QuickNavChip(
                      icon: Icons.lightbulb_outline,
                      label: 'Idea Vault',
                      onTap: () => widget.onNavigateTab(3),
                    ),
                    _QuickNavChip(
                      icon: Icons.check_circle_outline,
                      label: 'Tasks',
                      onTap: () => widget.onNavigateTab(4),
                    ),
                    _QuickNavChip(
                      icon: Icons.mic_none,
                      label: 'Voice Notes',
                      onTap: () => widget.onNavigateTab(5),
                    ),
                    _QuickNavChip(
                      icon: Icons.history,
                      label: 'Memory Lane',
                      onTap: () => widget.onNavigateTab(6),
                    ),
                    _QuickNavChip(
                      icon: Icons.lock_outline,
                      label: 'Private Space',
                      onTap: () => widget.onNavigateTab(7),
                    ),
                  ],
                ),
              ],
              if (sections.contains('stats')) ...[
                SectionHeader(
                  title: 'Personal Snapshot',
                  actionLabel: 'Full Stats',
                  onAction: () => widget.onNavigateTab(8),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      StatPill(
                        label: 'Notes',
                        value: '${ctrl.publicActiveNotes.length}',
                        icon: Icons.description_outlined,
                      ),
                      const SizedBox(width: 10),
                      StatPill(
                        label: 'Ideas',
                        value: '${ctrl.ideas.length}',
                        icon: Icons.lightbulb_outline,
                      ),
                      const SizedBox(width: 10),
                      StatPill(
                        label: 'Open Tasks',
                        value: '${ctrl.upcomingTasks.length}',
                        icon: Icons.task_alt,
                      ),
                      const SizedBox(width: 10),
                      StatPill(
                        label: 'Voice Notes',
                        value: '${ctrl.voiceRecordings.length}',
                        icon: Icons.mic_none,
                      ),
                    ],
                  ),
                ),
              ],
              if (sections.contains('pinned_notes') &&
                  ctrl.pinnedNotes.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Pinned Notes',
                  icon: Icons.push_pin_outlined,
                ),
                ...ctrl.pinnedNotes.take(3).map(
                      (n) => _NotePreviewTile(
                        note: n,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NoteEditorScreen(
                              controller: ctrl,
                              existingNote: n,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
              if (sections.contains('recent_notes')) ...[
                SectionHeader(
                  title: 'Recently Edited',
                  actionLabel: 'All Notes',
                  onAction: () => widget.onNavigateTab(1),
                ),
                if (ctrl.publicActiveNotes.isEmpty)
                  EmptyStateCard(
                    icon: Icons.note_add_outlined,
                    title: 'Your space is ready',
                    subtitle: 'Capture a thought, draft a plan, or record an idea.',
                    buttonLabel: 'Create Note',
                    onPressed: () => _openNewNote(),
                  )
                else
                  ...ctrl.publicActiveNotes.take(3).map(
                        (n) => _NotePreviewTile(
                          note: n,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NoteEditorScreen(
                                controller: ctrl,
                                existingNote: n,
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
              if (sections.contains('upcoming_tasks')) ...[
                SectionHeader(
                  title: 'Upcoming Tasks & Reminders',
                  actionLabel: 'Planner',
                  onAction: () => widget.onNavigateTab(4),
                ),
                if (ctrl.upcomingTasks.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.done_all,
                    title: 'No pending tasks',
                    subtitle: 'Enjoy a clear queue or plan your next milestone.',
                  )
                else
                  ...ctrl.upcomingTasks.take(3).map(
                        (TaskModel t) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Checkbox(
                              value: t.isCompleted,
                              onChanged: (_) => ctrl.toggleTaskComplete(t),
                            ),
                            title: Text(
                              t.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              t.reminderAt != null
                                  ? 'Reminder: ${AppFormatters.dateTime(t.reminderAt!)}'
                                  : (t.dueDate != null
                                      ? 'Due: ${AppFormatters.shortDate(t.dueDate!)}'
                                      : 'Priority: ${t.priority.label}'),
                            ),
                          ),
                        ),
                      ),
              ],
              if (sections.contains('reflection') &&
                  ctrl.reflectionPrompts.isNotEmpty) ...[
                SectionHeader(
                  title: 'Daily Reflection Prompt',
                  actionLabel: 'Journal',
                  onAction: () => widget.onNavigateTab(2),
                ),
                _DailyReflectionCard(controller: ctrl),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickNavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickNavChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _NotePreviewTile extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;

  const _NotePreviewTile({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = AppFormatters.hexToColor(note.colorHex,
        fallback: theme.colorScheme.surface);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            if (note.isPinned) ...[
              Icon(Icons.push_pin, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                note.title.isEmpty ? 'Untitled Note' : note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.plainText.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                note.plainText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              AppFormatters.relativeDate(note.updatedAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyReflectionCard extends StatefulWidget {
  final AppStateController controller;

  const _DailyReflectionCard({required this.controller});

  @override
  State<_DailyReflectionCard> createState() => _DailyReflectionCardState();
}

class _DailyReflectionCardState extends State<_DailyReflectionCard> {
  int _promptIndex = 0;
  final TextEditingController _answerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingAnswer();
  }

  void _loadExistingAnswer() {
    final prompts = widget.controller.reflectionPrompts;
    if (prompts.isEmpty) return;
    final p = prompts[_promptIndex % prompts.length];
    final existing = widget.controller.todayReflections
        .where((r) => r.promptId == p.id)
        .toList();
    _answerCtrl.text = existing.isNotEmpty ? existing.first.answer : '';
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prompts = widget.controller.reflectionPrompts;
    if (prompts.isEmpty) return const SizedBox.shrink();
    final currentPrompt = prompts[_promptIndex % prompts.length];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    currentPrompt.question,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Next prompt',
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {
                      _promptIndex = (_promptIndex + 1) % prompts.length;
                      _loadExistingAnswer();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Write a quick reflection...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () async {
                  await widget.controller.saveDailyReflectionAnswer(
                    currentPrompt,
                    _answerCtrl.text,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reflection saved.')),
                    );
                  }
                },
                child: const Text('Save Reflection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
