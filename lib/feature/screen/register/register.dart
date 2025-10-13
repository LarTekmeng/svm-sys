import 'dart:io';
import 'package:online_doc_savimex/app_import.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _empIdCtrl = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  File? _profileImage;
  int? _selectedDeptId;              // ← holds only the dept ID

  @override
  void initState() {
    super.initState();
    // kick off loading departments
    context.read<RegisterBloc>().add(LoadDepartments());
  }

  @override
  void dispose() {
    _empIdCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate() || _selectedDeptId == null) return;
    context.read<RegisterBloc>().add(
      RegisterRequested(
        _nameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passCtrl.text,
        _selectedDeptId!,           // ← pass the int dept ID
        _empIdCtrl.text.trim(),
        profileImage: _profileImage,
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegisterBloc, RegisterState>(
      listener: (context, state) {
        if (state is RegisterSuccess) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } else if (state is RegisterFailure) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.error)));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Register')),
        body: BlocBuilder<RegisterBloc, RegisterState>(
          builder: (context, state) {
            if (state is RegisterLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // pull departments list out of state
            List<Department> depts = [];
            if (state is DepartmentsLoadSuccess) {
              depts = state.departments;
              // default to first dept ID if none selected yet
              _selectedDeptId ??= depts.isNotEmpty ? depts.first.id : null;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // avatar picker
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundImage:
                          _profileImage != null ? FileImage(_profileImage!) : null,
                          child: _profileImage == null
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // DEPARTMENT dropdown now holds int IDs
                    DropdownButtonFormField<int>(
                      initialValue: _selectedDeptId,
                      decoration: const InputDecoration(labelText: 'Department'),
                      items: depts.map((d) {
                        return DropdownMenuItem<int>(
                          value: d.id,
                          child: Text(d.name),
                        );
                      }).toList(),
                      onChanged: (id) => setState(() => _selectedDeptId = id),
                      validator: (_) =>
                      _selectedDeptId == null ? 'Please select one' : null,
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _empIdCtrl,
                      decoration: const InputDecoration(labelText: 'Employee ID'),
                      validator: (v) =>
                      v == null || v.isEmpty ? 'Enter employee ID' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter email';
                        return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)
                            ? null
                            : 'Invalid email';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.length < 6) return 'Min 6 chars';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _onSubmit,
                      child: const Text('Register'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Have an account? Login'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
