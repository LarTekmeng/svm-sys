import 'package:online_doc_savimex/app_import.dart';
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final DepartmentRepository _depRepo;
  final AuthRepository _authRepo;
  final RoleRepository _roleRepo;
  final EmployeeRepository _employeeRepo;

  RegisterBloc({
    required DepartmentRepository depRepo,
    required AuthRepository authRepo,
    required RoleRepository roleRepo,
    required EmployeeRepository employeeRepo,
  })  : _depRepo = depRepo, _authRepo = authRepo, _roleRepo = roleRepo, _employeeRepo = employeeRepo,
        super(RegisterInitial()) {
    on<LoadDepartments>(_onLoadDepartments);
    on<RegisterRequested>(_onRegisterSubmitted);
    on<LoadRoles>(_onLoadRoles);
    on<UpdateEmployeeRequested>(_onUpdateEmployee);
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
        roleId: event.roleId,
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

  Future<void> _onUpdateEmployee(
      UpdateEmployeeRequested event,
      Emitter<RegisterState> emit,
      ) async {
    emit(RegisterLoading());
    try {
      await _employeeRepo.updateEmployee(
        employeeId: event.employeeId,
        name: event.name,
        email: event.email,
        password: event.password, // null = don't change password
        departmentId: event.departmentId,
        empId: event.empId,
        roleId: event.roleId,
        profileImage: event.profileImage,
      );

      emit(UpdateEmployeeSuccess());
    } catch (e) {
      emit(RegisterFailure(e.toString()));
    }
  }
}