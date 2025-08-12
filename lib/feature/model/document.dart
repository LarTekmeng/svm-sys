class Document {
  final int? id;
  final String title;
  final int? doctypeId;                 // maps from document_type_id
  final String? description;
  final String status;                  // defaults to 'PENDING' if absent
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? documentTypeTitle;      // handles document_type_title or document_type
  final int? sequence;                  // present in "assigned to me" rows
  final String? stepStatus;             // present in "assigned to me" rows
  final String? stepAction;             // present in "assigned to me" rows

  const Document({
    this.id,
    required this.title,
    this.doctypeId,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.documentTypeTitle,
    this.sequence,
    this.stepStatus,
    this.stepAction,
  });

  /// Robust factory that:
  /// - parses DateTime from string
  /// - accepts multiple key variants
  /// - provides safe defaults
  factory Document.fromJson(Map<String, dynamic> json) {
    final created = _parseDate(json['created_at'] ?? json['createed_at']);
    final updated = _parseDate(json['updated_at']);

    return Document(
      id: _asInt(json['id']),
      title: (json['title'] ?? '') as String,
      doctypeId: _asInt(json['document_type_id'] ?? json['doctype_id']),
      description: json['description'] as String?,
      status: (json['status'] as String?)?.toUpperCase() ?? 'PENDING',
      createdAt: created ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: updated ?? DateTime.fromMillisecondsSinceEpoch(0),
      documentTypeTitle: (json['document_type_title'] ?? json['document_type']) as String?,
      sequence: _asInt(json['sequence']),
      stepAction: json['step_action'] as String?,
      stepStatus: json['step_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': title,
    if (doctypeId != null) 'document_type_id': doctypeId,
    'description': description,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'document_type_title': documentTypeTitle,
    'sequence': sequence,
    'step_action': stepAction,
    'step_status': stepStatus,
  };

  Document copyWith({
    int? id,
    String? title,
    int? doctypeId,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? documentTypeTitle,
    int? sequence,
    String? stepStatus,
    String? stepAction,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      doctypeId: doctypeId ?? this.doctypeId,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      documentTypeTitle: documentTypeTitle ?? this.documentTypeTitle,
      sequence: sequence ?? this.sequence,
      stepStatus: stepStatus ?? this.stepStatus,
      stepAction: stepAction ?? this.stepAction,
    );
  }

  // ---------- helpers ----------
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        // Try trimming/normalizing if needed
        try {
          return DateTime.parse(v.replaceAll(' ', 'T'));
        } catch (_) {}
      }
    }
    return null;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String && v.isNotEmpty) {
      final n = int.tryParse(v);
      return n;
    }
    return null;
  }
}

class DocumentFile {
  final int id;
  final int documentId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String fileUrl;
  final DateTime uploadedAt;

  const DocumentFile({
    required this.id,
    required this.documentId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.fileUrl,
    required this.uploadedAt,
  });

  factory DocumentFile.fromJson(Map<String, dynamic> json) {
    return DocumentFile(
      id: json['id'] as int,
      documentId: json['document_id'] as int,
      fileName: json['file_name'] as String,
      fileType: json['file_type'] as String,
      fileSize: (json['file_size'] as num).toInt(),
      fileUrl: json['file_url'] as String,
      uploadedAt: DateTime.parse(json['upload_at'] ?? json['uploaded_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'document_id': documentId,
    'file_name': fileName,
    'file_type': fileType,
    'file_size': fileSize,
    'file_url': fileUrl,
    'uploaded_at': uploadedAt.toIso8601String(),
  };
}
