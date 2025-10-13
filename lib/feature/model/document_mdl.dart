// Put these in a shared file or at top of document_mdl.dart
int asInt(dynamic v, {int? or}) {
  if (v == null) return or ?? 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) {
    final i = int.tryParse(v);
    if (i != null) return i;
    final d = double.tryParse(v);
    if (d != null) return d.toInt();
  }
  throw FormatException("Expected int, got: $v (${v.runtimeType})");
}

double asDouble(dynamic v, {double? or}) {
  if (v == null) return or ?? 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) {
    final d = double.tryParse(v);
    if (d != null) return d;
  }
  throw FormatException("Expected double, got: $v (${v.runtimeType})");
}

DateTime _epoch0() => DateTime.fromMillisecondsSinceEpoch(0);
DateTime _safeDate(dynamic v, {DateTime? or}) {
  if (v == null) return or ?? _epoch0();
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) {
    try { return DateTime.parse(v); } catch (_) {
      try { return DateTime.parse(v.replaceAll(' ', 'T')); } catch (_) {}
    }
  }
  return or ?? _epoch0();
}

class Document {
  final int? id;
  final String title;
  final int? doctypeId;                 // maps from document_type_id
  final String? description;
  final String? status;                  // defaults to 'PENDING' if absent
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? documentTypeTitle;      // handles document_type_title or document_type
  final String? inboxType;
  final bool? requiresAction;
  final int? sequence;                  // present in "assigned to me" rows
  final String? stepStatus;             // present in "assigned to me" rows
  final String? stepAction;// present in "assigned to me" rows
  final String? uploaderName;

  const Document({
    this.id,
    required this.title,
    this.doctypeId,
    this.description,
    this.status,
    required this.createdAt,
    required this.updatedAt,
    this.documentTypeTitle,
    this.inboxType,
    this.requiresAction,
    this.sequence,
    this.stepStatus,
    this.stepAction,
    this.uploaderName
  });

  /// Robust factory that:
  /// - parses DateTime from string
  /// - accepts multiple key variants
  /// - provides safe defaults
  factory Document.fromJson(Map<String, dynamic> json) {
    final created = _parseDate(json['created_at'] ?? json['created_at']);
    final updated = _parseDate(json['updated_at']);

    return Document(
      id: (json['id'] == null) ? null : asInt(json['id']),
      title: (json['title'] ?? '') as String,
      doctypeId: (json['document_type_id'] == null) ? null : asInt(json['document_type_id']),
      description: json['description'] as String?,
      status: (json['status'] as String?)?.toUpperCase(),
      createdAt: created ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: updated ?? DateTime.fromMillisecondsSinceEpoch(0),
      documentTypeTitle: (json['document_type_title'] ?? json['document_type']) as String?,
      inboxType: json['inbox_type'] as String?,
      requiresAction: json['requires_action'] as bool?,
      sequence: (json['sequence'] == null) ? null : asInt(json['sequence']),
      stepAction: json['step_action'] as String?,
      stepStatus: json['step_status'] as String?,
      uploaderName: json['uploader_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': title,
    if (doctypeId != null) 'document_type_id': doctypeId,
    'description': description,
    if(status != null) 'status' : status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'document_type_title': documentTypeTitle,
    'sequence': sequence,
    'step_action': stepAction,
    'step_status': stepStatus,
    'uploader_name' : uploaderName,
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
    String? uploaderName,
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
      uploaderName: uploaderName ?? this.uploaderName,
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
  final String? uploaderName;

  const DocumentFile({
    required this.id,
    required this.documentId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.fileUrl,
    required this.uploadedAt,
    this.uploaderName,
  });

  factory DocumentFile.fromJson(Map<String, dynamic> json) => DocumentFile(
    id: asInt(json['id']),
    documentId: asInt(json['document_id']),
    fileName: (json['file_name'] ?? '') as String,
    fileType: (json['file_type'] ?? '') as String,
    fileSize: asInt(json['file_size'] ?? json['file_size_bytes']),
    fileUrl: (json['file_url'] ?? '') as String,
    uploadedAt: _safeDate(json['uploaded_at'] ?? json['upload_at']),
    uploaderName: (json['uploader_name'] as String?),
  );
}


class DocumentDetail {
  // actionability from backend
  final int? currentActionableStepId;
  final String? currentActionableStepAction;
  final bool canAct;     // Approve/Reject
  final bool canAttach;  // Add attachment

  // core
  final int id;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;

  // meta
  final String documentTypeTitle;
  final String forwardMode; // Direct | Step by Step
  final String uploaderName;
  final String uploaderDepartmentName;

  // steps
  final int flowsCount;        // defined in flow
  final List<DocumentStep> steps; // current instance steps

  const DocumentDetail({
    required this.currentActionableStepId,
    required this.currentActionableStepAction,
    required this.canAct,
    required this.canAttach,
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.documentTypeTitle,
    required this.forwardMode,
    required this.uploaderName,
    required this.uploaderDepartmentName,
    required this.flowsCount,
    required this.steps,
  });

  factory DocumentDetail.fromJson(Map<String, dynamic> json) {
    final doc = (json['document'] as Map<String, dynamic>);
    final stepsJson = (json['steps'] as List).cast<Map<String, dynamic>>();
    return DocumentDetail(
      currentActionableStepId: json['current_actionable_step_id'] as int?,
      currentActionableStepAction: json['current_actionable_step_action'] as String?,
      canAct: json['canAct'] == true,
      canAttach: json['canAttach'] == true,

      id: asInt(doc['id']),
      title: (doc['title'] ?? '') as String,
      description: (doc['description'] ?? '') as String,
      status: ((doc['status'] ?? 'PENDING') as String).toUpperCase(),
      createdAt: _safeDate(doc['created_at']),

      documentTypeTitle: (doc['document_type_title'] ?? '') as String,
      forwardMode: (doc['forward_mode'] ?? 'Direct') as String,
      uploaderName: (doc['uploader_name'] ?? '') as String,
      uploaderDepartmentName: (doc['uploader_department_name'] ?? '-') as String,

      flowsCount: asInt(json['flowsCount'], or: 0),
      steps: stepsJson.map(DocumentStep.fromJson).toList(),
    );
  }
}

class DocumentStep {
  final int id;
  final int sequence;
  final int employeeId;
  final String employeeName;
  final String departmentName;
  /// Display only (APPROVAL / SIGNATURE)
  final String stepAction;
  /// PENDING | APPROVED | REJECTED
  final String status;

  const DocumentStep({
    required this.id,
    required this.sequence,
    required this.employeeId,
    required this.employeeName,
    required this.departmentName,
    required this.stepAction,
    required this.status,
  });

  factory DocumentStep.fromJson(Map<String, dynamic> j) => DocumentStep(
    id: asInt(j['id']),
    sequence: asInt(j['sequence']),
    employeeId: asInt(j['employee_id']),
    employeeName: (j['employee_name'] ?? '-') as String,
    departmentName: (j['department_name'] ?? '-') as String,
    stepAction: (j['step_action'] ?? '') as String,
    status: (j['status'] ?? '') as String,
  );
}