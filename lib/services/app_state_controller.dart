import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/app_models.dart';
import '../models/feature_models.dart';
import '../utils/formatters.dart';
import 'auth_security_service.dart';
import 'backup_export_service.dart';
import 'notification_service.dart';
import 'voice_recorder_service.dart';

class AppStateController extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;
  final AuthSecurityService authService = AuthSecurityService();
  final VoiceRecorderService voiceService = VoiceRecorderService();
  final BackupExportService backupService = BackupExportService();

  bool _isLoading = true;
  AppSettingsModel _settings = const AppSettingsModel();

  List<FolderModel> _folders = [];
  List<TagModel> _tags = [];
  List<NoteModel> _notes = [];
  List<JournalEntryModel> _journalEntries = [];
  List<IdeaModel> _ideas = [];
  List<ProjectModel> _projects = [];
  List<TaskModel> _tasks = [];
  List<VoiceRecordingModel> _voiceRecordings = [];
  List<NoteConnectionModel> _connections = [];
  List<ReflectionPromptModel> _reflectionPrompts = [];
  List<DailyReflectionModel> _todayReflections = [];
  List<BackupRecordModel> _backupHistory = [];

  bool get isLoading => _isLoading;
  AppSettingsModel get settings => _settings;
  List<FolderModel> get folders => _folders;
  List<TagModel> get tags => _tags;
  List<NoteModel> get allNotes => _notes;
  List<JournalEntryModel> get journalEntries => _journalEntries;
  List<IdeaModel> get ideas => _ideas;
  List<ProjectModel> get projects => _projects;
  List<TaskModel> get tasks => _tasks;
  List<VoiceRecordingModel> get voiceRecordings => _voiceRecordings;
  List<NoteConnectionModel> get connections => _connections;
  List<ReflectionPromptModel> get reflectionPrompts => _reflectionPrompts;
  List<DailyReflectionModel> get todayReflections => _todayReflections;
  List<BackupRecordModel> get backupHistory => _backupHistory;

  // Filtered convenience getters
  List<NoteModel> get publicActiveNotes => _notes
      .where((n) => !n.isDeleted && !n.isArchived && !n.isPrivate)
      .toList();

  List<NoteModel> get pinnedNotes =>
      publicActiveNotes.where((n) => n.isPinned).toList();

  List<NoteModel> get archivedNotes =>
      _notes.where((n) => !n.isDeleted && n.isArchived && !n.isPrivate).toList();

  List<NoteModel> get trashedNotes =>
      _notes.where((n) => n.isDeleted && !n.isPrivate).toList();

  List<NoteModel> get privateNotes =>
      _notes.where((n) => !n.isDeleted && n.isPrivate).toList();

  List<JournalEntryModel> get privateJournalEntries =>
      _journalEntries.where((j) => j.isPrivate).toList();

  List<TaskModel> get upcomingTasks =>
      _tasks.where((t) => !t.isCompleted).toList();

  List<TaskModel> get completedTasks =>
      _tasks.where((t) => t.isCompleted).toList();

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await authService.initialize();
    await NotificationService.instance.initialize();
    await _loadSettings();
    await refreshAll();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = AppSettingsModel(
      userName: prefs.getString('ps_user_name') ?? 'Friend',
      themeMode: prefs.getString('ps_theme_mode') ?? 'system',
      accentHex: prefs.getString('ps_accent_hex') ?? '#C85A32',
      textScale: prefs.getDouble('ps_text_scale') ?? 1.0,
      autoLockSeconds: prefs.getInt('ps_auto_lock') ?? 60,
      biometricsEnabled: prefs.getBool('ps_biometrics') ?? true,
      homeSections: prefs.getStringList('ps_home_sections') ??
          const [
            'greeting',
            'quick_actions',
            'stats',
            'pinned_notes',
            'recent_notes',
            'upcoming_tasks',
            'reflection',
          ],
    );
  }

  Future<void> updateSettings(AppSettingsModel updated) async {
    _settings = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ps_user_name', updated.userName);
    await prefs.setString('ps_theme_mode', updated.themeMode);
    await prefs.setString('ps_accent_hex', updated.accentHex);
    await prefs.setDouble('ps_text_scale', updated.textScale);
    await prefs.setInt('ps_auto_lock', updated.autoLockSeconds);
    await prefs.setBool('ps_biometrics', updated.biometricsEnabled);
    await prefs.setStringList('ps_home_sections', updated.homeSections);
    notifyListeners();
  }

  Future<void> refreshAll() async {
    final todayKey = AppFormatters.dateKey(DateTime.now());
    _folders = await _db.getFolders();
    _tags = await _db.getTags();
    _notes = await _db.getNotes();
    _journalEntries = await _db.getJournalEntries();
    _ideas = await _db.getIdeas();
    _projects = await _db.getProjects();
    _tasks = await _db.getTasks();
    _voiceRecordings = await _db.getVoiceRecordings();
    _connections = await _db.getConnections();
    _reflectionPrompts = await _db.getReflectionPrompts();
    _todayReflections = await _db.getReflectionsForDate(todayKey);
    _backupHistory = await _db.getBackupHistory();
    notifyListeners();
  }

  // --- FOLDERS & TAGS ---
  Future<FolderModel> createFolder(String name, {String colorHex = '#C85A32'}) async {
    final folder = FolderModel(
      id: const Uuid().v4(),
      name: name.trim(),
      colorHex: colorHex,
      sortOrder: _folders.length,
      createdAt: DateTime.now(),
    );
    await _db.upsertFolder(folder);
    _folders = await _db.getFolders();
    notifyListeners();
    return folder;
  }

  Future<void> deleteFolder(String id) async {
    await _db.deleteFolder(id);
    _folders = await _db.getFolders();
    _notes = await _db.getNotes();
    notifyListeners();
  }

  Future<TagModel> createOrGetTag(String name, {String colorHex = '#4A6FA5'}) async {
    final clean = name.trim();
    final existing = _tags.where((t) => t.name.toLowerCase() == clean.toLowerCase());
    if (existing.isNotEmpty) return existing.first;

    final tag = TagModel(
      id: const Uuid().v4(),
      name: clean,
      colorHex: colorHex,
      createdAt: DateTime.now(),
    );
    await _db.upsertTag(tag);
    _tags = await _db.getTags();
    notifyListeners();
    return tag;
  }

  // --- NOTES ---
  Future<void> saveNote(NoteModel note) async {
    await _db.upsertNote(note);
    _notes = await _db.getNotes();
    notifyListeners();
  }

  Future<void> softDeleteNote(NoteModel note) async {
    await saveNote(note.copyWith(
      isDeleted: true,
      isPinned: false,
      deletedAt: DateTime.now(),
    ));
  }

  Future<void> restoreNote(NoteModel note) async {
    await saveNote(note.copyWith(
      isDeleted: false,
      clearDeletedAt: true,
    ));
  }

  Future<void> permanentlyDeleteNote(String id) async {
    await _db.permanentlyDeleteNote(id);
    _notes = await _db.getNotes();
    notifyListeners();
  }

  Future<void> emptyTrash() async {
    await _db.emptyTrash();
    _notes = await _db.getNotes();
    notifyListeners();
  }

  // --- JOURNAL ---
  Future<void> saveJournalEntry(JournalEntryModel entry) async {
    await _db.upsertJournalEntry(entry);
    _journalEntries = await _db.getJournalEntries();
    notifyListeners();
  }

  Future<void> deleteJournalEntry(String id) async {
    await _db.deleteJournalEntry(id);
    _journalEntries = await _db.getJournalEntries();
    notifyListeners();
  }

  // --- IDEAS ---
  Future<void> saveIdea(IdeaModel idea) async {
    await _db.upsertIdea(idea);
    _ideas = await _db.getIdeas();
    notifyListeners();
  }

  Future<void> deleteIdea(String id) async {
    await _db.deleteIdea(id);
    _ideas = await _db.getIdeas();
    notifyListeners();
  }

  // --- PROJECTS & TASKS ---
  Future<ProjectModel> createProject(String name, {String colorHex = '#2E7D6B'}) async {
    final project = ProjectModel(
      id: const Uuid().v4(),
      name: name.trim(),
      colorHex: colorHex,
      createdAt: DateTime.now(),
    );
    await _db.upsertProject(project);
    _projects = await _db.getProjects();
    notifyListeners();
    return project;
  }

  Future<void> saveTask(TaskModel task) async {
    await _db.upsertTask(task);
    if (task.reminderAt != null && !task.isCompleted) {
      await NotificationService.instance.scheduleTaskReminder(
        taskId: task.id,
        taskTitle: task.title,
        scheduledAt: task.reminderAt!,
      );
    } else {
      await NotificationService.instance.cancelReminder(task.id);
    }
    _tasks = await _db.getTasks();
    notifyListeners();
  }

  Future<void> toggleTaskComplete(TaskModel task) async {
    final completed = !task.isCompleted;
    await saveTask(task.copyWith(
      isCompleted: completed,
      completedAt: completed ? DateTime.now() : null,
      clearCompletedAt: !completed,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> deleteTask(String id) async {
    await NotificationService.instance.cancelReminder(id);
    await _db.deleteTask(id);
    _tasks = await _db.getTasks();
    notifyListeners();
  }

  // --- VOICE RECORDINGS ---
  Future<void> saveVoiceRecording(VoiceRecordingModel recording) async {
    await _db.upsertVoiceRecording(recording);
    _voiceRecordings = await _db.getVoiceRecordings();
    notifyListeners();
  }

  Future<void> deleteVoiceRecording(String id) async {
    await _db.deleteVoiceRecording(id);
    _voiceRecordings = await _db.getVoiceRecordings();
    notifyListeners();
  }

  // --- NOTE CONNECTIONS ---
  Future<void> addConnection({
    required String sourceType,
    required String sourceId,
    required String targetType,
    required String targetId,
    String label = 'Related to',
  }) async {
    final conn = NoteConnectionModel(
      id: const Uuid().v4(),
      sourceType: sourceType,
      sourceId: sourceId,
      targetType: targetType,
      targetId: targetId,
      label: label,
      createdAt: DateTime.now(),
    );
    await _db.upsertConnection(conn);
    _connections = await _db.getConnections();
    notifyListeners();
  }

  Future<void> removeConnection(String id) async {
    await _db.deleteConnection(id);
    _connections = await _db.getConnections();
    notifyListeners();
  }

  List<NoteConnectionModel> connectionsFor(String type, String id) {
    return _connections
        .where((c) =>
            (c.sourceType == type && c.sourceId == id) ||
            (c.targetType == type && c.targetId == id))
        .toList();
  }

  // --- DAILY REFLECTIONS ---
  Future<void> addCustomReflectionPrompt(String question) async {
    final prompt = ReflectionPromptModel(
      id: const Uuid().v4(),
      question: question.trim(),
      isCustom: true,
    );
    await _db.upsertReflectionPrompt(prompt);
    _reflectionPrompts = await _db.getReflectionPrompts();
    notifyListeners();
  }

  Future<void> saveDailyReflectionAnswer(
    ReflectionPromptModel prompt,
    String answer,
  ) async {
    final todayKey = AppFormatters.dateKey(DateTime.now());
    final existing = _todayReflections.where((r) => r.promptId == prompt.id);
    final entry = DailyReflectionModel(
      id: existing.isNotEmpty ? existing.first.id : const Uuid().v4(),
      promptId: prompt.id,
      questionSnapshot: prompt.question,
      answer: answer.trim(),
      dateKey: todayKey,
      updatedAt: DateTime.now(),
    );
    await _db.upsertDailyReflection(entry);
    _todayReflections = await _db.getReflectionsForDate(todayKey);
    notifyListeners();
  }

  // --- MEMORY LANE ---
  List<({String label, DateTime date, String title, String excerpt, String kind, String id})>
      getMemoryLaneItems() {
    final now = DateTime.now();
    final results = <({
      String label,
      DateTime date,
      String title,
      String excerpt,
      String kind,
      String id
    })>[];

    String? matchWindow(DateTime created) {
      final days = now.difference(created).inDays;
      if (days >= 28 && days <= 33) return '1 month ago';
      if (days >= 88 && days <= 95) return '3 months ago';
      if (days >= 178 && days <= 186) return '6 months ago';
      if (days >= 362 && days <= 368 && created.year < now.year) {
        final years = now.year - created.year;
        return '$years year${years > 1 ? 's' : ''} ago on this day';
      }
      if (days >= 7) return '$days days ago';
      return null;
    }

    // Respect private-note settings: only include non-private notes
    for (final note in publicActiveNotes) {
      final label = matchWindow(note.createdAt);
      if (label != null) {
        results.add((
          label: label,
          date: note.createdAt,
          title: note.title.isEmpty ? 'Untitled Note' : note.title,
          excerpt: note.plainText,
          kind: 'note',
          id: note.id,
        ));
      }
    }

    // Only include non-private journal entries in public Memory Lane
    for (final j in _journalEntries.where((e) => !e.isPrivate)) {
      final label = matchWindow(j.entryDate);
      if (label != null) {
        results.add((
          label: label,
          date: j.entryDate,
          title: j.title.isEmpty ? 'Journal Entry' : j.title,
          excerpt: j.body,
          kind: 'journal',
          id: j.id,
        ));
      }
    }

    results.sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  // --- STATISTICS ---
  Map<String, int> getWeeklyActivityCounts() {
    final now = DateTime.now();
    final Map<String, int> counts = {};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = AppFormatters.dateKey(day);
      final noteCount =
          _notes.where((n) => AppFormatters.dateKey(n.createdAt) == key).length;
      final journalCount = _journalEntries
          .where((j) => AppFormatters.dateKey(j.entryDate) == key)
          .length;
      final ideaCount =
          _ideas.where((id) => AppFormatters.dateKey(id.createdAt) == key).length;
      counts[key] = noteCount + journalCount + ideaCount;
    }
    return counts;
  }
}
