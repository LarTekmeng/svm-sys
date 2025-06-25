// lib/models/document_type.dart

class DocumentType {
  final int? id;
  final String docTitle;
  final String docDesc;

  DocumentType({
    this.id,
    required this.docTitle,
    required this.docDesc,
  });

  factory DocumentType.fromJson(Map<String, dynamic> json) {
    return DocumentType(
      id: json['id'] as int?,
      docTitle: (json['name'] as String) ?? '',
      docDesc:  (json['description'] as String) ?? '',
    );
  }
}
