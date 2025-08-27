import 'package:equatable/equatable.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<dynamic> documents; // replace with your Document model
  final String? error;
  final DateTime? lastUpdated;

  const HomeState({
    this.status = HomeStatus.initial,
    this.documents = const [],
    this.error,
    this.lastUpdated,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<dynamic>? documents,
    String? error,
    DateTime? lastUpdated,
  }) {
    return HomeState(
      status: status ?? this.status,
      documents: documents ?? this.documents,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [status, documents, error, lastUpdated];
}
