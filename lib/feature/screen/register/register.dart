import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:online_doc_savimex/app_import.dart';

import '../../model/role_mdl.dart';

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
  int? _selectedRoleId;

  bool _defaultDeptSet = false;
  bool _defaultRoleSet = false;

  // Caches so we don't lose data on state switches
  List<Department> _depts = [];
  List<Role> _roles = [];

  @override
  void initState() {
    super.initState();
    debugPrint('[Register] initState() → dispatch LoadDepartments & LoadRoles');
    try {
      final bloc = context.read<RegisterBloc>();
      bloc.add(LoadDepartments());
      bloc.add(LoadRoles());
    } catch (e, st) {
      dev.log('[Register] ERROR dispatching initial loads', error: e, stackTrace: st);
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
    if (_selectedRoleId == null) {
      debugPrint('[Register] Role not selected → abort submit');
      return;
    }

    final masked = '*' * _passCtrl.text.length;

    dev.log('[Register] Dispatch RegisterRequested',
        name: 'register.submit',
        error: {
          'name'        : _nameCtrl.text.trim(),
          'email'       : _emailCtrl.text.trim(),
          'passwordLen' : masked.length,
          'departmentId': _selectedDeptId,
          'roleId'      : _selectedRoleId,
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
          roleId: _selectedRoleId,
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

        if (state is DepartmentsLoadSuccess) {
          setState(() {
            _depts = state.departments;
            if (!_defaultDeptSet && _depts.isNotEmpty) {
              _selectedDeptId ??= _depts.first.id;
              _defaultDeptSet = true;
              debugPrint('[Register] Default dept selected: id=$_selectedDeptId (${_depts.first.name})');
            }
          });
        } else if (state is RoleLoadSuccess) {
          setState(() {
            _roles = state.roles;
            if (!_defaultRoleSet && _roles.isNotEmpty) {
              _selectedRoleId ??= _roles.first.id;
              _defaultRoleSet = true;
              debugPrint('[Register] Default role selected: id=$_selectedRoleId (${_roles.first.roleCode})');
            }
          });
        } else if (state is RegisterSuccess) {
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
            debugPrint('[Register] buildWhen: ${prev.runtimeType} → ${curr.runtimeType}');
            return true;
          },
          builder: (context, state) {
            if (state is RegisterLoading && _depts.isEmpty && _roles.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // Use cached lists so we always have both dropdowns populated
            final depts = _depts;
            final roles = _roles;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                          child: _profileImage == null
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Department dropdown
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
                      validator: (_) => _selectedDeptId == null ? 'Please select one' : null,
                    ),

                    const SizedBox(height: 16),

                    // Role dropdown
                    DropdownButtonFormField<int>(
                      key: const ValueKey('role_dropdown'),
                      value: _selectedRoleId,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: roles.map((r) {
                        return DropdownMenuItem<int>(
                          value: r.id,
                          child: Text(r.roleCode.isEmpty ? 'Role ${r.id}' : r.roleCode),
                        );
                      }).toList(),
                      onChanged: (id) {
                        setState(() => _selectedRoleId = id);
                        debugPrint('[Register] Role changed → $_selectedRoleId');
                      },
                      validator: (_) => _selectedRoleId == null ? 'Please select one' : null,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _empIdCtrl,
                      decoration: const InputDecoration(labelText: 'Employee ID'),
                      validator: (v) => (v != null && v.isNotEmpty) ? null : 'Enter employee ID',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => (v != null && v.isNotEmpty) ? null : 'Enter name',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter email';
                        return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v) ? null : 'Invalid email';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) => (v != null && v.length >= 6) ? null : 'Min 6 chars',
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
