import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/app_models.dart';
import '../../services/app_state_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class JournalScreen extends StatefulWidget {
  final AppStateController controller;

  const JournalScreen({super.key, required this.controller});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  bool _calendarMode = false;
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<String> _moods = [
    'Calm',
    'Focused',
    'Grateful',
    'Energized',
    'Reflective',
    'Tired',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<JournalEntryModel> _visibleEntries() {
    // Only show unlocked private entries or non-private entries in main journal list
    final unlocked = widget.controller.authService.isUnlocked;
    var items = widget.controller.journalEntries
        .where((e) => !e.isPrivate || unlocked)
        .toList();

    if (_calendarMode) {
      final selKey = AppFormatters.dateKey(_selectedDate);
      items = items
          .where((e) => AppFormatters.dateKey(e.entryDate) == selKey)
          .toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((e) =>
              e.title.toLowerCase().contains(q) ||
              e.body.toLowerCase().contains(q) ||
              (e.mood?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return items;
  }

  void _openEntryEditor({JournalEntryModel? existing}) {
    final prompts = widget.controller.reflectionPrompts;
    final defaultPrompt =
        prompts.isNotEmpty ? prompts.first.question : 'What stood out today?';

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    String? mood = existing?.mood;
    String? promptUsed = existing?.promptUsed;
    bool isPrivate = existing?.isPrivate ?? true;
    DateTime entryDate = existing?.entryDate ?? _selectedDate;
    final attachments =
        List<AttachmentItem>.from(existing?.attachments ?? const []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> pickPhoto() async {
              final picker = ImagePicker();
              final img = await picker.pickImage(source: ImageSource.gallery);
              if (img == null) return;
              final f = File(img.path);
              final bytes = await f.exists() ? await f.length() : 0;
              setSheetState(() {
                attachments.add(AttachmentItem(
                  id: const Uuid().v4(),
                  name: img.name,
                  path: img.path,
                  kind: 'image',
                  sizeBytes: bytes,
                ));
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            existing == null
                                ? 'New Journal Entry'
                                : 'Edit Journal Entry',
                            style: Theme.of(ctx)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: entryDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                entryDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  entryDate.hour,
                                  entryDate.minute,
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(AppFormatters.shortDate(entryDate)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ActionChip(
                      avatar: const Icon(Icons.auto_awesome, size: 16),
                      label: Text(promptUsed == null
                          ? 'Use Daily Prompt'
                          : 'Prompt: $promptUsed'),
                      onPressed: () {
                        if (prompts.isEmpty) return;
                        final currentIdx = prompts
                            .indexWhere((p) => p.question == promptUsed);
                        final next =
                            prompts[(currentIdx + 1) % prompts.length];
                        setSheetState(() {
                          promptUsed = next.question;
                          if (bodyCtrl.text.trim().isEmpty) {
                            bodyCtrl.text = '${next.question}\n';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Entry headline (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: defaultPrompt,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _moods.map((m) {
                          final active = mood == m;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(m),
                              selected: active,
                              onSelected: (sel) =>
                                  setSheetState(() => mood = sel ? m : null),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: pickPhoto,
                          icon: const Icon(Icons.photo_outlined),
                          label: Text('Photos (${attachments.length})'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Private entry'),
                            value: isPrivate,
                            onChanged: (v) =>
                                setSheetState(() => isPrivate = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final body = bodyCtrl.text.trim();
                          final title = titleCtrl.text.trim();
                          if (body.isEmpty && title.isEmpty) return;
                          final now = DateTime.now();
                          final entry = JournalEntryModel(
                            id: existing?.id ?? const Uuid().v4(),
                            title: title,
                            body: body,
                            mood: mood,
                            promptUsed: promptUsed,
                            attachments: attachments,
                            isPrivate: isPrivate,
                            entryDate: entryDate,
                            createdAt: existing?.createdAt ?? now,
                            updatedAt: now,
                          );
                          await widget.controller.saveJournalEntry(entry);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Save Entry'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _visibleEntries();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Journal'),
        actions: [
          IconButton(
            tooltip: _calendarMode ? 'Switch to List View' : 'Calendar Filter',
            icon: Icon(_calendarMode ? Icons.view_agenda_outlined : Icons.calendar_month),
            onPressed: () => setState(() => _calendarMode = !_calendarMode),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntryEditor(),
        icon: const Icon(Icons.book),
        label: const Text('Write Entry'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search journal entries or moods...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          if (_calendarMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text('Date: ${AppFormatters.fullDate(_selectedDate)}'),
                  subtitle: const Text('Tap to pick another journal date'),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                ),
              ),
            ),
          Expanded(
            child: entries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: EmptyStateCard(
                      icon: Icons.auto_stories_outlined,
                      title: 'No journal entries yet',
                      subtitle:
                          'Entries are private by default and stored locally on your device.',
                      buttonLabel: 'First Entry',
                      onPressed: () => _openEntryEditor(),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: entries.length,
                    itemBuilder: (_, idx) {
                      final entry = entries[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => _openEntryEditor(existing: entry),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.title.isEmpty
                                      ? AppFormatters.fullDate(entry.entryDate)
                                      : entry.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (entry.isPrivate)
                                const Icon(Icons.lock_outline, size: 16),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                entry.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Text(
                                    AppFormatters.dateTime(entry.entryDate),
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                  if (entry.mood != null)
                                    Text(
                                      'Mood: ${entry.mood}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  if (entry.attachments.isNotEmpty)
                                    Text(
                                      '${entry.attachments.length} photo(s)',
                                      style:
                                          Theme.of(context).textTheme.labelSmall,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete entry',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                widget.controller.deleteJournalEntry(entry.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
