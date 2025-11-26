import 'package:online_doc_savimex/app_import.dart';
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final DepartmentRepository _depRepo;
  final AuthRepository _authRepo;
  final RoleRepository _roleRepo;

  RegisterBloc({
    required DepartmentRepository depRepo,
    required AuthRepository authRepo,
    required RoleRepository roleRepo,
  })  : _depRepo = depRepo, _authRepo = authRepo, _roleRepo = roleRepo,
        super(RegisterInitial()) {
    on<LoadDepartments>(_onLoadDepartments);
    on<RegisterRequested>(_onRegisterSubmitted);
    on<LoadRoles>(_onLoadRoles);
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
        name: event.employeeName,
        email: event.email,
        password: event.password,
        departmentID: event.departmentID,
        employeeID: event.employeeID,
        profileImage: event.profileImage,
      );
      if (event.createNew){
        emit (RegisterSuccessNew());
      }else{
        emit (RegisterSuccess());
      }
    } catch (e) {
      emit(RegisterFailure(e.toString()));
    }
  }
  Future<void> _onLoadRoles(
      LoadRoles event,
      Emitter<RegisterState> emit,
      ) async {
    // You can choose whether to emit a loading state or not; keeping UI snappy:
    final roles = await _roleRepo.fetchRole();
    emit(RoleLoadSuccess(roles));                       // <-- this feeds the UI
  }
}