import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/app_state_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../notes/note_editor_screen.dart';

class MemoryLaneScreen extends StatelessWidget {
  final AppStateController controller;

  const MemoryLaneScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final memories = controller.getMemoryLaneItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Lane'),
      ),
      body: memories.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyStateCard(
                icon: Icons.history,
                title: 'Memories surface over time',
                subtitle:
                    'As your notes and non-private journal entries age across days, months, and years, they will reappear here. Private entries remain protected.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: memories.length,
              itemBuilder: (_, idx) {
                final item = memories[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(item.label),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppFormatters.fullDate(item.date),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (item.excerpt.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.excerpt,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.kind == 'note') ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                final match = controller.allNotes
                                    .where((n) => n.id == item.id)
                                    .toList();
                                if (match.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoteEditorScreen(
                                        controller: controller,
                                        existingNote: match.first,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Open Note'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
