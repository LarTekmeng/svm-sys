import 'package:cached_network_image/cached_network_image.dart';
import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/screen/profile/edit_employee_profile_screen.dart';
import '../../../bloc/editBLoC/edit_profile_bloc.dart';
import '../../../repositories/profile_repo.dart';
import 'avatar_cache_manager.dart';

class DrawerHomeScreen extends StatelessWidget {
  final Employee? employee; // <- data comes from parent
  const DrawerHomeScreen({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color.fromRGBO(0, 105, 133, 1),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(employee: employee),

          // === keep your existing tiles below unchanged ===
          _drawerTile(
            context,
            Icons.category,
            'Document Type',
                () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentTypeScreen(employeeID: employee?.employeeID ?? ''),
                ),
              );
            },
          ),
          _drawerTile(
            context,
            Icons.home,
            'Department',
                () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentTypeScreen(employeeID: employee?.employeeID ?? ''),
                ),
              );
            },
          ),
          _drawerTile(
            context,
            Icons.person,
            'Employee',
                () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentTypeScreen(employeeID: employee?.employeeID ?? ''),
                ),
              );
            },
          ),
          _drawerTile(
            context,
            Icons.logout,
            'Logout',
                () async {
              final authRepo = context.read<AuthRepository>();
              await authRepo.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(BuildContext ctx, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(fontSize: 16, color: Colors.white)),
      onTap: onTap,
    );
  }
}

class _Header extends StatelessWidget {
  final Employee? employee;
  const _Header({required this.employee});

  @override
  Widget build(BuildContext context) {
    final id   = _safeText(employee?.employeeID);
    final name = _safeText(employee?.employeeName);
    final dept = _safeText(employee?.departmentName);

    return DrawerHeader(
      decoration: const BoxDecoration(color: Color.fromRGBO(0, 105, 133, 1)),
      child: Row(
        children: [
          _avatar(employee, context), // <— tap avatar to edit profile
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: $id',   style: _headerTextStyle),
              Text('Name: $name', style: _headerTextStyle),
              Text('Dept: $dept', style: _headerTextStyle),
            ],
          ),
        ],
      ),
    );
  }

  static TextStyle get _headerTextStyle => const TextStyle(
    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600,
  );

  String _safeText(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? '—' : t;
  }

  // -----------------------------
  // Avatar + navigation to EDIT
  // -----------------------------
  Widget _avatar(Employee? e, BuildContext context) {
    final url = (e?.profileImageUrl ?? '').trim();
    final cacheKey = 'avatar:${e?.employeeID ?? 'unknown'}';
    if (url.isEmpty) {
      return GestureDetector(
        onTap: () => _openEdit(context, e),
        child: const CircleAvatar(radius: 30, child: Icon(Icons.person)),
      );
    }
    return GestureDetector(
      onTap: () => _openEdit(context, e),        // <— navigate
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          cacheManager: AvatarCacheManager.instance,
          cacheKey: cacheKey,                // stable key ties to employee
          useOldImageOnUrlChange: true,      // keep previous image visible
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 120),
          placeholder: (_, __) => const SizedBox(
            width: 60, height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (_, __, ___) =>
          const CircleAvatar(radius: 30, child: Icon(Icons.person_off)),
        ),
      ),
    );
  }
  Future<void> _openEdit(BuildContext context, Employee? e) async {
    if (e == null) return;

    final profileRepo = context.read<ProfileRepo>();
    // ⬇️ capture the *existing* bloc from Homescreen’s scope
    final profileBloc = context.read<EmployeeProfileBloc>();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: profileBloc, // <-- provide the SAME bloc instance to the new route
          child: EditEmployeeProfileScreen(
            repo: profileRepo,
            initialName: e.employeeName,
            initialEmail: e.email,
            initialDepartmentId: e.departmentID,
            // you can keep your normalized list OR pass [] and let the screen load
            departments: const <Map<String, dynamic>>[],
          ),
        ),
      ),
    );
  }

}
