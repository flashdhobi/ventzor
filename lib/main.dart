import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ventzor/clients/clients_setup.dart';
import 'package:ventzor/firebase_options.dart';
import 'package:ventzor/intro/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ventzor/miscscreens/delete_account.dart';
import 'package:ventzor/miscscreens/html_viewer.dart';
import 'package:ventzor/services/client_service.dart';
import 'package:ventzor/services/event_service.dart';
import 'package:ventzor/services/invoice_service.dart';
import 'package:ventzor/services/job_service.dart';
import 'package:ventzor/services/pns_service.dart';
import 'package:ventzor/services/quote_service.dart';
import 'package:ventzor/setup/org_setup.dart';
import 'package:ventzor/setup/pns_setup.dart';

class RouteNames {
  static const String splash = '/';
  static const String orgSetup = '/organizationSetup';
  static const String pnsSetup = '/productServiceSetup';
  static const String clients = '/clients';
  static const String deleteAccount = '/deleteaccount';
  static const String privacy = '/privacy';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const VentzorApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Failed to initialize app: $e')),
        ),
      ),
    );
  }
}

class VentzorApp extends StatelessWidget {
  const VentzorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => InvoiceRepository()),
        Provider(create: (_) => EventRepository()),
        Provider(create: (_) => JobRepository()),
        Provider(create: (_) => QuoteRepository()),
        Provider(create: (_) => ClientRepository()),
        Provider(create: (_) => PnSRepository()),
      ],
      child: MaterialApp(
        title: 'Ventzor',
        debugShowCheckedModeBanner: false,
        theme: _buildAppTheme(context),

        // Remove initialRoute
        // initialRoute: RouteNames.splash,
        onGenerateInitialRoutes: (initialRouteName) {
          debugPrint('Initial Route: $initialRouteName');

          // Handle deep link routing first
          switch (initialRouteName) {
            case RouteNames.deleteAccount:
              return [
                MaterialPageRoute(builder: (_) => const DeleteAccountPage()),
              ];
            case RouteNames.privacy:
              return [
                MaterialPageRoute(
                  builder: (_) => LocalHtmlViewer(
                    filePath: 'assets/html/privacy_policy.html',
                    screenTitle: 'Privacy Policy',
                  ),
                ),
              ];
            case RouteNames.orgSetup:
              return [
                MaterialPageRoute(
                  builder: (_) => const OrganizationSetupPage(),
                ),
              ];
            case RouteNames.pnsSetup:
              return [
                MaterialPageRoute(
                  builder: (_) => const ProductsServicesSetupPage(),
                ),
              ];
            case RouteNames.clients:
              return [MaterialPageRoute(builder: (_) => const ClientsScreen())];
            default:
              // Fallback to splash
              return [MaterialPageRoute(builder: (_) => const SplashScreen())];
          }
        },

        routes: {
          RouteNames.splash: (context) => const SplashScreen(),
          RouteNames.deleteAccount: (context) => const DeleteAccountPage(),
          RouteNames.privacy: (context) => LocalHtmlViewer(
            filePath: 'assets/html/privacy_policy.html',
            screenTitle: 'Privacy Policy',
          ),
          RouteNames.orgSetup: (context) => const OrganizationSetupPage(),
          RouteNames.pnsSetup: (context) => const ProductsServicesSetupPage(),
          RouteNames.clients: (context) => const ClientsScreen(),
        },
      ),
    );
  }

  ThemeData _buildAppTheme(BuildContext context) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      useMaterial3: true,
      textTheme: GoogleFonts.quicksandTextTheme(Theme.of(context).textTheme),
    );
  }
}
