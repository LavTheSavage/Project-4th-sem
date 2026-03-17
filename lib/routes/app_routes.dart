// lib/routes/app_routes.dart
import 'package:flutter/material.dart';
import '../pages/my_rentals_page.dart';
import '../pages/my_listings_page.dart';
import '../pages/settings_page.dart';
import '../pages/about_us_page.dart';
import '../pages/profile_page.dart';
import '../pages/admin_dashboard_page.dart';
import '../pages/item_form_page.dart';

class AppRoutes {
  static const myRentals = '/myRentals';
  static const myListings = '/myListings';
  static const settings = '/settings';
  static const about = '/about';
  static const profile = '/profile';
  static const admin = '/admin';
  static const addItem = '/addItem';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = (settings.arguments as Map<String, dynamic>?) ?? {};
    final name = settings.name;

    if (name == myRentals) {
      return MaterialPageRoute(builder: (_) => const MyRentalsPage());
    } else if (name == myListings) {
      return MaterialPageRoute(
        builder: (_) => MyListingsPage(
          items: args['items'],
          currentUser: args['currentUser'],
          onDelete: args['onDelete'],
          onUpdate: args['onUpdate'],
        ),
      );
    } else if (name == addItem) {
      final categories = args['categories'] != null
          ? List<String>.from(args['categories'])
          : <String>[];

      return MaterialPageRoute(
        builder: (_) => ItemFormPage(
          categories: args['categories'],
          existingItem: args['existingItem'],
        ),
      );
    } else if (name == settings) {
      return MaterialPageRoute(builder: (_) => const SettingsPage());
    } else if (name == about) {
      return MaterialPageRoute(builder: (_) => const AboutUsPage());
    } else if (name == profile) {
      return MaterialPageRoute(builder: (_) => const ProfilePage());
    } else if (name == admin) {
      return MaterialPageRoute(builder: (_) => const AdminDashboardPage());
    } else {
      return MaterialPageRoute(
        builder: (_) =>
            const Scaffold(body: Center(child: Text('Page not found'))),
      );
    }
  }
}
