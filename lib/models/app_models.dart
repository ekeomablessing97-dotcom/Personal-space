import 'dart:convert';

class FolderModel {
  final String id;
  final String name;
  final String iconName;
  final String colorHex;
  final int sortOrder;
  final DateTime createdAt;

  const FolderModel({
    required this.id,
    required this.name,
    this.iconName = 'folder',
    this.colorHex = '#C85A32',
    this.sortOrder = 0,
    required this.createdAt,
  });

  FolderModel copyWith({
    String? id,
    String? name,
    String? iconName,
    String? colorHex,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon_name': iconName,
        'color_hex': colorHex,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory FolderModel.fromMap(Map<String, dynamic> map) => FolderModel(
        id: map['id'] as String,
        name: map['name'] as String,
        iconName: (map['icon_name'] as String?) ?? 'folder',
        colorHex: (map['color_hex'] as String?) ?? '#C85A32',
        sortOrder: (map['sort_order'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class TagModel {
  final String id;
  final String name;
  final String colorHex;
  final DateTime createdAt;

  const TagModel({
    required this.id,
    required this.name,
    this.colorHex = '#4A6FA5',
    required this.createdAt,
  });

  TagModel copyWith({
    String? id,
    String? name,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return TagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color_hex': colorHex,
        'created_at': createdAt.toIso8601String(),
      };

  factory TagModel.fromMap(Map<String, dynamic> map) => TagModel(
        id: map['id'] as String,
        name: map['name'] as String,
        colorHex: (map['color_hex'] as String?) ?? '#4A6FA5',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class AttachmentItem {
  final String id;
  final String name;
  final String path;
  final String kind; // 'image' | 'file' | 'audio'
  final int sizeBytes;

  const AttachmentItem({
    required this.id,
    required this.name,
    required this.path,
    required this.kind,
    this.sizeBytes = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'path': path,
        'kind': kind,
        'size_bytes': sizeBytes,
      };

  factory AttachmentItem.fromMap(Map<String, dynamic> map) => AttachmentItem(
        id: map['id'] as String,
        name: map['name'] as String,
        path: map['path'] as String,
        kind: (map['kind'] as String?) ?? 'file',
        sizeBytes: (map['size_bytes'] as int?) ?? 0,
      );

  static String encodeList(List<AttachmentItem> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList());

  static List<AttachmentItem> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => AttachmentItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

class NoteModel {
  final String id;
  final String title;
  final String plainText;
  final String formattedMarkdown;
  final String? folderId;
  final String colorHex;
  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;
  final bool isPrivate;
  final List<String> tagIds;
  final List<AttachmentItem> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const NoteModel({
    required this.id,
    required this.title,
    required this.plainText,
    required this.formattedMarkdown,
    this.folderId,
    this.colorHex = '#FFFFFF',
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.isPrivate = false,
    this.tagIds = const [],
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  NoteModel copyWith({
    String? id,
    String? title,
    String? plainText,
    String? formattedMarkdown,
    String? folderId,
    bool clearFolder = false,
    String? colorHex,
    bool? isPinned,
    bool? isArchived,
    bool? isDeleted,
    bool? isPrivate,
    List<String>? tagIds,
    List<AttachmentItem>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      plainText: plainText ?? this.plainText,
      formattedMarkdown: formattedMarkdown ?? this.formattedMarkdown,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      colorHex: colorHex ?? this.colorHex,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      isPrivate: isPrivate ?? this.isPrivate,
      tagIds: tagIds ?? this.tagIds,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'plain_text': plainText,
        'formatted_markdown': formattedMarkdown,
        'folder_id': folderId,
        'color_hex': colorHex,
        'is_pinned': isPinned ? 1 : 0,
        'is_archived': isArchived ? 1 : 0,
        'is_deleted': isDeleted ? 1 : 0,
        'is_private': isPrivate ? 1 : 0,
        'attachments_json': AttachmentItem.encodeList(attachments),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };

  factory NoteModel.fromMap(
    Map<String, dynamic> map, {
    List<String> tagIds = const [],
  }) {
    return NoteModel(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      plainText: (map['plain_text'] as String?) ?? '',
      formattedMarkdown: (map['formatted_markdown'] as String?) ?? '',
      folderId: map['folder_id'] as String?,
      colorHex: (map['color_hex'] as String?) ?? '#FFFFFF',
      isPinned: ((map['is_pinned'] as int?) ?? 0) == 1,
      isArchived: ((map['is_archived'] as int?) ?? 0) == 1,
      isDeleted: ((map['is_deleted'] as int?) ?? 0) == 1,
      isPrivate: ((map['is_private'] as int?) ?? 0) == 1,
      tagIds: tagIds,
      attachments: AttachmentItem.decodeList(map['attachments_json'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
    );
  }
}

class JournalEntryModel {
  final String id;
  final String title;
  final String body;
  final String? mood;
  final String? promptUsed;
  final List<AttachmentItem> attachments;
  final bool isPrivate;
  final DateTime entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntryModel({
    required this.id,
    required this.title,
    required this.body,
    this.mood,
    this.promptUsed,
    this.attachments = const [],
    this.isPrivate = true,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  JournalEntryModel copyWith({
    String? id,
    String? title,
    String? body,
    String? mood,
    bool clearMood = false,
    String? promptUsed,
    List<AttachmentItem>? attachments,
    bool? isPrivate,
    DateTime? entryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      mood: clearMood ? null : (mood ?? this.mood),
      promptUsed: promptUsed ?? this.promptUsed,
      attachments: attachments ?? this.attachments,
      isPrivate: isPrivate ?? this.isPrivate,
      entryDate: entryDate ?? this.entryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'mood': mood,
        'prompt_used': promptUsed,
        'attachments_json': AttachmentItem.encodeList(attachments),
        'is_private': isPrivate ? 1 : 0,
        'entry_date': entryDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory JournalEntryModel.fromMap(Map<String, dynamic> map) =>
      JournalEntryModel(
        id: map['id'] as String,
        title: (map['title'] as String?) ?? '',
        body: (map['body'] as String?) ?? '',
        mood: map['mood'] as String?,
        promptUsed: map['prompt_used'] as String?,
        attachments: AttachmentItem.decodeList(map['attachments_json'] as String?),
        isPrivate: ((map['is_private'] as int?) ?? 1) == 1,
        entryDate: DateTime.parse(map['entry_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

class AppSettingsModel {
  final String userName;
  final String themeMode; // 'system' | 'light' | 'dark'
  final String accentHex;
  final double textScale;
  final int autoLockSeconds; // 0 = immediate, 30, 60, 300
  final bool biometricsEnabled;
  final List<String> homeSections;

  const AppSettingsModel({
    this.userName = 'Friend',
    this.themeMode = 'system',
    this.accentHex = '#C85A32',
    this.textScale = 1.0,
    this.autoLockSeconds = 60,
    this.biometricsEnabled = true,
    this.homeSections = const [
      'greeting',
      'quick_actions',
      'stats',
      'pinned_notes',
      'recent_notes',
      'upcoming_tasks',
      'reflection',
    ],
  });

  AppSettingsModel copyWith({
    String? userName,
    String? themeMode,
    String? accentHex,
    double? textScale,
    int? autoLockSeconds,
    bool? biometricsEnabled,
    List<String>? homeSections,
  }) {
    return AppSettingsModel(
      userName: userName ?? this.userName,
      themeMode: themeMode ?? this.themeMode,
      accentHex: accentHex ?? this.accentHex,
      textScale: textScale ?? this.textScale,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      homeSections: homeSections ?? this.homeSections,
    );
  }
}
