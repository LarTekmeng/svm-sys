import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/home_repo.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepo homeRepo;

  HomeBloc({required this.homeRepo}) : super(const HomeState()) {
    on<HomeStarted>(_onLoad);
    on<HomeRefreshRequested>(_onLoad);
  }

  Future<void> _onLoad(HomeEvent event, Emitter<HomeState> emit) async {
    try {
      emit(state.copyWith(status: HomeStatus.loading, error: null));
      final docs = await homeRepo.getView(); // must return a new List
      emit(state.copyWith(
        status: HomeStatus.success,
        documents: List.of(docs as Iterable), // ensure new reference for Equatable
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.failure, error: e.toString()));
    }
  }
}
