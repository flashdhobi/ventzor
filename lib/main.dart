import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ventzor/clients/clients_setup.dart';
import 'package:ventzor/firebase_options.dart';
import 'package:ventzor/intro/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ventzor/setup/org_setup.dart';
import 'package:ventzor/setup/pns_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VentzorApp());
}

class VentzorApp extends StatelessWidget {
  const VentzorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ventzor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
        textTheme: GoogleFonts.quicksandTextTheme(Theme.of(context).textTheme),
      ),
      home: const SplashScreen(),
      routes: {
        // other routes...
        '/organizationSetup': (context) => const OrganizationSetupPage(),
        '/productServiceSetup': (context) => const ProductsServicesSetupPage(),
        '/clients': (context) => const ClientsScreen(),
      },
    );
  }
}
