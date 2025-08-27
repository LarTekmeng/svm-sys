import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class HomeStarted extends HomeEvent {
  const HomeStarted();
}

class HomeRefreshRequested extends HomeEvent {
  const HomeRefreshRequested();
}
