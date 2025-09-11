import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/repositories/doctype_repo.dart';
import 'package:online_doc_savimex/feature/widget/color.dart';

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
  late final AuthRepository authRepo;

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
        final doctypeRepo = context.read<DoctypeRepository>();
        await doctypeRepo.newDocType(
          _titleController.text.trim(),
          _descriptionController.text.trim(),
        );
      } else {
        // UPDATE
        final doctypeRepo = context.read<DoctypeRepository>();
        await doctypeRepo.updateDocType(
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
    final title = Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.white, fontWeight: FontWeight.bold);
    final subTitle = Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.white, fontWeight: FontWeight.bold);
    final linkText = Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.yellow, fontWeight: FontWeight.bold);
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        color: AppColors.background,
        child: Padding(
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
                  style: title,
                  // style: const TextStyle(
                  //   fontSize: 22,
                  //   fontWeight: FontWeight.bold,
                  //   color: AppColors.white
                  // ),
                ),
                const SizedBox(height: 30),

                // Title field
                Text('Document type name:',style: subTitle),
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
                  onTapOutside: (event){FocusScope.of(context).unfocus();},
                ),
                const SizedBox(height: 20),

                // Description field
                Text('Document description:', style: subTitle,),
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
                  onTapOutside: (event){FocusScope.of(context).unfocus();},
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
                    child: Text(
                      'Set the document type now?',
                      style: linkText,
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
      ),
    );
  }
}
