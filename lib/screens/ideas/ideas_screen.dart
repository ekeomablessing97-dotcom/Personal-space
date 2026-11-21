import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/app_models.dart';
import '../../models/feature_models.dart';
import '../../services/app_state_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class IdeasScreen extends StatefulWidget {
  final AppStateController controller;

  const IdeasScreen({super.key, required this.controller});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  IdeaCategory? _categoryFilter;
  IdeaStage? _stageFilter;

  List<IdeaModel> _filteredIdeas() {
    return widget.controller.ideas.where((idea) {
      if (_categoryFilter != null && idea.category != _categoryFilter) {
        return false;
      }
      if (_stageFilter != null && idea.stage != _stageFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  void _openIdeaDialog({IdeaModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final tagsCtrl =
        TextEditingController(text: existing?.tags.join(', ') ?? '');
    IdeaCategory category = existing?.category ?? IdeaCategory.inventions;
    IdeaStage stage = existing?.stage ?? IdeaStage.newThought;
    final relatedNoteIds =
        List<String>.from(existing?.relatedNoteIds ?? const []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
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
                    Text(
                      existing == null ? 'New Vault Idea' : 'Develop Idea',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Idea title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Core concept, mechanics, or hypothesis',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<IdeaCategory>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: IdeaCategory.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => category = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<IdeaStage>(
                      initialValue: stage,
                      decoration: const InputDecoration(
                        labelText: 'Development Stage',
                        border: OutlineInputBorder(),
                      ),
                      items: IdeaStage.values
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => stage = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tagsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma separated)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (widget.controller.publicActiveNotes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Related Notes',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: widget.controller.publicActiveNotes
                            .take(10)
                            .map((NoteModel n) {
                          final linked = relatedNoteIds.contains(n.id);
                          return FilterChip(
                            label: Text(
                              n.title.isEmpty ? 'Untitled Note' : n.title,
                            ),
                            selected: linked,
                            onSelected: (sel) {
                              setSheetState(() {
                                if (sel) {
                                  relatedNoteIds.add(n.id);
                                } else {
                                  relatedNoteIds.remove(n.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) return;
                          final tags = tagsCtrl.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                          final now = DateTime.now();
                          final idea = IdeaModel(
                            id: existing?.id ?? const Uuid().v4(),
                            title: title,
                            description: descCtrl.text.trim(),
                            category: category,
                            stage: stage,
                            tags: tags,
                            attachments: existing?.attachments ?? const [],
                            relatedNoteIds: relatedNoteIds,
                            createdAt: existing?.createdAt ?? now,
                            updatedAt: now,
                          );
                          await widget.controller.saveIdea(idea);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Save Idea'),
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

  Future<void> _advanceStage(IdeaModel idea) async {
    final idx = IdeaStage.values.indexOf(idea.stage);
    final next = IdeaStage.values[(idx + 1) % IdeaStage.values.length];
    await widget.controller.saveIdea(
      idea.copyWith(stage: next, updatedAt: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ideas = _filteredIdeas();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Idea Vault'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openIdeaDialog(),
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('New Idea'),
      ),
      body: Column(
        children: [
          // Stage filter bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Stages'),
                  selected: _stageFilter == null,
                  onSelected: (_) => setState(() => _stageFilter = null),
                ),
                const SizedBox(width: 6),
                ...IdeaStage.values.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(s.label),
                        selected: _stageFilter == s,
                        onSelected: (sel) =>
                            setState(() => _stageFilter = sel ? s : null),
                      ),
                    )),
              ],
            ),
          ),
          // Category filter bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Categories'),
                  selected: _categoryFilter == null,
                  onSelected: (_) => setState(() => _categoryFilter = null),
                ),
                const SizedBox(width: 6),
                ...IdeaCategory.values.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(c.label),
                        selected: _categoryFilter == c,
                        onSelected: (sel) =>
                            setState(() => _categoryFilter = sel ? c : null),
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: ideas.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: EmptyStateCard(
                      icon: Icons.lightbulb_outline,
                      title: 'No ideas match this filter',
                      subtitle:
                          'Store inventions, systems, business concepts, or future plans and move them through stages.',
                      buttonLabel: 'Capture Idea',
                      onPressed: () => _openIdeaDialog(),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: ideas.length,
                    itemBuilder: (_, idx) {
                      final idea = ideas[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Chip(
                                    label: Text(idea.category.label),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(idea.stage.label),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Advance Stage',
                                    icon: const Icon(Icons.arrow_forward),
                                    onPressed: () => _advanceStage(idea),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _openIdeaDialog(existing: idea),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        widget.controller.deleteIdea(idea.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                idea.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (idea.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(idea.description),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Created ${AppFormatters.shortDate(idea.createdAt)} • ${idea.relatedNoteIds.length} linked note(s)',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
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
