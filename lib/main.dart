import 'package:online_doc_savimex/feature/presentation/splash_screen.dart';
import 'package:online_doc_savimex/feature/repositories/profile_repo.dart';
import 'package:online_doc_savimex/feature/service/device_info.dart';
import 'app_import.dart';

// If NOT exported by app_import.dart, uncomment this explicit import:
// import 'package:online_doc_savimex/feature/data/repository/document_repo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final baseUrl = await ApiHost.resolve();
  final authRepo = await AuthRepository.create();
  await authRepo.init();

  final departmentRepo = DepartmentRepository(baseUrl: baseUrl);
  final employeeRepo   = EmployeeRepository(baseUrl: baseUrl, authRepo: authRepo);
  final doctypeRepo    = DoctypeRepository(baseUrl: baseUrl, authRepo: authRepo, empRepo: employeeRepo, deptRepo: departmentRepo);
  final homeRepo       = HomeRepo(baseUrl: baseUrl, authRepo: authRepo );
  final documentRepo = DocumentRepository(baseUrl: baseUrl, authRepo: authRepo);
  final profileRepo = ProfileRepo(baseUrl: baseUrl, authRepo: authRepo);
  final roleRepo = RoleRepository(baseUrl: baseUrl);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepo),
        RepositoryProvider<DepartmentRepository>.value(value: departmentRepo),
        RepositoryProvider<EmployeeRepository>.value(value: employeeRepo),
        RepositoryProvider<DoctypeRepository>.value(value: doctypeRepo),
        RepositoryProvider<HomeRepo>.value(value: homeRepo),
        RepositoryProvider<DocumentRepository>.value(value: documentRepo),
        RepositoryProvider<ProfileRepo>.value(value: profileRepo,),
        RepositoryProvider<RoleRepository>.value(value: roleRepo,),
      ],
      child: MultiBlocProvider(
        providers: [
          // Registration Bloc (loads departments up-front)
          BlocProvider<RegisterBloc>(
            create: (ctx) => RegisterBloc(
              depRepo: ctx.read<DepartmentRepository>(),
              authRepo: ctx.read<AuthRepository>(),
              roleRepo: ctx.read<RoleRepository>(),
              employeeRepo: ctx.read<EmployeeRepository>(),
            )..add(LoadDepartments()),
          ),
          BlocProvider<AuthLoginBloc>(
            create: (ctx) => AuthLoginBloc(ctx.read<AuthRepository>())..add(AppStarted()),
          ),
          BlocProvider<HomeBloc>(
            create: (ctx) => HomeBloc(homeRepo: ctx.read<HomeRepo>())
              ..add(const HomeStarted()),
          ),
          BlocProvider<UploadBloc>(
            create: (ctx) => UploadBloc(
              documentRepo: ctx.read<DocumentRepository>(),
              homeBloc: ctx.read<HomeBloc>(), // <-- cross-bloc reference
            ),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) {
          final employee = ModalRoute.of(context)!.settings.arguments as Employee?;

          // 🔍 Debug log
          print('🔍 ROUTE /home - Employee: ${employee?.employeeID} - ${employee?.employeeName}');

          if (employee == null) {  // ✅ FIXED: Using == for comparison (was: employee = null)
            print('🔍 ROUTE /home - No employee, redirecting to login');
            return const LoginScreen();
          }

          return Homescreen(employeeID: employee.employeeID);  // ✅ Correct property name
        }
      },
    );
  }
}
