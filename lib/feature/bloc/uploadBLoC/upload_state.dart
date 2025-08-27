import 'package:equatable/equatable.dart';

enum UploadStatus { idle, submitting, success, failure }

class UploadState extends Equatable {
  final UploadStatus status;
  final String? error;

  const UploadState({
    this.status = UploadStatus.idle,
    this.error,
  });

  UploadState copyWith({
    UploadStatus? status,
    String? error,
  }) {
    return UploadState(
      status: status ?? this.status,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, error];
}
