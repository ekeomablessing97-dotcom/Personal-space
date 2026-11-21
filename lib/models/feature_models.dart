import 'dart:convert';
import 'app_models.dart';

enum IdeaCategory {
  inventions('Inventions'),
  technology('Technology'),
  business('Business'),
  education('Education'),
  creativeProjects('Creative projects'),
  personalDevelopment('Personal development'),
  futurePlans('Future plans'),
  otherIdeas('Other ideas');

  final String label;
  const IdeaCategory(this.label);

  static IdeaCategory fromName(String? name) => IdeaCategory.values.firstWhere(
        (e) => e.name == name || e.label.toLowerCase() == name?.toLowerCase(),
        orElse: () => IdeaCategory.otherIdeas,
      );
}

enum IdeaStage {
  newThought('New Thought'),
  researching('Researching'),
  planning('Planning'),
  inDevelopment('In Development'),
  completed('Completed');

  final String label;
  const IdeaStage(this.label);

  static IdeaStage fromName(String? name) => IdeaStage.values.firstWhere(
        (e) => e.name == name || e.label.toLowerCase() == name?.toLowerCase(),
        orElse: () => IdeaStage.newThought,
      );
}

class IdeaModel {
  final String id;
  final String title;
  final String description;
  final IdeaCategory category;
  final IdeaStage stage;
  final List<String> tags;
  final List<AttachmentItem> attachments;
  final List<String> relatedNoteIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IdeaModel({
    required this.id,
    required this.title,
    required this.description,
    this.category = IdeaCategory.otherIdeas,
    this.stage = IdeaStage.newThought,
    this.tags = const [],
    this.attachments = const [],
    this.relatedNoteIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  IdeaModel copyWith({
    String? id,
    String? title,
    String? description,
    IdeaCategory? category,
    IdeaStage? stage,
    List<String>? tags,
    List<AttachmentItem>? attachments,
    List<String>? relatedNoteIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IdeaModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      stage: stage ?? this.stage,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      relatedNoteIds: relatedNoteIds ?? this.relatedNoteIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>).map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'stage': stage.name,
        'tags_json': jsonEncode(tags),
        'attachments_json': AttachmentItem.encodeList(attachments),
        'related_note_ids_json': jsonEncode(relatedNoteIds),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory IdeaModel.fromMap(Map<String, dynamic> map) => IdeaModel(
        id: map['id'] as String,
        title: (map['title'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        category: IdeaCategory.fromName(map['category'] as String?),
        stage: IdeaStage.fromName(map['stage'] as String?),
        tags: _decodeStringList(map['tags_json'] as String?),
        attachments: AttachmentItem.decodeList(map['attachments_json'] as String?),
        relatedNoteIds: _decodeStringList(map['related_note_ids_json'] as String?),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

enum TaskPriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  urgent('Urgent');

  final String label;
  const TaskPriority(this.label);

  static TaskPriority fromName(String? name) => TaskPriority.values.firstWhere(
        (e) => e.name == name,
        orElse: () => TaskPriority.medium,
      );
}

class ProjectModel {
  final String id;
  final String name;
  final String colorHex;
  final DateTime createdAt;

  const ProjectModel({
    required this.id,
    required this.name,
    this.colorHex = '#2E7D6B',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color_hex': colorHex,
        'created_at': createdAt.toIso8601String(),
      };

  factory ProjectModel.fromMap(Map<String, dynamic> map) => ProjectModel(
        id: map['id'] as String,
        name: map['name'] as String,
        colorHex: (map['color_hex'] as String?) ?? '#2E7D6B',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class ChecklistItemModel {
  final String id;
  final String taskId;
  final String label;
  final bool isChecked;
  final int sortOrder;

  const ChecklistItemModel({
    required this.id,
    required this.taskId,
    required this.label,
    this.isChecked = false,
    this.sortOrder = 0,
  });

  ChecklistItemModel copyWith({
    String? id,
    String? taskId,
    String? label,
    bool? isChecked,
    int? sortOrder,
  }) {
    return ChecklistItemModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      label: label ?? this.label,
      isChecked: isChecked ?? this.isChecked,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'task_id': taskId,
        'label': label,
        'is_checked': isChecked ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory ChecklistItemModel.fromMap(Map<String, dynamic> map) =>
      ChecklistItemModel(
        id: map['id'] as String,
        taskId: map['task_id'] as String,
        label: map['label'] as String,
        isChecked: ((map['is_checked'] as int?) ?? 0) == 1,
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );
}

class TaskModel {
  final String id;
  final String? projectId;
  final String title;
  final String notes;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime? reminderAt;
  final bool isCompleted;
  final DateTime? completedAt;
  final List<ChecklistItemModel> checklist;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.id,
    this.projectId,
    required this.title,
    this.notes = '',
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.reminderAt,
    this.isCompleted = false,
    this.completedAt,
    this.checklist = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  TaskModel copyWith({
    String? id,
    String? projectId,
    bool clearProject = false,
    String? title,
    String? notes,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? reminderAt,
    bool clearReminder = false,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    List<ChecklistItemModel>? checklist,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: clearProject ? null : (projectId ?? this.projectId),
      title: title ?? this.title,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      checklist: checklist ?? this.checklist,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'title': title,
        'notes': notes,
        'priority': priority.name,
        'due_date': dueDate?.toIso8601String(),
        'reminder_at': reminderAt?.toIso8601String(),
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory TaskModel.fromMap(
    Map<String, dynamic> map, {
    List<ChecklistItemModel> checklist = const [],
  }) =>
      TaskModel(
        id: map['id'] as String,
        projectId: map['project_id'] as String?,
        title: map['title'] as String,
        notes: (map['notes'] as String?) ?? '',
        priority: TaskPriority.fromName(map['priority'] as String?),
        dueDate: map['due_date'] != null
            ? DateTime.parse(map['due_date'] as String)
            : null,
        reminderAt: map['reminder_at'] != null
            ? DateTime.parse(map['reminder_at'] as String)
            : null,
        isCompleted: ((map['is_completed'] as int?) ?? 0) == 1,
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
        checklist: checklist,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

class VoiceRecordingModel {
  final String id;
  final String title;
  final String filePath;
  final int durationMs;
  final String? attachedNoteId;
  final DateTime createdAt;

  const VoiceRecordingModel({
    required this.id,
    required this.title,
    required this.filePath,
    required this.durationMs,
    this.attachedNoteId,
    required this.createdAt,
  });

  VoiceRecordingModel copyWith({
    String? id,
    String? title,
    String? filePath,
    int? durationMs,
    String? attachedNoteId,
    bool clearNote = false,
    DateTime? createdAt,
  }) {
    return VoiceRecordingModel(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      durationMs: durationMs ?? this.durationMs,
      attachedNoteId: clearNote ? null : (attachedNoteId ?? this.attachedNoteId),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'file_path': filePath,
        'duration_ms': durationMs,
        'attached_note_id': attachedNoteId,
        'created_at': createdAt.toIso8601String(),
      };

  factory VoiceRecordingModel.fromMap(Map<String, dynamic> map) =>
      VoiceRecordingModel(
        id: map['id'] as String,
        title: map['title'] as String,
        filePath: map['file_path'] as String,
        durationMs: (map['duration_ms'] as int?) ?? 0,
        attachedNoteId: map['attached_note_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class NoteConnectionModel {
  final String id;
  final String sourceType; // 'note' | 'journal' | 'idea' | 'task'
  final String sourceId;
  final String targetType; // 'note' | 'journal' | 'idea' | 'task'
  final String targetId;
  final String label;
  final DateTime createdAt;

  const NoteConnectionModel({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.targetType,
    required this.targetId,
    this.label = 'Related to',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'source_type': sourceType,
        'source_id': sourceId,
        'target_type': targetType,
        'target_id': targetId,
        'label': label,
        'created_at': createdAt.toIso8601String(),
      };

  factory NoteConnectionModel.fromMap(Map<String, dynamic> map) =>
      NoteConnectionModel(
        id: map['id'] as String,
        sourceType: map['source_type'] as String,
        sourceId: map['source_id'] as String,
        targetType: map['target_type'] as String,
        targetId: map['target_id'] as String,
        label: (map['label'] as String?) ?? 'Related to',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class ReflectionPromptModel {
  final String id;
  final String question;
  final bool isCustom;

  const ReflectionPromptModel({
    required this.id,
    required this.question,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'is_custom': isCustom ? 1 : 0,
      };

  factory ReflectionPromptModel.fromMap(Map<String, dynamic> map) =>
      ReflectionPromptModel(
        id: map['id'] as String,
        question: map['question'] as String,
        isCustom: ((map['is_custom'] as int?) ?? 0) == 1,
      );
}

class DailyReflectionModel {
  final String id;
  final String promptId;
  final String questionSnapshot;
  final String answer;
  final String dateKey; // YYYY-MM-DD
  final DateTime updatedAt;

  const DailyReflectionModel({
    required this.id,
    required this.promptId,
    required this.questionSnapshot,
    required this.answer,
    required this.dateKey,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'prompt_id': promptId,
        'question_snapshot': questionSnapshot,
        'answer': answer,
        'date_key': dateKey,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DailyReflectionModel.fromMap(Map<String, dynamic> map) =>
      DailyReflectionModel(
        id: map['id'] as String,
        promptId: map['prompt_id'] as String,
        questionSnapshot: map['question_snapshot'] as String,
        answer: (map['answer'] as String?) ?? '',
        dateKey: map['date_key'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

class BackupRecordModel {
  final String id;
  final String filePath;
  final String actionType; // 'backup' | 'restore' | 'export_pdf' | 'export_txt'
  final int recordCount;
  final DateTime createdAt;

  const BackupRecordModel({
    required this.id,
    required this.filePath,
    required this.actionType,
    required this.recordCount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'file_path': filePath,
        'action_type': actionType,
        'record_count': recordCount,
        'created_at': createdAt.toIso8601String(),
      };

  factory BackupRecordModel.fromMap(Map<String, dynamic> map) =>
      BackupRecordModel(
        id: map['id'] as String,
        filePath: map['file_path'] as String,
        actionType: map['action_type'] as String,
        recordCount: (map['record_count'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
