// create_department.dart
import 'package:online_doc_savimex/app_import.dart';

class CreateDepartment extends StatefulWidget {
  final Department? department; // null = create mode, not null = edit mode

  const CreateDepartment({super.key, this.department});

  @override
  State<CreateDepartment> createState() => _CreateDepartmentState();
}

class _CreateDepartmentState extends State<CreateDepartment> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;

  // Helper getter to check if we're in edit mode
  bool get _isEditMode => widget.department != null;

  @override
  void initState() {
    super.initState();
    // If editing, populate the field with current name
    if (_isEditMode) {
      _name.text = widget.department!.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repo = context.read<DepartmentRepository>();
      final trimmedName = _name.text.trim();

      if (_isEditMode) {
        // Update existing department
        await repo.updateDepartment(widget.department!.id, trimmedName);
      } else {
        // Create new department
        await repo.createDepartment(trimmedName);
      }

      if (!mounted) return;
      // IMPORTANT: return TRUE so the caller knows to refresh
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Department' : 'Create Department'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Department name'),
                enabled: !_busy,
                autofocus: !_isEditMode, // Auto-focus only in create mode
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Name is required';
                  if (t.length > 100) return 'Max 100 characters';
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Icon(_isEditMode ? Icons.check : Icons.add),
                      label: Text(_isEditMode ? 'Update' : 'Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}