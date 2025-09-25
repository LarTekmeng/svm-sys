import 'package:cached_network_image/cached_network_image.dart';
import 'package:online_doc_savimex/app_import.dart';

import 'avatar_cache_manager.dart';

class DrawerHomeScreen extends StatefulWidget {
  final String employeeID;
  const DrawerHomeScreen({super.key, required this.employeeID});

  @override
  State<DrawerHomeScreen> createState() => _DrawerHomeScreenState();
}

class _DrawerHomeScreenState extends State<DrawerHomeScreen> {
  late Future<Employee> _employee;
  late final AuthRepository _authRepo;
  late final EmployeeRepository _employeeRepo;

  @override
  void initState() {
    super.initState();
    _authRepo = context.read<AuthRepository>();
    _employeeRepo = context.read<EmployeeRepository>();

    // Fetch employee once, and prefetch avatar into disk cache so the drawer is instant
    _employee = _employeeRepo.fetchEmployeeByID(widget.employeeID).then((e) {
      final url = e.profileImageUrl;
      if (url.trim().isNotEmpty) {
        _prefetchAvatar(url);
      }
      return e;
    });
  }

  // Download to cache and pre-cache into memory for a snappy first paint
  void _prefetchAvatar(String url) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AvatarCacheManager.instance.getSingleFile(url);
        if (!mounted) return;
        await precacheImage(
          CachedNetworkImageProvider(
            url,
            cacheManager: AvatarCacheManager.instance,
          ),
          context,
        );
      } catch (_) {
        // ignore
      }
    });
  }

  void _onLogout() async {
    await _authRepo.logout();
    // ignore: use_build_context_synchronously
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color.fromRGBO(0, 105, 133, 1),
      child: FutureBuilder<Employee>(
        future: _employee,
        builder: (context, snapshot) {
          // We ALWAYS render the header & tiles.
          // If loading or error, we pass null so the header shows INVALID & broken image.
          final Employee? employee = snapshot.data;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeaderSafe(employee),
              ..._buildMenuTiles(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderSafe(Employee? e) {
    final id = _safeText(e?.employeeID);
    final name = _safeText(e?.employeeName);
    final dept = _safeText(e?.departmentName);

    return DrawerHeader(
      decoration: const BoxDecoration(color: Color.fromRGBO(0, 105, 133, 1)),
      child: Row(
        children: [
          _avatarSafe(e?.profileImageUrl),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: $id', style: _headerTextStyle),
              Text('Name: $name', style: _headerTextStyle),
              Text('Dept: $dept', style: _headerTextStyle),
            ],
          ),
        ],
      ),
    );
  }

  // "INVALID" if null/empty/whitespace
  String _safeText(String? s) {
    if (s == null) return 'INVALID';
    final t = s.trim();
    return t.isEmpty ? 'INVALID' : t;
  }

  // Broken-image indicator on failure, cached avatar on success
  Widget _avatarSafe(String? url) {
    final trimmed = (url ?? '').trim();
    if (trimmed.isEmpty) {
      return const CircleAvatar(
        radius: 30,
        child: Icon(Icons.broken_image, color: Colors.white),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: trimmed,
        cacheManager: AvatarCacheManager.instance,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => const SizedBox(
          width: 60,
          height: 60,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => const SizedBox(
          width: 60,
          height: 60,
          child: CircleAvatar(
            radius: 30,
            child: Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuTiles() {
    return [
      _drawerTile(Icons.category, 'Document Type', () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentTypeScreen(employeeID: widget.employeeID),
          ),
        );
      }),
      _drawerTile(Icons.logout, 'Logout', _onLogout),
    ];
  }

  TextStyle get _headerTextStyle => const TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
      onTap: onTap,
    );
  }
}
