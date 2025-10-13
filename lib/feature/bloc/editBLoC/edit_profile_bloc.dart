import 'package:online_doc_savimex/app_import.dart';
import 'edit_profile_event.dart';
import 'edit_profile_state.dart';

class EmployeeProfileBloc extends Bloc<EmployeeProfileEvent, EmployeeProfileState> {
  final EmployeeRepository repo;
  String? _employeeId;

  EmployeeProfileBloc({required this.repo}) : super(const EmployeeProfileState()) {
    on<EmployeeProfileStarted>(_onStarted);
    on<EmployeeProfileRefreshRequested>(_onRefresh);
    on<EmployeeProfileUpdatedLocally>(_onUpdatedLocally);
  }

  Future<void> _onStarted(
      EmployeeProfileStarted event,
      Emitter<EmployeeProfileState> emit,
      ) async {
    _employeeId = event.employeeId;
    emit(state.copyWith(status: EmployeeProfileStatus.loading, error: null));
    try {
      final Employee e = await repo.fetchEmployeeByID(_employeeId!);
      emit(state.copyWith(employee: e, status: EmployeeProfileStatus.success));
    } catch (e) {
      emit(state.copyWith(status: EmployeeProfileStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRefresh(
      EmployeeProfileRefreshRequested event,
      Emitter<EmployeeProfileState> emit,
      ) async {
    if (_employeeId == null && state.employee?.employeeID != null) {
      _employeeId = state.employee!.employeeID;
    }
    if (_employeeId == null) return;

    emit(state.copyWith(status: EmployeeProfileStatus.loading, error: null));
    try {
      final Employee e = await repo.fetchEmployeeByID(_employeeId!);
      emit(state.copyWith(employee: e, status: EmployeeProfileStatus.success));
    } catch (e) {
      emit(state.copyWith(status: EmployeeProfileStatus.failure, error: e.toString()));
    }
  }

  void _onUpdatedLocally(
      EmployeeProfileUpdatedLocally event,
      Emitter<EmployeeProfileState> emit,
      ) {
    emit(state.copyWith(employee: event.employee, status: EmployeeProfileStatus.success));
  }
}
