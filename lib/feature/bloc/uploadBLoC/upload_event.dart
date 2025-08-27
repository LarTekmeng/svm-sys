import 'package:equatable/equatable.dart';
import 'dart:io';

class UploadEvent extends Equatable {
  const UploadEvent();
  @override
  List<Object?> get props => [];
}

class UploadSubmitted extends UploadEvent {
  final int documentTypeId;
  final String title;
  final String description;
  final List<File> files; // or XFile if you use image_picker

  const UploadSubmitted({
    required this.documentTypeId,
    required this.title,
    required this.description,
    required this.files,
  });

  @override
  List<Object?> get props => [documentTypeId, title, description, files];
}
