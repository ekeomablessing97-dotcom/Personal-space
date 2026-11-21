import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/app_models.dart';
import '../models/feature_models.dart';
import '../utils/formatters.dart';

class BackupExportService {
  final AppDatabase _db = AppDatabase.instance;

  Future<Directory> _exportDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'personal_space_exports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Creates a complete local JSON backup file and logs it in backup_history.
  Future<File> createFullBackup({bool shareAfter = false}) async {
    final folders = await _db.getFolders();
    final tags = await _db.getTags();
    final notes = await _db.getNotes();
    final journals = await _db.getJournalEntries();
    final ideas = await _db.getIdeas();
    final projects = await _db.getProjects();
    final tasks = await _db.getTasks();
    final recordings = await _db.getVoiceRecordings();
    final connections = await _db.getConnections();
    final prompts = await _db.getReflectionPrompts();
    final reflections = await _db.getAllReflections();

    final payload = {
      'app': 'PERSONAL SPACE',
      'schema_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'folders': folders.map((e) => e.toMap()).toList(),
      'tags': tags.map((e) => e.toMap()).toList(),
      'notes': notes
          .map((n) => {
                ...n.toMap(),
                'tag_ids': n.tagIds,
              })
          .toList(),
      'journal_entries': journals.map((e) => e.toMap()).toList(),
      'ideas': ideas.map((e) => e.toMap()).toList(),
      'projects': projects.map((e) => e.toMap()).toList(),
      'tasks': tasks
          .map((t) => {
                ...t.toMap(),
                'checklist': t.checklist.map((c) => c.toMap()).toList(),
              })
          .toList(),
      'voice_recordings': recordings.map((e) => e.toMap()).toList(),
      'note_connections': connections.map((e) => e.toMap()).toList(),
      'reflection_prompts': prompts.map((e) => e.toMap()).toList(),
      'daily_reflections': reflections.map((e) => e.toMap()).toList(),
    };

    final dir = await _exportDir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'personal_space_backup_$stamp.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    final count = notes.length + journals.length + ideas.length + tasks.length;
    await _db.insertBackupRecord(
      BackupRecordModel(
        id: const Uuid().v4(),
        filePath: file.path,
        actionType: 'backup',
        recordCount: count,
        createdAt: DateTime.now(),
      ),
    );

    if (shareAfter) {
      await Share.shareXFiles([XFile(file.path)],
          subject: 'PERSONAL SPACE Backup');
    }
    return file;
  }

  /// Picks a JSON backup file and merges records non-destructively (upserting by ID).
  Future<int> restoreFromBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return 0;

    final file = File(result.files.single.path!);
    final raw = await file.readAsString();
    final map = jsonDecode(raw) as Map<String, dynamic>;

    if (map['app'] != 'PERSONAL SPACE') {
      throw const FormatException('Invalid PERSONAL SPACE backup file.');
    }

    int restored = 0;

    for (final f in (map['folders'] as List<dynamic>? ?? [])) {
      await _db.upsertFolder(FolderModel.fromMap(Map<String, dynamic>.from(f)));
      restored++;
    }
    for (final t in (map['tags'] as List<dynamic>? ?? [])) {
      await _db.upsertTag(TagModel.fromMap(Map<String, dynamic>.from(t)));
      restored++;
    }
    for (final n in (map['notes'] as List<dynamic>? ?? [])) {
      final nMap = Map<String, dynamic>.from(n);
      final tagIds = (nMap['tag_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      await _db.upsertNote(NoteModel.fromMap(nMap, tagIds: tagIds));
      restored++;
    }
    for (final j in (map['journal_entries'] as List<dynamic>? ?? [])) {
      await _db.upsertJournalEntry(
          JournalEntryModel.fromMap(Map<String, dynamic>.from(j)));
      restored++;
    }
    for (final i in (map['ideas'] as List<dynamic>? ?? [])) {
      await _db.upsertIdea(IdeaModel.fromMap(Map<String, dynamic>.from(i)));
      restored++;
    }
    for (final pr in (map['projects'] as List<dynamic>? ?? [])) {
      await _db
          .upsertProject(ProjectModel.fromMap(Map<String, dynamic>.from(pr)));
      restored++;
    }
    for (final tk in (map['tasks'] as List<dynamic>? ?? [])) {
      final tMap = Map<String, dynamic>.from(tk);
      final checks = (tMap['checklist'] as List<dynamic>? ?? [])
          .map((c) => ChecklistItemModel.fromMap(Map<String, dynamic>.from(c)))
          .toList();
      await _db.upsertTask(TaskModel.fromMap(tMap, checklist: checks));
      restored++;
    }
    for (final c in (map['note_connections'] as List<dynamic>? ?? [])) {
      await _db.upsertConnection(
          NoteConnectionModel.fromMap(Map<String, dynamic>.from(c)));
      restored++;
    }

    await _db.insertBackupRecord(
      BackupRecordModel(
        id: const Uuid().v4(),
        filePath: file.path,
        actionType: 'restore',
        recordCount: restored,
        createdAt: DateTime.now(),
      ),
    );

    return restored;
  }

  /// Exports notes or journal entries to a clean plain-text (.txt) file.
  Future<File> exportAsText({
    required String fileNamePrefix,
    required String content,
    bool shareAfter = true,
  }) async {
    final dir = await _exportDir();
    final file = File(p.join(
      dir.path,
      '${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.txt',
    ));
    await file.writeAsString(content);

    await _db.insertBackupRecord(
      BackupRecordModel(
        id: const Uuid().v4(),
        filePath: file.path,
        actionType: 'export_txt',
        recordCount: 1,
        createdAt: DateTime.now(),
      ),
    );

    if (shareAfter) {
      await Share.shareXFiles([XFile(file.path)], subject: fileNamePrefix);
    }
    return file;
  }

  /// Exports a note, journal, or collection into a formatted PDF document.
  Future<File> exportAsPdf({
    required String documentTitle,
    required List<({String heading, String meta, String body})> sections,
    bool shareAfter = true,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'PERSONAL SPACE',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            documentTitle,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Exported ${AppFormatters.dateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Divider(height: 24),
          ...sections.expand(
            (s) => [
              pw.Text(
                s.heading,
                style:
                    pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
              ),
              if (s.meta.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2, bottom: 6),
                  child: pw.Text(
                    s.meta,
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey600),
                  ),
                ),
              pw.Text(
                s.body,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4),
              ),
              pw.SizedBox(height: 18),
            ],
          ),
        ],
      ),
    );

    final dir = await _exportDir();
    final file = File(p.join(
      dir.path,
      'personal_space_${DateTime.now().millisecondsSinceEpoch}.pdf',
    ));
    await file.writeAsBytes(await doc.save());

    await _db.insertBackupRecord(
      BackupRecordModel(
        id: const Uuid().v4(),
        filePath: file.path,
        actionType: 'export_pdf',
        recordCount: sections.length,
        createdAt: DateTime.now(),
      ),
    );

    if (shareAfter) {
      await Share.shareXFiles([XFile(file.path)], subject: documentTitle);
    }
    return file;
  }
}
