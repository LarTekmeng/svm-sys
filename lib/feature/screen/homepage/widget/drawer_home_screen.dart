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
    // Delay until after first frame so `context` is safe for precacheImage
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Ensure the file exists in the disk cache (no network needed later)
        await AvatarCacheManager.instance.getSingleFile(url);
        if (!mounted) return;

        // Warm up memory cache for immediate display the first time
        await precacheImage(
          CachedNetworkImageProvider(
            url,
            cacheManager: AvatarCacheManager.instance,
          ),
          context,
        );
      } catch (_) {
        // Ignore prefetch failures; the UI will still fallback gracefully
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
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading profile: ${snapshot.error}'),
            );
          }
          final employee = snapshot.data!;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(employee),
              ..._buildMenuTiles(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(Employee e) {
    final ImageProvider avatarProvider = _avatarProvider(e);

    return DrawerHeader(
      decoration: const BoxDecoration(color: Color.fromRGBO(0, 105, 133, 1)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: avatarProvider,
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${e.employeeID}', style: _headerTextStyle),
              Text('Name: ${e.employeeName}', style: _headerTextStyle),
              Text('Dept: ${e.departmentName}', style: _headerTextStyle),
            ],
          ),
        ],
      ),
    );
  }

  // Choose a cached provider or a local placeholder — never hit the network on drawer open
  ImageProvider _avatarProvider(Employee e) {
    final url = e.profileImageUrl; // String? is OK
    if (url.trim().isNotEmpty) {
      return CachedNetworkImageProvider(
        url,
        cacheManager: AvatarCacheManager.instance,
      );
    }
    return const AssetImage('assets/images/user.png');
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
