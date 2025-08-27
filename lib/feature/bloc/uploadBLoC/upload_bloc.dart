import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/document_repo.dart';
import '../homeBLoC/home_bloc.dart';
import '../homeBLoC/home_event.dart';
import 'upload_event.dart';
import 'upload_state.dart';

class UploadBloc extends Bloc<UploadEvent, UploadState> {
  final DocumentRepository documentRepo;
  final HomeBloc homeBloc;

  UploadBloc({
    required this.documentRepo,
    required this.homeBloc,
  }) : super(const UploadState()) {
    on<UploadSubmitted>(_onSubmit);
  }

  Future<void> _onSubmit(
      UploadSubmitted event,
      Emitter<UploadState> emit,
      ) async {
    emit(state.copyWith(status: UploadStatus.submitting, error: null));
    try {
      // Backend contract: POST /api/documents/with-files with fields & files
      // (as implemented in your Node controller)
      await documentRepo.createDocumentWithFiles(
        documentTypeId: event.documentTypeId,
        title: event.title,
        description: event.description,
        files: event.files,
      );

      // Immediately refresh Home after a successful upload (no UI change needed)
      homeBloc.add(const HomeRefreshRequested());

      emit(state.copyWith(status: UploadStatus.success));
    } catch (e) {
      emit(state.copyWith(status: UploadStatus.failure, error: e.toString()));
    }
  }
}
