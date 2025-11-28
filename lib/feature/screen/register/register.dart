import 'dart:io';
import 'dart:developer' as dev;
import 'package:online_doc_savimex/app_import.dart';

class RegisterScreen extends StatefulWidget {
  final Employee? employeeToEdit; // null = create mode, not null = edit mode
  final String? currentEmployeeId;

  const RegisterScreen({super.key, this.employeeToEdit, this.currentEmployeeId});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _empIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  File? _profileImage;
  int? _selectedDeptId;
  int? _selectedRoleId;

  bool _defaultDeptSet = false;
  bool _defaultRoleSet = false;

  // Caches so we don't lose data on state switches
  List<Department> _depts = [];
  List<Role> _roles = [];

  bool get isEditMode => widget.employeeToEdit != null;

  @override
  void initState() {
    super.initState();

    // If editing, pre-fill the form with existing data
    if (isEditMode) {
      final emp = widget.employeeToEdit!;
      _empIdCtrl.text = emp.employeeID;
      _nameCtrl.text = emp.employeeName;
      _emailCtrl.text = emp.email;
      _selectedDeptId = emp.departmentID;
      _selectedRoleId = emp.roleId;
      debugPrint('[Register] Edit mode: pre-filled data for employee ${emp.id}');
    }

    debugPrint('[Register] initState() → dispatch LoadDepartments & LoadRoles');
    try {
      final bloc = context.read<RegisterBloc>();
      bloc.add(LoadDepartments());
      bloc.add(LoadRoles());
    } catch (e, st) {
      dev.log(
        '[Register] ERROR dispatching initial loads',
        error: e,
        stackTrace: st,
      );
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

  void _onSave() {
    _onSubmit(createNew: false);
  }

  void _onSaveNew() {
    _onSubmit(createNew: true);
  }

  void _onSubmit({required bool createNew}) {
    debugPrint('[Register] _onSubmit() pressed');
    if (!_formKey.currentState!.validate()) {
      debugPrint('[Register] Form invalid → abort submit');
      return;
    }
    if (_selectedDeptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department')),
      );
      return;
    }
    if (_selectedRoleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role')),
      );
      return;
    }

    final masked = '*' * _passCtrl.text.length;

    dev.log(
      isEditMode ? '[Register] Dispatch UpdateEmployeeRequested' : '[Register] Dispatch RegisterRequested',
      name: 'register.submit',
      error: {
        'mode': isEditMode ? 'edit' : 'create',
        'id': isEditMode ? widget.employeeToEdit!.id : null,
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'passwordLen': masked.length,
        'departmentId': _selectedDeptId,
        'roleId': _selectedRoleId,
        'employeeId': _empIdCtrl.text.trim(),
        'hasImage': _profileImage != null,
      },
    );

    try {
      if (isEditMode) {
        // UPDATE existing employee
        context.read<RegisterBloc>().add(
          UpdateEmployeeRequested(
            employeeId: widget.employeeToEdit!.id!,
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text.isEmpty ? null : _passCtrl.text,
            departmentId: _selectedDeptId!,
            empId: _empIdCtrl.text.trim(),
            roleId: _selectedRoleId,
            profileImage: _profileImage,
          ),
        );
      } else {
        // CREATE new employee
        context.read<RegisterBloc>().add(
          RegisterRequested(
            _nameCtrl.text.trim(),
            _emailCtrl.text.trim(),
            _passCtrl.text,
            _selectedDeptId!,
            _empIdCtrl.text.trim(),
            roleId: _selectedRoleId,
            profileImage: _profileImage,
            createNew: createNew,
          ),
        );
      }
    } catch (e, st) {
      dev.log(
        '[Register] ERROR dispatching event',
        error: e,
        stackTrace: st,
      );
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
            if (!_defaultDeptSet && _depts.isNotEmpty && !isEditMode) {
              _selectedDeptId ??= _depts.first.id;
              _defaultDeptSet = true;
              debugPrint(
                '[Register] Default dept selected: id=$_selectedDeptId (${_depts.first.name})',
              );
            }
          });
        } else if (state is RoleLoadSuccess) {
          setState(() {
            _roles = state.roles;
            if (!_defaultRoleSet && _roles.isNotEmpty && !isEditMode) {
              _selectedRoleId ??= _roles.first.id;
              _defaultRoleSet = true;
              debugPrint(
                '[Register] Default role selected: id=$_selectedRoleId (${_roles.first.roleCode})',
              );
            }
          });
        } else if (state is UpdateEmployeeSuccess) {
          debugPrint('[Register] UpdateEmployeeSuccess → pop back');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employee updated successfully')),
          );
          Navigator.pop(context, true); // Return to previous screen
        } else if (state is RegisterSuccess) {
          debugPrint('[Register] RegisterSuccess → go to Home');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => Homescreen(employeeID: widget.currentEmployeeId ?? _empIdCtrl.text),
            ),
          );
        } else if (state is RegisterSuccessNew) {
          _nameCtrl.clear();
          _emailCtrl.clear();
          _passCtrl.clear();
          _empIdCtrl.clear();
          setState(() {
            _selectedDeptId = null;
            _selectedRoleId = null;
            _profileImage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Created, You can create new Employee"),
            ),
          );
        } else if (state is RegisterFailure) {
          dev.log('[Register] RegisterFailure', error: state.error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditMode ? 'Edit Employee' : 'Create new employee'),
        ),
        body: BlocBuilder<RegisterBloc, RegisterState>(
          buildWhen: (prev, curr) {
            debugPrint(
              '[Register] buildWhen: ${prev.runtimeType} → ${curr.runtimeType}',
            );
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
                    // Profile Image
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : (isEditMode && widget.employeeToEdit!.profileImageUrl.isNotEmpty)
                                  ? NetworkImage(widget.employeeToEdit!.profileImageUrl)
                                  : null,
                              child: (_profileImage == null &&
                                  (!isEditMode || widget.employeeToEdit!.profileImageUrl.isEmpty))
                                  ? const Icon(Icons.person, size: 48)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.blue,
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Department dropdown
                    DropdownButtonFormField<int>(
                      key: const ValueKey('dept_dropdown'),
                      initialValue: _selectedDeptId,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                      ),
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

                    // Role dropdown
                    DropdownButtonFormField<int>(
                      key: const ValueKey('role_dropdown'),
                      initialValue: _selectedRoleId,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: roles.map((r) {
                        return DropdownMenuItem<int>(
                          value: r.id,
                          child: Text(
                            r.roleCode.isEmpty ? 'Role ${r.id}' : r.roleCode,
                          ),
                        );
                      }).toList(),
                      onChanged: (id) {
                        setState(() => _selectedRoleId = id);
                        debugPrint('[Register] Role changed → $_selectedRoleId');
                      },
                      validator: (_) =>
                      _selectedRoleId == null ? 'Please select one' : null,
                    ),

                    const SizedBox(height: 16),

                    // Employee ID
                    TextFormField(
                      controller: _empIdCtrl,
                      decoration: InputDecoration(
                        labelText: 'Employee ID',
                        border: const OutlineInputBorder(),
                        suffixIcon: isEditMode
                            ? const Icon(Icons.lock, size: 16)
                            : null,
                      ),
                      enabled: !isEditMode, // Disabled in edit mode
                      style: isEditMode
                          ? TextStyle(color: Colors.grey[600])
                          : null,
                      validator: (v) =>
                      (v != null && v.isNotEmpty) ? null : 'Enter employee ID',
                    ),

                    const SizedBox(height: 16),

                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                      (v != null && v.isNotEmpty) ? null : 'Enter name',
                    ),

                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter email';
                        return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)
                            ? null
                            : 'Invalid email';
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passCtrl,
                      decoration: InputDecoration(
                        labelText: isEditMode
                            ? 'New Password (leave empty to keep current)'
                            : 'Password',
                        border: const OutlineInputBorder(),
                        helperText: isEditMode
                            ? 'Only fill if you want to change password'
                            : null,
                      ),
                      obscureText: true,
                      validator: (v) {
                        if (isEditMode) {
                          // In edit mode, password is optional
                          if (v != null && v.isNotEmpty && v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        } else {
                          // In create mode, password is required
                          return (v != null && v.length >= 6)
                              ? null
                              : 'Min 6 chars';
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    if (isEditMode)
                    // Edit mode: only show Update button
                      ElevatedButton.icon(
                        onPressed: state is RegisterLoading ? null : _onSave,
                        icon: state is RegisterLoading
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.save),
                        label: Text(
                          state is RegisterLoading ? 'Updating...' : 'Update Employee',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      )
                    else
                    // Create mode: show both buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Expanded(
                          //   child: ElevatedButton(
                          //     onPressed: state is RegisterLoading ? null : _onSave,
                          //     child: const Text('Save'),
                          //   ),
                          // ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: state is RegisterLoading ? null : _onSaveNew,
                              child: const Text('Save/Create New'),
                            ),
                          ),
                        ],
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

