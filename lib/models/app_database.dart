import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/app_models.dart';
import '../models/feature_models.dart';

class AppDatabase {
  static const String _dbName = 'personal_space.db';
  static const int _dbVersion = 1;

  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_name TEXT NOT NULL DEFAULT 'folder',
        color_hex TEXT NOT NULL DEFAULT '#C85A32',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        color_hex TEXT NOT NULL DEFAULT '#4A6FA5',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        plain_text TEXT NOT NULL DEFAULT '',
        formatted_markdown TEXT NOT NULL DEFAULT '',
        folder_id TEXT,
        color_hex TEXT NOT NULL DEFAULT '#FFFFFF',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_private INTEGER NOT NULL DEFAULT 0,
        attachments_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE note_tags (
        note_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (note_id, tag_id),
        FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        mood TEXT,
        prompt_used TEXT,
        attachments_json TEXT NOT NULL DEFAULT '[]',
        is_private INTEGER NOT NULL DEFAULT 1,
        entry_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ideas (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'otherIdeas',
        stage TEXT NOT NULL DEFAULT 'newThought',
        tags_json TEXT NOT NULL DEFAULT '[]',
        attachments_json TEXT NOT NULL DEFAULT '[]',
        related_note_ids_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color_hex TEXT NOT NULL DEFAULT '#2E7D6B',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        project_id TEXT,
        title TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        priority TEXT NOT NULL DEFAULT 'medium',
        due_date TEXT,
        reminder_at TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE checklist_items (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        label TEXT NOT NULL,
        is_checked INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE voice_recordings (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        attached_note_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (attached_note_id) REFERENCES notes (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE note_connections (
        id TEXT PRIMARY KEY,
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        target_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        label TEXT NOT NULL DEFAULT 'Related to',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reflection_prompts (
        id TEXT PRIMARY KEY,
        question TEXT NOT NULL,
        is_custom INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_reflections (
        id TEXT PRIMARY KEY,
        prompt_id TEXT NOT NULL,
        question_snapshot TEXT NOT NULL,
        answer TEXT NOT NULL DEFAULT '',
        date_key TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE backup_history (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        action_type TEXT NOT NULL,
        record_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_notes_updated ON notes(updated_at DESC)');
    await db.execute('CREATE INDEX idx_notes_flags ON notes(is_deleted, is_archived, is_private)');
    await db.execute('CREATE INDEX idx_journal_date ON journal_entries(entry_date DESC)');
    await db.execute('CREATE INDEX idx_tasks_due ON tasks(is_completed, due_date)');
    await db.execute('CREATE INDEX idx_connections_src ON note_connections(source_type, source_id)');

    await _seedDefaultPrompts(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await _createSchema(db, newVersion);
    }
  }

  Future<void> _seedDefaultPrompts(Database db) async {
    final defaults = [
      ('prompt_1', 'What did I learn today?'),
      ('prompt_2', 'What did I accomplish?'),
      ('prompt_3', 'What new idea did I develop?'),
      ('prompt_4', 'What would I like to improve?'),
      ('prompt_5', 'What do I want to remember?'),
    ];
    for (final item in defaults) {
      await db.insert(
        'reflection_prompts',
        {'id': item.$1, 'question': item.$2, 'is_custom': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // --- FOLDERS & TAGS ---
  Future<List<FolderModel>> getFolders() async {
    final db = await database;
    final rows = await db.query('folders', orderBy: 'sort_order ASC, name ASC');
    return rows.map(FolderModel.fromMap).toList();
  }

  Future<void> upsertFolder(FolderModel folder) async {
    final db = await database;
    await db.insert('folders', folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteFolder(String id) async {
    final db = await database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TagModel>> getTags() async {
    final db = await database;
    final rows = await db.query('tags', orderBy: 'name ASC');
    return rows.map(TagModel.fromMap).toList();
  }

  Future<void> upsertTag(TagModel tag) async {
    final db = await database;
    await db.insert('tags', tag.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTag(String id) async {
    final db = await database;
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  // --- NOTES ---
  Future<List<NoteModel>> getNotes({
    String orderBy = 'updated_at DESC',
  }) async {
    final db = await database;
    final rows = await db.query('notes', orderBy: orderBy);
    final tagRows = await db.query('note_tags');

    final Map<String, List<String>> noteTagMap = {};
    for (final tr in tagRows) {
      final nId = tr['note_id'] as String;
      final tId = tr['tag_id'] as String;
      noteTagMap.putIfAbsent(nId, () => []).add(tId);
    }

    return rows
        .map((r) => NoteModel.fromMap(r, tagIds: noteTagMap[r['id']] ?? const []))
        .toList();
  }

  Future<void> upsertNote(NoteModel note) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'notes',
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('note_tags', where: 'note_id = ?', whereArgs: [note.id]);
      for (final tagId in note.tagIds) {
        await txn.insert(
          'note_tags',
          {'note_id': note.id, 'tag_id': tagId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<void> permanentlyDeleteNote(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> emptyTrash() async {
    final db = await database;
    await db.delete('notes', where: 'is_deleted = 1');
  }

  // --- JOURNAL ---
  Future<List<JournalEntryModel>> getJournalEntries() async {
    final db = await database;
    final rows =
        await db.query('journal_entries', orderBy: 'entry_date DESC, created_at DESC');
    return rows.map(JournalEntryModel.fromMap).toList();
  }

  Future<void> upsertJournalEntry(JournalEntryModel entry) async {
    final db = await database;
    await db.insert('journal_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteJournalEntry(String id) async {
    final db = await database;
    await db.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
  }

  // --- IDEAS ---
  Future<List<IdeaModel>> getIdeas() async {
    final db = await database;
    final rows = await db.query('ideas', orderBy: 'updated_at DESC');
    return rows.map(IdeaModel.fromMap).toList();
  }

  Future<void> upsertIdea(IdeaModel idea) async {
    final db = await database;
    await db.insert('ideas', idea.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteIdea(String id) async {
    final db = await database;
    await db.delete('ideas', where: 'id = ?', whereArgs: [id]);
  }

  // --- PROJECTS & TASKS ---
  Future<List<ProjectModel>> getProjects() async {
    final db = await database;
    final rows = await db.query('projects', orderBy: 'name ASC');
    return rows.map(ProjectModel.fromMap).toList();
  }

  Future<void> upsertProject(ProjectModel project) async {
    final db = await database;
    await db.insert('projects', project.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TaskModel>> getTasks() async {
    final db = await database;
    final taskRows =
        await db.query('tasks', orderBy: 'is_completed ASC, due_date ASC, created_at DESC');
    final checkRows =
        await db.query('checklist_items', orderBy: 'sort_order ASC');

    final Map<String, List<ChecklistItemModel>> checkMap = {};
    for (final cr in checkRows) {
      final item = ChecklistItemModel.fromMap(cr);
      checkMap.putIfAbsent(item.taskId, () => []).add(item);
    }

    return taskRows
        .map((r) => TaskModel.fromMap(r, checklist: checkMap[r['id']] ?? const []))
        .toList();
  }

  Future<void> upsertTask(TaskModel task) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'checklist_items',
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      for (int i = 0; i < task.checklist.length; i++) {
        final item = task.checklist[i].copyWith(taskId: task.id, sortOrder: i);
        await txn.insert(
          'checklist_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // --- VOICE RECORDINGS ---
  Future<List<VoiceRecordingModel>> getVoiceRecordings() async {
    final db = await database;
    final rows =
        await db.query('voice_recordings', orderBy: 'created_at DESC');
    return rows.map(VoiceRecordingModel.fromMap).toList();
  }

  Future<void> upsertVoiceRecording(VoiceRecordingModel rec) async {
    final db = await database;
    await db.insert('voice_recordings', rec.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteVoiceRecording(String id) async {
    final db = await database;
    await db.delete('voice_recordings', where: 'id = ?', whereArgs: [id]);
  }

  // --- CONNECTIONS ---
  Future<List<NoteConnectionModel>> getConnections() async {
    final db = await database;
    final rows =
        await db.query('note_connections', orderBy: 'created_at DESC');
    return rows.map(NoteConnectionModel.fromMap).toList();
  }

  Future<void> upsertConnection(NoteConnectionModel conn) async {
    final db = await database;
    await db.insert('note_connections', conn.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteConnection(String id) async {
    final db = await database;
    await db.delete('note_connections', where: 'id = ?', whereArgs: [id]);
  }

  // --- REFLECTIONS ---
  Future<List<ReflectionPromptModel>> getReflectionPrompts() async {
    final db = await database;
    final rows = await db.query('reflection_prompts', orderBy: 'is_custom ASC, id ASC');
    return rows.map(ReflectionPromptModel.fromMap).toList();
  }

  Future<void> upsertReflectionPrompt(ReflectionPromptModel prompt) async {
    final db = await database;
    await db.insert('reflection_prompts', prompt.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DailyReflectionModel>> getReflectionsForDate(String dateKey) async {
    final db = await database;
    final rows = await db.query(
      'daily_reflections',
      where: 'date_key = ?',
      whereArgs: [dateKey],
    );
    return rows.map(DailyReflectionModel.fromMap).toList();
  }

  Future<List<DailyReflectionModel>> getAllReflections() async {
    final db = await database;
    final rows =
        await db.query('daily_reflections', orderBy: 'date_key DESC');
    return rows.map(DailyReflectionModel.fromMap).toList();
  }

  Future<void> upsertDailyReflection(DailyReflectionModel reflection) async {
    final db = await database;
    await db.insert('daily_reflections', reflection.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- BACKUP HISTORY ---
  Future<List<BackupRecordModel>> getBackupHistory() async {
    final db = await database;
    final rows =
        await db.query('backup_history', orderBy: 'created_at DESC');
    return rows.map(BackupRecordModel.fromMap).toList();
  }

  Future<void> insertBackupRecord(BackupRecordModel record) async {
    final db = await database;
    await db.insert('backup_history', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
