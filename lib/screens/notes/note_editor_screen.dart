import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/app_models.dart';
import '../../services/app_state_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class NoteEditorScreen extends StatefulWidget {
  final AppStateController controller;
  final NoteModel? existingNote;
  final String? initialFolderId;
  final String initialPlainText;
  final bool forcePrivate;

  const NoteEditorScreen({
    super.key,
    required this.controller,
    this.existingNote,
    this.initialFolderId,
    this.initialPlainText = '',
    this.forcePrivate = false,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final String _noteId;
  late final DateTime _createdAt;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late String _colorHex;
  late String? _folderId;
  late bool _isPinned;
  late bool _isPrivate;
  late List<String> _tagIds;
  late List<AttachmentItem> _attachments;
  Timer? _autoSaveDebounce;
  bool _savingIndicator = false;

  static const List<String> _noteColors = [
    '#FFFFFF',
    '#FFF3E0',
    '#E8F5E9',
    '#E3F2FD',
    '#F3E5F5',
    '#FCE4EC',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingNote;
    _noteId = existing?.id ?? const Uuid().v4();
    _createdAt = existing?.createdAt ?? DateTime.now();
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _bodyCtrl = TextEditingController(
      text: existing?.formattedMarkdown.isNotEmpty == true
          ? existing!.formattedMarkdown
          : widget.initialPlainText,
    );
    _colorHex = existing?.colorHex ?? '#FFFFFF';
    _folderId = existing?.folderId ?? widget.initialFolderId;
    _isPinned = existing?.isPinned ?? false;
    _isPrivate = existing?.isPrivate ?? widget.forcePrivate;
    _tagIds = List<String>.from(existing?.tagIds ?? const []);
    _attachments = List<AttachmentItem>.from(existing?.attachments ?? const []);

    _titleCtrl.addListener(_scheduleAutoSave);
    _bodyCtrl.addListener(_scheduleAutoSave);
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _titleCtrl.removeListener(_scheduleAutoSave);
    _bodyCtrl.removeListener(_scheduleAutoSave);
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 600), () {
      _persistNote(showSpinner: false);
    });
  }

  Future<void> _persistNote({bool showSpinner = true}) async {
    final title = _titleCtrl.text.trim();
    final raw = _bodyCtrl.text;
    final plain = AppFormatters.stripMarkdown(raw);
    if (title.isEmpty && plain.isEmpty && _attachments.isEmpty) return;

    if (showSpinner && mounted) {
      setState(() => _savingIndicator = true);
    }

    final note = NoteModel(
      id: _noteId,
      title: title,
      plainText: plain,
      formattedMarkdown: raw,
      folderId: _folderId,
      colorHex: _colorHex,
      isPinned: _isPinned,
      isArchived: widget.existingNote?.isArchived ?? false,
      isDeleted: widget.existingNote?.isDeleted ?? false,
      isPrivate: _isPrivate,
      tagIds: _tagIds,
      attachments: _attachments,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );

    await widget.controller.saveNote(note);

    if (showSpinner && mounted) {
      setState(() => _savingIndicator = false);
    }
  }

  void _insertFormatting(String prefix, {String suffix = ''}) {
    final text = _bodyCtrl.text;
    final sel = _bodyCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';

    final updated = text.replaceRange(start, end, replacement);
    _bodyCtrl.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(
        offset: start + replacement.length,
      ),
    );
    _scheduleAutoSave();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    final size = await file.exists() ? await file.length() : 0;

    setState(() {
      _attachments.add(AttachmentItem(
        id: const Uuid().v4(),
        name: picked.name,
        path: picked.path,
        kind: 'image',
        sizeBytes: size,
      ));
    });
    await _persistNote();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final pf = result.files.single;

    setState(() {
      _attachments.add(AttachmentItem(
        id: const Uuid().v4(),
        name: pf.name,
        path: pf.path!,
        kind: 'file',
        sizeBytes: pf.size,
      ));
    });
    await _persistNote();
  }

  Future<void> _addTagDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. architecture, research',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final tag = await widget.controller.createOrGetTag(ctrl.text);
              if (!_tagIds.contains(tag.id)) {
                setState(() => _tagIds.add(tag.id));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    await _persistNote();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final bg = AppFormatters.hexToColor(_colorHex,
        fallback: Theme.of(context).colorScheme.scaffoldBackgroundColor);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        _autoSaveDebounce?.cancel();
        await _persistNote(showSpinner: false);
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          title: _savingIndicator
              ? const Text('Saving...', style: TextStyle(fontSize: 14))
              : const Text('Note Editor', style: TextStyle(fontSize: 16)),
          actions: [
            IconButton(
              tooltip: _isPinned ? 'Unpin' : 'Pin Note',
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () async {
                setState(() => _isPinned = !_isPinned);
                await _persistNote();
              },
            ),
            IconButton(
              tooltip: 'Link Related Items',
              icon: const Icon(Icons.link),
              onPressed: () async {
                await _persistNote(showSpinner: false);
                if (!context.mounted) return;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ConnectionSheet(
                    controller: ctrl,
                    sourceType: 'note',
                    sourceId: _noteId,
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Save Now',
              icon: const Icon(Icons.check),
              onPressed: () async {
                await _persistNote();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Folder, privacy, and color bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  DropdownButton<String?>(
                    value: _folderId,
                    hint: const Text('No Folder'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No Folder'),
                      ),
                      ...ctrl.folders.map((f) => DropdownMenuItem<String?>(
                            value: f.id,
                            child: Text(f.name),
                          )),
                    ],
                    onChanged: (v) async {
                      setState(() => _folderId = v);
                      await _persistNote();
                    },
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    avatar: const Icon(Icons.lock_outline, size: 16),
                    label: const Text('Private'),
                    selected: _isPrivate,
                    onSelected: (val) async {
                      setState(() => _isPrivate = val);
                      await _persistNote();
                    },
                  ),
                  const SizedBox(width: 12),
                  ..._noteColors.map((hex) {
                    final c = AppFormatters.hexToColor(hex);
                    final selected = _colorHex == hex;
                    return GestureDetector(
                      onTap: () async {
                        setState(() => _colorHex = hex);
                        await _persistNote();
                      },
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.black87 : Colors.black26,
                            width: selected ? 2.2 : 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                children: [
                  TextField(
                    controller: _titleCtrl,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    decoration: const InputDecoration(
                      hintText: 'Note title...',
                      border: InputBorder.none,
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ..._tagIds.map((tId) {
                        final matches = ctrl.tags.where((t) => t.id == tId);
                        final label =
                            matches.isNotEmpty ? '#${matches.first.name}' : '#tag';
                        return Chip(
                          label: Text(label),
                          onDeleted: () async {
                            setState(() => _tagIds.remove(tId));
                            await _persistNote();
                          },
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('Tag'),
                        onPressed: _addTagDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: null,
                    minLines: 12,
                    style: const TextStyle(height: 1.55, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText:
                          'Start writing... Use the toolbar below for headings, bold, italic, and lists.',
                      border: InputBorder.none,
                    ),
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text(
                      'Attachments (${_attachments.length})',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._attachments.map((att) => Card(
                          child: ListTile(
                            leading: Icon(att.kind == 'image'
                                ? Icons.image_outlined
                                : Icons.attach_file),
                            title: Text(att.name),
                            subtitle: Text('${(att.sizeBytes / 1024).toStringAsFixed(1)} KB'),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () async {
                                setState(() => _attachments
                                    .removeWhere((x) => x.id == att.id));
                                await _persistNote();
                              },
                            ),
                          ),
                        )),
                  ],
                ],
              ),
            ),
            // Formatting & attachment toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Heading',
                      icon: const Icon(Icons.title),
                      onPressed: () => _insertFormatting('## '),
                    ),
                    IconButton(
                      tooltip: 'Bold',
                      icon: const Icon(Icons.format_bold),
                      onPressed: () =>
                          _insertFormatting('**', suffix: '**'),
                    ),
                    IconButton(
                      tooltip: 'Italic',
                      icon: const Icon(Icons.format_italic),
                      onPressed: () => _insertFormatting('*', suffix: '*'),
                    ),
                    IconButton(
                      tooltip: 'Bullet list',
                      icon: const Icon(Icons.format_list_bulleted),
                      onPressed: () => _insertFormatting('- '),
                    ),
                    IconButton(
                      tooltip: 'Numbered list',
                      icon: const Icon(Icons.format_list_numbered),
                      onPressed: () => _insertFormatting('1. '),
                    ),
                    IconButton(
                      tooltip: 'Attach photo',
                      icon: const Icon(Icons.photo_outlined),
                      onPressed: _pickImage,
                    ),
                    IconButton(
                      tooltip: 'Attach file',
                      icon: const Icon(Icons.attach_file),
                      onPressed: _pickFile,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
