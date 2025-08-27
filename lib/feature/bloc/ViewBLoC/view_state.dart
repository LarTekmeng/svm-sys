import 'package:equatable/equatable.dart';
import 'package:online_doc_savimex/app_import.dart';

enum ViewStatus { initial, loading, loaded, error }

class ViewState extends Equatable {
  final ViewStatus status;
  final int? documentId;

  final DocumentDetail? detail;
  final List<DocumentFile> files;

  final bool actBusy;      // approving/rejecting busy
  final bool uploadBusy;   // attachment upload busy

  final String? error;     // fatal error on page load
  final String? flash;     // one-time message
  final int flashId;       // increments for distinct messages

  const ViewState({
    this.status = ViewStatus.initial,
    this.documentId,
    this.detail,
    this.files = const [],
    this.actBusy = false,
    this.uploadBusy = false,
    this.error,
    this.flash,
    this.flashId = 0,
  });

  ViewState copyWith({
    ViewStatus? status,
    int? documentId,
    DocumentDetail? detail,
    List<DocumentFile>? files,
    bool? actBusy,
    bool? uploadBusy,
    String? error,     // pass null to clear
    String? flash,     // set message
    bool clearFlash = false,
    int? flashId,
  }) {
    return ViewState(
      status: status ?? this.status,
      documentId: documentId ?? this.documentId,
      detail: detail ?? this.detail,
      files: files ?? this.files,
      actBusy: actBusy ?? this.actBusy,
      uploadBusy: uploadBusy ?? this.uploadBusy,
      error: error,
      flash: clearFlash ? null : (flash ?? this.flash),
      flashId: flashId ?? this.flashId,
    );
  }

  factory ViewState.initial() => const ViewState();

  @override
  List<Object?> get props => [
    status,
    documentId,
    detail,
    files,
    actBusy,
    uploadBusy,
    error,
    flash,
    flashId,
  ];
}
