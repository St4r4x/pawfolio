import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/theme_mode_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.email), title: Text(email)),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Thème', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Système'),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Clair'),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Sombre'),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode!),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Se déconnecter'),
            onTap: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
    );
  }
}
