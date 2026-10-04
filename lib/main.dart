import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api_config.dart';
import 'providers/auth_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/settings/server_settings_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await ApiConfig.instance.load();
  await NotificationService.instance.init();
  runApp(const GeoTaniApp());
}

class GeoTaniApp extends StatelessWidget {
  const GeoTaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'GeoTani',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: const _RootScreen(),
      ),
    );
  }
}

/// Menentukan layar awal: kalau alamat server belum diisi -> ServerSettings,
/// kalau sudah -> coba auto-login pakai token tersimpan (bisa gagal kalau
/// token kedaluwarsa/server tidak bisa dihubungi), baru putuskan Home/Login.
class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (ApiConfig.instance.isConfigured) {
      try {
        await context.read<AuthProvider>().tryAutoLogin().timeout(const Duration(seconds: 15));
      } catch (_) {
        // Server tidak terjangkau / timeout: jangan tertahan di spinner,
        // tampilkan LoginScreen (token tetap disimpan untuk percobaan berikutnya).
      }
    }
    if (mounted) setState(() => _checkingAuth = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.instance.isConfigured) {
      return ServerSettingsScreen(
        onSaved: () {
          setState(() => _checkingAuth = true);
          _bootstrap();
        },
      );
    }
    if (_checkingAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
