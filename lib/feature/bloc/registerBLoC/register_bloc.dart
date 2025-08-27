import 'package:online_doc_savimex/app_import.dart';
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final DepartmentRepository _depRepo;
  final AuthRepository _authRepo;

  RegisterBloc({
    required DepartmentRepository depRepo,
    required AuthRepository authRepo,
  })  : _depRepo = depRepo,
        _authRepo = authRepo,
        super(RegisterInitial()) {
    on<LoadDepartments>(_onLoadDepartments);
    on<RegisterRequested>(_onRegisterSubmitted);
  }

  Future<void> _onLoadDepartments(
      LoadDepartments event,
      Emitter<RegisterState> emit,
      ) async {
    emit(RegisterLoading());
    try {
      final depts = await _depRepo.fetchDepartments();
      emit(DepartmentsLoadSuccess(depts));
    } catch (e) {
      emit(RegisterFailure(e.toString()));
    }
  }

  Future<void> _onRegisterSubmitted(
      RegisterRequested event,
      Emitter<RegisterState> emit,
      ) async {
    emit(RegisterLoading());
    try {
      await _authRepo.registerEmployee(
        // event.employeeName,
        // event.email,
        // event.password,
        // event.departmentID,
        // event.employeeID,
        // profileImage : event.profileImage,
        name: event.employeeName,
        email: event.email,
        password: event.password,
        departmentID: event.departmentID,
        employeeID: event.employeeID,
        profileImage: event.profileImage,
      );
      emit(RegisterSuccess());
    } catch (e) {
      emit(RegisterFailure(e.toString()));
    }
  }
}