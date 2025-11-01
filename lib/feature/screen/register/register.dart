import 'dart:io';
import 'dart:developer' as dev; // for dev.log
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:image_picker/image_picker.dart';
import 'package:online_doc_savimex/app_import.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _empIdCtrl = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  File? _profileImage;
  int? _selectedDeptId;

  bool _defaultDeptSet = false; // prevent resetting selection on every rebuild

  @override
  void initState() {
    super.initState();
    debugPrint('[Register] initState() → dispatch LoadDepartments');
    try {
      context.read<RegisterBloc>().add(LoadDepartments());
    } catch (e, st) {
      dev.log('[Register] ERROR dispatching LoadDepartments', error: e, stackTrace: st);
    }
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
    debugPrint('[Register] _onSubmit() pressed');
    if (!_formKey.currentState!.validate()) {
      debugPrint('[Register] Form invalid → abort submit');
      return;
    }
    if (_selectedDeptId == null) {
      debugPrint('[Register] Department not selected → abort submit');
      return;
    }

    // Mask password length only (avoid printing secrets)
    final masked = '*' * _passCtrl.text.length;

    dev.log('[Register] Dispatch RegisterRequested', name: 'register.submit', error: {
      'name'        : _nameCtrl.text.trim(),
      'email'       : _emailCtrl.text.trim(),
      'passwordLen' : masked.length,
      'departmentId': _selectedDeptId,
      'employeeId'  : _empIdCtrl.text.trim(),
      'hasImage'    : _profileImage != null,
    });

    try {
      context.read<RegisterBloc>().add(
        RegisterRequested(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passCtrl.text,
          _selectedDeptId!,
          _empIdCtrl.text.trim(),
          profileImage: _profileImage,
        ),
      );
    } catch (e, st) {
      dev.log('[Register] ERROR dispatching RegisterRequested', error: e, stackTrace: st);
    }
  }

  Future<void> _pickImage() async {
    debugPrint('[Register] _pickImage() open gallery');
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _profileImage = File(picked.path));
        debugPrint('[Register] Picked image: ${picked.path}');
      } else {
        debugPrint('[Register] Image picking canceled');
      }
    } catch (e, st) {
      dev.log('[Register] ERROR picking image', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegisterBloc, RegisterState>(
      listener: (context, state) {
        debugPrint('[Register] Listener state: ${state.runtimeType}');
        if (state is RegisterSuccess) {
          debugPrint('[Register] RegisterSuccess → go LoginScreen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } else if (state is RegisterFailure) {
          dev.log('[Register] RegisterFailure', error: state.error);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.error)));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Create new employee')),
        body: BlocBuilder<RegisterBloc, RegisterState>(
          buildWhen: (prev, curr) {
            // Always log transitions
            debugPrint('[Register] buildWhen: ${prev.runtimeType} → ${curr.runtimeType}');
            return true;
          },
          builder: (context, state) {
            if (state is RegisterLoading) {
              debugPrint('[Register] UI: RegisterLoading');
              return const Center(child: CircularProgressIndicator());
            }

            // pull departments list out of state
            List<Department> depts = [];
            if (state is DepartmentsLoadSuccess) {
              depts = state.departments;
              debugPrint('[Register] DepartmentsLoadSuccess: count=${depts.length}');
              if (!_defaultDeptSet && depts.isNotEmpty) {
                // set default only once to avoid flipping selection on rebuilds
                _selectedDeptId ??= depts.first.id;
                _defaultDeptSet = true;
                debugPrint('[Register] Default dept selected: id=$_selectedDeptId (${depts.first.name})');
              }
            } else {
              debugPrint('[Register] State not DepartmentsLoadSuccess (got ${state.runtimeType})');
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

                    // DEPARTMENT dropdown (int IDs)
                    DropdownButtonFormField<int>(
                      key: const ValueKey('dept_dropdown'),
                      value: _selectedDeptId,
                      decoration: const InputDecoration(labelText: 'Department'),
                      items: depts.map((d) {
                        return DropdownMenuItem<int>(
                          value: d.id,
                          child: Text(d.name),
                        );
                      }).toList(),
                      onChanged: (id) {
                        setState(() => _selectedDeptId = id);
                        debugPrint('[Register] Dept changed → $_selectedDeptId');
                      },
                      validator: (_) =>
                      _selectedDeptId == null ? 'Please select one' : null,
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _empIdCtrl,
                      decoration: const InputDecoration(labelText: 'Employee ID'),
                      validator: (v) {
                        final ok = v != null && v.isNotEmpty;
                        if (!ok) debugPrint('[Register] Validation fail: Employee ID');
                        return ok ? null : 'Enter employee ID';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) {
                        final ok = v != null && v.isNotEmpty;
                        if (!ok) debugPrint('[Register] Validation fail: Name');
                        return ok ? null : 'Enter name';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          debugPrint('[Register] Validation fail: Email empty');
                          return 'Enter email';
                        }
                        final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
                        if (!ok) debugPrint('[Register] Validation fail: Email invalid → $v');
                        return ok ? null : 'Invalid email';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) {
                        final ok = v != null && v.length >= 6;
                        if (!ok) debugPrint('[Register] Validation fail: Password too short');
                        return ok ? null : 'Min 6 chars';
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _onSubmit,
                      child: const Text('Register'),
                    ),
                    TextButton(
                      onPressed: () {
                        debugPrint('[Register] Go to LoginScreen via footer button');
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
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
