import 'package:online_doc_savimex/app_import.dart';

class AuthLoginBloc extends Bloc<AuthLoginEvent, AuthLoginState> {
  final AuthRepository _repo;
  AuthLoginBloc(this._repo) : super(AuthInitial()) {
    on<AppStarted> ((e, emit) async {
      emit(AuthLoading());
      final ok = await _repo.hasValidToken();
      if(ok) {
        final employee = await _repo.getPersistedEmployee();
        emit(employee != null ? AuthAuthenticated(employee) : Unauthenticated());
      } else {
        emit(Unauthenticated());
      }
    });

    on<LoginRequested>((e, emit) async{
      emit(AuthLoading());
      try {
        final employee = await _repo.loginUser(employeeID: e.employeeID, password: e.password, rememberMe: e.rememberMe);
        emit(AuthAuthenticated(employee));
      } catch (err){
        emit(AuthFailure(err.toString()));
      }
    });

    on<LogoutRequested>((e,emit) async {
      await _repo.logout();
      emit(Unauthenticated());
    });
  }
}
