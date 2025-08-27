import 'package:online_doc_savimex/app_import.dart';


class ViewBloc extends Bloc<ViewEvent, ViewState> {
  final DocumentRepository repo;
  ViewBloc({required this.repo}) : super(ViewState.initial()) {
    on<ViewStarted>(_onStarted);
    on<ViewRefreshed>(_onRefreshed);
    on<ViewApprovePressed>(_onApprove);
    on<ViewRejectPressed>(_onReject);
    on<ViewUploadPicked>(_onUploadPicked);
    on<ViewClearFlash>(_onClearFlash);
  }

  Future<void> _onStarted(ViewStarted e, Emitter<ViewState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading, documentId: e.documentId, error: null, clearFlash: true));
    try {
      final detail = await repo.getDetail(e.documentId);
      final files = await repo.listFiles(e.documentId);
      emit(state.copyWith(
        status: ViewStatus.loaded,
        detail: detail,
        files: files,
      ));
    } catch (err) {
      emit(state.copyWith(status: ViewStatus.error, error: 'Failed to load: $err'));
    }
  }

  Future<void> _onRefreshed(ViewRefreshed e, Emitter<ViewState> emit) async {
    final id = state.documentId;
    if (id == null) return;
    try {
      final detail = await repo.getDetail(id);
      final files = await repo.listFiles(id);
      emit(state.copyWith(status: ViewStatus.loaded, detail: detail, files: files, error: null));
    } catch (err) {
      emit(state.copyWith(status: ViewStatus.error, error: 'Failed to refresh: $err'));
    }
  }

  Future<void> _onApprove(ViewApprovePressed e, Emitter<ViewState> emit) async {
    final d = state.detail;
    if (d == null) return;
    if (!d.canAct || d.currentActionableStepId == null) {
      // Not allowed: silently ignore or flash
      emit(state.copyWith(flash: 'You cannot approve right now', flashId: state.flashId + 1));
      return;
    }
    emit(state.copyWith(actBusy: true, clearFlash: true));
    try {
      await repo.decideStep(documentId: d.id, stepId: d.currentActionableStepId!, decision: 'APPROVED');
      // Reload detail & files after decision
      final detail = await repo.getDetail(d.id);
      final files = await repo.listFiles(d.id);
      emit(state.copyWith(
        detail: detail,
        files: files,
        actBusy: false,
        flash: 'Approved',
        flashId: state.flashId + 1,
      ));
    } catch (err) {
      emit(state.copyWith(actBusy: false, flash: 'Approve failed: $err', flashId: state.flashId + 1));
    }
  }

  Future<void> _onReject(ViewRejectPressed e, Emitter<ViewState> emit) async {
    final d = state.detail;
    if (d == null) return;
    if (!d.canAct || d.currentActionableStepId == null) {
      emit(state.copyWith(flash: 'You cannot reject right now', flashId: state.flashId + 1));
      return;
    }
    emit(state.copyWith(actBusy: true, clearFlash: true));
    try {
      await repo.decideStep(documentId: d.id, stepId: d.currentActionableStepId!, decision: 'REJECTED');
      final detail = await repo.getDetail(d.id);
      final files = await repo.listFiles(d.id);
      emit(state.copyWith(
        detail: detail,
        files: files,
        actBusy: false,
        flash: 'Rejected',
        flashId: state.flashId + 1,
      ));
    } catch (err) {
      emit(state.copyWith(actBusy: false, flash: 'Reject failed: $err', flashId: state.flashId + 1));
    }
  }

  Future<void> _onUploadPicked(ViewUploadPicked e, Emitter<ViewState> emit) async {
    final d = state.detail;
    if (d == null) return;
    if (!d.canAttach) {
      emit(state.copyWith(flash: 'You cannot attach files right now', flashId: state.flashId + 1));
      return;
    }
    if (e.files.isEmpty) return;

    emit(state.copyWith(uploadBusy: true, clearFlash: true));
    try {
      // Convert payload to repo’s accepted tuple
      final uploaded = await repo.addFiles(
        d.id,
        e.files.map((f) => (name: f.name, bytes: f.bytes, mime: f.mime)).toList(),
      );
      // Prepend in-memory; no need to hit server again unless you prefer full refresh
      final newFiles = [...uploaded, ...state.files];
      emit(state.copyWith(
        files: newFiles,
        uploadBusy: false,
        flash: 'Files uploaded',
        flashId: state.flashId + 1,
      ));
    } catch (err) {
      emit(state.copyWith(uploadBusy: false, flash: 'Upload failed: $err', flashId: state.flashId + 1));
    }
  }

  void _onClearFlash(ViewClearFlash e, Emitter<ViewState> emit) {
    emit(state.copyWith(clearFlash: true));
  }
}
