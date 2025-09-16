
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

class UploadBlock extends StatefulWidget {
  final VoidCallback? onRemove;
  final VoidCallback? onTapPickFiles;
  final void Function(List<PlatformFile> files)? onFilesDropped;

  const UploadBlock({
    super.key,
    this.onRemove,
    this.onTapPickFiles,
    this.onFilesDropped,
  });

  @override
  State<UploadBlock> createState() => _UploadBlockState();
}

class _UploadBlockState extends State<UploadBlock> {
  bool showFileDescription = false;
  final TextEditingController fileDescriptionController =
      TextEditingController();

  DropzoneViewController? _dz;
  bool _hovering = false;

  @override
  void dispose() {
    fileDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleDrop(dynamic ev) async {
    if (_dz == null) return;
    final name = await _dz!.getFilename(ev);
    final size = await _dz!.getFileSize(ev);
    final bytes = await _dz!.getFileData(ev);

    final pf = PlatformFile(name: name, size: size, bytes: bytes);

    widget.onFilesDropped?.call([pf]);
    setState(() {
      _hovering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dnd = DottedBorder(
      color: _hovering ? Colors.blue : Colors.black26,
      strokeWidth: 1.2,
      dashPattern: [6, 4],
      borderType: BorderType.RRect,
      radius: Radius.circular(12),
      child: InkWell(
        onTap: widget.onTapPickFiles,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_upload_outlined, size: 40),
              SizedBox(height: 8),
              Text(
                'Click to browse files',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'or drag & drop here',
                style: TextStyle(color: Colors.black54),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    return Stack(
      children: [
        dnd,
        if(kIsWeb)
          Positioned.fill(child: IgnorePointer(
            ignoring: false,
            child: DropzoneView(
              onCreated: (c) => _dz = c,
              operation: DragOperation.copy,
              cursor: CursorType.grab,
              onHover: () => setState(() => _hovering = true),
              onLeave: () => setState(() => _hovering = false),
              onDropFile: _handleDrop,
            ),
          )),
        if (widget.onRemove != null)
          Positioned(
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.undo, color: Colors.red),
              onPressed: widget.onRemove,
            ),
          ),
      ],
    );
  }
}
