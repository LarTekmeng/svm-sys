class Document{
  final int? id;
  final String title;
  final int? doctypeId;
  final String description;
  Document({
    this.id,
    required this.title,
    this.doctypeId,
    required this.description
  });
  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as int?,
      doctypeId: json['doctype_id'] as int?,
      title: json['doc_title']?.toString() ?? '',
      description: json['doc_desc']?.toString() ?? '',
    );
  }
}