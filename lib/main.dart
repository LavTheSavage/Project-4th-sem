import 'dart:async';
import 'package:flutter/material.dart';
import 'package:project/pages/auth_gate.dart';
import 'package:project/routes/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

const List<String> appCategories = [
  'All',
  'Electronics',
  'Appliances',
  'Tools',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://orfcnqyvcxphfgfxsvrm.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9yZmNucXl2Y3hwaGZnZnhzdnJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzNzQ3MTUsImV4cCI6MjA4MDk1MDcxNX0.gox9lzfQEF-TOyWMLdZtw85iIUE1__Du88kDCZ43Ap4',
  );
  runApp(const MyAppRoot());
}

class MyAppRoot extends StatelessWidget {
  const MyAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(secondary: const Color(0xFFFFC107)),
        primaryColor: const Color(0xFF1E88E5),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E88E5),
          foregroundColor: Color(0xFFFFFFFF),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFFC107),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF263238)),
          bodyMedium: TextStyle(color: Color(0xFF263238)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF90CAF9),
          disabledColor: Colors.grey.shade300,
          selectedColor: const Color(0xFF1E88E5),
          secondarySelectedColor: const Color(0xFF1E88E5),
          labelStyle: const TextStyle(color: Color(0xFF263238)),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          brightness: Brightness.light,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

class MyAppStateNotifier {
  static VoidCallback? refresh;
}

class ItemService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String itemSelect = '''
          *,
          owner:profiles (
            id,
            full_name,
            avatar_url
          ),
          bookings(
          id,
          status,
          from_date,
          to_date
          )
        ''';

  Future<List<Map<String, dynamic>>> fetchItems() async {
    try {
      final res = await _client
          .from('items')
          .select(itemSelect)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res);
    } catch (e, st) {
      debugPrint('❌ fetchItems failed');
      debugPrint(e.toString());
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addItem(Map<String, dynamic> item) async {
    final user = _client.auth.currentUser!;
    final userProfile = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .single();

    final rawImages = item['images'];

    final inserted = await _client
        .from('items')
        .insert({
          ...item,
          'images': rawImages is List
              ? rawImages
              : rawImages is String
              ? [rawImages]
              : [],
          'owner_id': user.id,
          'owner_name': userProfile['full_name'],
        })
        .select(itemSelect)
        .single();

    return Map<String, dynamic>.from(inserted);
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    return await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }
}
