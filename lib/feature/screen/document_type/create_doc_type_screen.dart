import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/repositories/doctype_repo.dart';

class CreateDocumentTypeScreen extends StatefulWidget {
  final DocumentType? existing;
  const CreateDocumentTypeScreen({super.key, this.existing});

  @override
  State<CreateDocumentTypeScreen> createState() =>
      _CreateDocumentTypeScreenState();
}

class _CreateDocumentTypeScreenState extends State<CreateDocumentTypeScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Prefill if editing
    _titleController = TextEditingController(text: widget.existing?.docTitle);
    _descriptionController = TextEditingController(
      text: widget.existing?.docDesc,
    );
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      if (widget.existing == null) {
        // CREATE
        await DoctypeRepository().newDocType(
          _titleController.text.trim(),
          _descriptionController.text.trim(),
        );
      } else {
        // UPDATE
        await DoctypeRepository().updateDocType(
          widget.existing!.id!,
          _titleController.text.trim(),
          _descriptionController.text.trim(),
        );
      }
      // On success, pop back and signal parent to refresh
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit
                    ? 'Edit: ${widget.existing?.docTitle}'
                    : 'Create new\nDocument Type',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Title field
              const Text('Document type name:'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // Description field
              const Text('Document description:'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'type...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 15),

              // Optional link to set types
              Center(
                child: TextButton(
                  onPressed: () {
                    final id = widget.existing?.id;
                    if (id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => SetDocumentTypeScreen(documentTypeId: id),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Set the document type now?',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),

              const Spacer(),

              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Confirm button
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                        onPressed: _onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          isEdit ? 'Save' : 'Confirm',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),

                  // Cancel button
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
