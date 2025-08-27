import 'package:equatable/equatable.dart';

/// Lightweight payload for uploads.
class UploadFilePayload {
  final String name;
  final List<int> bytes;
  final String mime;
  const UploadFilePayload({required this.name, required this.bytes, required this.mime});
}

abstract class ViewEvent extends Equatable {
  const ViewEvent();
  @override
  List<Object?> get props => [];
}

/// Initial load with target document id.
class ViewStarted extends ViewEvent {
  final int documentId;
  const ViewStarted(this.documentId);
  @override
  List<Object?> get props => [documentId];
}

/// Pull-to-refresh or programmatic refresh.
class ViewRefreshed extends ViewEvent {
  const ViewRefreshed();
}

/// User pressed Approve.
class ViewApprovePressed extends ViewEvent {
  const ViewApprovePressed();
}

/// User pressed Reject.
class ViewRejectPressed extends ViewEvent {
  const ViewRejectPressed();
}

/// User picked files for attachment.
class ViewUploadPicked extends ViewEvent {
  final List<UploadFilePayload> files;
  const ViewUploadPicked(this.files);
  @override
  List<Object?> get props => [files];
}

/// Clear one-time message (toast/snackbar).
class ViewClearFlash extends ViewEvent {
  const ViewClearFlash();
}
