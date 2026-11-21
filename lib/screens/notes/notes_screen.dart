import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/app_models.dart';
import '../../services/app_state_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import 'note_editor_screen.dart';

enum NoteBucket { active, archived, trash }

enum NoteSortBy { updatedDesc, createdDesc, titleAsc }

class NotesScreen extends StatefulWidget {
  final AppStateController controller;

  const NotesScreen({super.key, required this.controller});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  NoteBucket _bucket = NoteBucket.active;
  NoteSortBy _sortBy = NoteSortBy.updatedDesc;
  String? _selectedFolderId;
  String? _selectedTagId;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openEditor({NoteModel? note, String initialText = ''}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          controller: widget.controller,
          existingNote: note,
          initialFolderId: _selectedFolderId,
          initialPlainText: initialText,
        ),
      ),
    );
  }

  void _showQuickCaptureDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick Capture'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Jot down a thought immediately...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              final now = DateTime.now();
              final note = NoteModel(
                id: const Uuid().v4(),
                title: text.split('\n').first.takeChars(48),
                plainText: text,
                formattedMarkdown: text,
                folderId: _selectedFolderId,
                createdAt: now,
                updatedAt: now,
              );
              await widget.controller.saveNote(note);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await widget.controller.createFolder(nameCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  List<NoteModel> _filteredNotes() {
    List<NoteModel> base;
    switch (_bucket) {
      case NoteBucket.active:
        base = widget.controller.publicActiveNotes;
        break;
      case NoteBucket.archived:
        base = widget.controller.archivedNotes;
        break;
      case NoteBucket.trash:
        base = widget.controller.trashedNotes;
        break;
    }

    if (_selectedFolderId != null) {
      base = base.where((n) => n.folderId == _selectedFolderId).toList();
    }
    if (_selectedTagId != null) {
      base = base.where((n) => n.tagIds.contains(_selectedTagId)).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      base = base
          .where((n) =>
              n.title.toLowerCase().contains(q) ||
              n.plainText.toLowerCase().contains(q))
          .toList();
    }

    final sorted = List<NoteModel>.from(base);
    switch (_sortBy) {
      case NoteSortBy.updatedDesc:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case NoteSortBy.createdDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case NoteSortBy.titleAsc:
        sorted.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final notes = _filteredNotes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            tooltip: 'Quick Capture',
            icon: const Icon(Icons.bolt),
            onPressed: _showQuickCaptureDialog,
          ),
          IconButton(
            tooltip: 'New Folder',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _showCreateFolderDialog,
          ),
          PopupMenuButton<NoteSortBy>(
            tooltip: 'Sort Notes',
            icon: const Icon(Icons.sort),
            onSelected: (s) => setState(() => _sortBy = s),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: NoteSortBy.updatedDesc,
                  child: Text('Last modified')),
              PopupMenuItem(
                  value: NoteSortBy.createdDesc, child: Text('Date created')),
              PopupMenuItem(value: NoteSortBy.titleAsc, child: Text('Title A-Z')),
            ],
          ),
          if (_bucket == NoteBucket.trash && notes.isNotEmpty)
            IconButton(
              tooltip: 'Empty Recycle Bin',
              icon: const Icon(Icons.delete_forever),
              onPressed: () async {
                await ctrl.emptyTrash();
              },
            ),
        ],
      ),
      floatingActionButton: _bucket == NoteBucket.active
          ? FloatingActionButton(
              onPressed: () => _openEditor(),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search titles and note content...',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Active'),
                  selected: _bucket == NoteBucket.active,
                  onSelected: (_) => setState(() => _bucket = NoteBucket.active),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Archive'),
                  selected: _bucket == NoteBucket.archived,
                  onSelected: (_) =>
                      setState(() => _bucket = NoteBucket.archived),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Recycle Bin'),
                  selected: _bucket == NoteBucket.trash,
                  onSelected: (_) => setState(() => _bucket = NoteBucket.trash),
                ),
                const SizedBox(width: 12),
                ...ctrl.folders.map((f) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        avatar: const Icon(Icons.folder_outlined, size: 16),
                        label: Text(f.name),
                        selected: _selectedFolderId == f.id,
                        onSelected: (sel) => setState(
                            () => _selectedFolderId = sel ? f.id : null),
                      ),
                    )),
                ...ctrl.tags.map((t) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('#${t.name}'),
                        selected: _selectedTagId == t.id,
                        onSelected: (sel) =>
                            setState(() => _selectedTagId = sel ? t.id : null),
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: EmptyStateCard(
                      icon: _bucket == NoteBucket.trash
                          ? Icons.delete_outline
                          : Icons.description_outlined,
                      title: _bucket == NoteBucket.trash
                          ? 'Recycle Bin is empty'
                          : 'No notes here yet',
                      subtitle: _bucket == NoteBucket.trash
                          ? 'Deleted notes stay here until restored or emptied.'
                          : 'Tap + to write a structured note or capture an idea.',
                      buttonLabel:
                          _bucket == NoteBucket.active ? 'New Note' : null,
                      onPressed:
                          _bucket == NoteBucket.active ? () => _openEditor() : null,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                    itemCount: notes.length,
                    itemBuilder: (_, idx) {
                      final note = notes[idx];
                      final bg = AppFormatters.hexToColor(note.colorHex,
                          fallback: Theme.of(context).colorScheme.surface);
                      return Card(
                        color: bg,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => _openEditor(note: note),
                          title: Row(
                            children: [
                              if (note.isPinned) ...[
                                const Icon(Icons.push_pin, size: 15),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  note.title.isEmpty
                                      ? 'Untitled Note'
                                      : note.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (note.plainText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  note.plainText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                'Updated ${AppFormatters.relativeDate(note.updatedAt)}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                          trailing: _bucket == NoteBucket.trash
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Restore',
                                      icon: const Icon(Icons.restore),
                                      onPressed: () => ctrl.restoreNote(note),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Permanently',
                                      icon: const Icon(Icons.delete_forever),
                                      onPressed: () =>
                                          ctrl.permanentlyDeleteNote(note.id),
                                    ),
                                  ],
                                )
                              : PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'pin') {
                                      await ctrl.saveNote(note.copyWith(
                                          isPinned: !note.isPinned));
                                    } else if (action == 'archive') {
                                      await ctrl.saveNote(note.copyWith(
                                          isArchived: !note.isArchived,
                                          isPinned: false));
                                    } else if (action == 'delete') {
                                      await ctrl.softDeleteNote(note);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'pin',
                                      child: Text(
                                          note.isPinned ? 'Unpin' : 'Pin note'),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text(note.isArchived
                                          ? 'Unarchive'
                                          : 'Archive'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Move to Recycle Bin'),
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

extension on String {
  String takeChars(int max) => length <= max ? this : substring(0, max).trim();
}
