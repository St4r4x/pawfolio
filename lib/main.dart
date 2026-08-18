import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_router.dart';
import 'notifications/reminder_scheduler.dart';
import 'providers/theme_mode_provider.dart';
import 'supabase_config.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(SupabaseConfig.url.isNotEmpty, 'SUPABASE_URL must be passed via --dart-define');
  assert(SupabaseConfig.anonKey.isNotEmpty, 'SUPABASE_ANON_KEY must be passed via --dart-define');
  await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
  final scheduler = ReminderScheduler(FlutterLocalNotificationsPlugin());
  await scheduler.init();
  runApp(const ProviderScope(child: PawfolioApp()));
}

class PawfolioApp extends ConsumerWidget {
  const PawfolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Pawfolio',
      theme: pawfolioTheme,
      darkTheme: pawfolioDarkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
