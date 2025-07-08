import 'package:online_doc_savimex/feature/presentation/splash_screen.dart';

import 'app_import.dart';

void main() {
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => AuthRepository()),
        RepositoryProvider<DepartmentRepository>(
          create: (_) => DepartmentRepository(),
        ),
        RepositoryProvider<EmployeeRepository>(
          create: (_) => EmployeeRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          // Registration Bloc (loads departments up-front)
          BlocProvider<RegisterBloc>(
            create:
                (ctx) => RegisterBloc(
                  depRepo: ctx.read<DepartmentRepository>(),
                  authRepo: ctx.read<AuthRepository>(),
                )..add(LoadDepartments()),
          ),
          BlocProvider<AuthLoginBloc>(
            create:
                (ctx) =>
                    AuthLoginBloc(ctx.read<AuthRepository>(),)
                      ..add(AppStarted()),
          ),

          // (You can add other Blocs here, e.g. AuthBloc, EmployeeBloc, etc.)
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
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) {
          final employee =
              ModalRoute.of(context)!.settings.arguments as Employee;
          return Homescreen(employeeID: employee.employeeID);
        },
      },
    );
  }
}
