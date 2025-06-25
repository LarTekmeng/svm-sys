import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';

class UploadBlock extends StatefulWidget {
  final VoidCallback? onRemove;
  const UploadBlock({Key? key, this.onRemove}) : super(key: key);

  @override
  State<UploadBlock> createState() => _UploadBlockState();
}

class _UploadBlockState extends State<UploadBlock> {
  bool showFileDescription = false;
  final TextEditingController fileDescriptionController = TextEditingController();

  @override
  void dispose() {
    fileDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DottedBorder(
          borderType: BorderType.RRect,
          radius: const Radius.circular(8),
          dashPattern: [6, 3],
          color: Colors.black45,
          strokeWidth: 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_upload_outlined, size: 40),
                const SizedBox(height: 8),
                const Text(
                  'Click to browse file',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Drag and drop file here',
                  style: TextStyle(color: Colors.black54),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showFileDescription = !showFileDescription;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        showFileDescription
                            ? Icons.undo
                            : Icons.add_circle_outline,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showFileDescription ? 'Undo' : 'Add Description',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                if (showFileDescription)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: fileDescriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Enter file description...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
