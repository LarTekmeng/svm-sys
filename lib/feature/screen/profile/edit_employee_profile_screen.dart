import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:online_doc_savimex/app_import.dart';
import '../../bloc/editBLoC/edit_profile_bloc.dart';
import '../../bloc/editBLoC/edit_profile_event.dart';
import '../../repositories/profile_repo.dart';
import 'change_password_screen.dart';
import 'package:flutter/painting.dart' as painting;
import '../homepage/widget/avatar_cache_manager.dart';

class EditEmployeeProfileScreen extends StatefulWidget {
  final ProfileRepo repo;
  final String initialName;
  final String initialEmail;
  final int? initialDepartmentId;
  final List<Map<String, dynamic>> departments; // [{id:1, name:'HR'}, ...]

  const EditEmployeeProfileScreen({
    super.key,
    required this.repo,
    required this.initialName,
    required this.initialEmail,
    required this.initialDepartmentId,
    required this.departments,
  });

  @override
  State<EditEmployeeProfileScreen> createState() => _EditEmployeeProfileScreenState();
}

class _EditEmployeeProfileScreenState extends State<EditEmployeeProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  int? _deptId;
  File? _pickedImageFile;
  bool _saving = false;
  List<Map<String, dynamic>> _departments = const [];

  // safe helper (no maybeOf)
  EmployeeProfileBloc? _blocOrNull(BuildContext context) {
    try {
      return context.read<EmployeeProfileBloc>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _email = TextEditingController(text: widget.initialEmail);
    _deptId = widget.initialDepartmentId;
    if (widget.departments.isEmpty) {
      _loadDepartments();
    } else {
      _departments = widget.departments;
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final deptRepo = context.read<DepartmentRepository>(); // your repo
      // Expecting a list of Department models: map -> {id,name}
      final items = await deptRepo.fetchDepartments(); // method name in your repo
      setState(() {
        _departments = items
            .map<Map<String, dynamic>>((d) => {'id': d.id, 'name': d.name})
            .toList();
      });
    } catch (e) {
      // optional: show a snack; keeping UI unchanged
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load departments')));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _pickedImageFile = File(x.path));
  }

  // Evict any stale avatar from cache (custom + default), so Drawer updates instantly
// Evict avatar everywhere: custom cache, default cache, and in-memory image cache.
  Future<void> _evictAvatarCache(String employeeId, [String? imageUrl]) async {
    // 1) Your custom cache (uses the stable cacheKey)
    try {
      await AvatarCacheManager.instance.removeFile('avatar:$employeeId');
    } catch (_) {}

    // 2) Also try removing by URL key (some code paths use URL as key)
    try {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await AvatarCacheManager.instance.removeFile(imageUrl);
      }
    } catch (_) {}

    // 3) CachedNetworkImage default cache, just in case
    try {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(imageUrl);
        await DefaultCacheManager().removeFile(imageUrl);
      }
    } catch (_) {}

    // 4) Purge Flutter's in-memory image cache so the new frame can't reuse old pixels
    try {
      painting.imageCache.clear();           // disk->memory purge
      painting.imageCache.clearLiveImages(); // purge images currently referenced by widgets
    } catch (_) {}
  }



  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // 1) Update on server (unchanged)
      await widget.repo.updateProfile(
        employeeName: _name.text.trim(),
        email: _email.text.trim(),
        departmentId: _deptId,
        avatarFile: _pickedImageFile, // null if unchanged
      );

      // 2) Re-fetch myself by id (avoid /me 404)
      final profileBloc = context.read<EmployeeProfileBloc>();
      final myId = profileBloc.state.employee?.employeeID ?? '';
      final empRepo = context.read<EmployeeRepository>();
      final me = await empRepo.fetchEmployeeByID(myId);

      // 3) Bust cache + update bloc so Drawer refreshes instantly
      await _evictAvatarCache(me.employeeID, me.profileImageUrl);
      profileBloc.add(EmployeeProfileUpdatedLocally(me));
      profileBloc.add(const EmployeeProfileRefreshRequested());

      // 4) Navigate back to Home (unchanged flow)
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => Homescreen(employeeID: me.employeeID)),
            (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar (UNCHANGED)
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 44,
                    backgroundImage: _pickedImageFile != null ? FileImage(_pickedImageFile!) : null,
                    child: _pickedImageFile == null ? const Icon(Icons.camera_alt) : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name (UNCHANGED)
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              // Email (UNCHANGED)
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Email is required';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Department (UNCHANGED)
              DropdownButtonFormField<int>(
                initialValue: _deptId, // keep your current value binding
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Department'),
                items: (_departments.isNotEmpty ? _departments : widget.departments)
                    .map((m) => DropdownMenuItem<int>(
                  value: m['id'] as int,
                  child: Text(m['name'] as String),
                ))
                    .toList(),
                onChanged: (v) => setState(() => _deptId = v),
                validator: (v) => v == null ? 'Please select a department' : null,
              ),
              const SizedBox(height: 24),

              // Save button (UNCHANGED)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving…' : 'Save'),
                  onPressed: _saving ? null : _onSave,
                ),
              ),

              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.lock),
                label: const Text('Change password'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChangePasswordScreen(repo: widget.repo)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
