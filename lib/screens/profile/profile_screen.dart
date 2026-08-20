import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/theme_mode_provider.dart';
import '../../theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            color: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pets, color: Colors.white, size: 36),
                const SizedBox(height: 12),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Thème', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Système'),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (mode) =>
                ref.read(themeModeProvider.notifier).setThemeMode(mode!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Clair'),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (mode) =>
                ref.read(themeModeProvider.notifier).setThemeMode(mode!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Sombre'),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (mode) =>
                ref.read(themeModeProvider.notifier).setThemeMode(mode!),
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
