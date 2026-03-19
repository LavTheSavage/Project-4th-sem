import 'package:flutter/material.dart';
import 'package:project/main.dart';
import 'package:project/pages/login_page.dart';
import 'package:project/pages/notification_page.dart';
import 'package:project/pages/search_page.dart';
import 'package:project/widgets/app_drawer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _userEmail;
  String? _userName;
  String? _avatarUrl;
  bool _isAdmin = false;
  bool _isBanned = false;
  RealtimeChannel? _itemsChannel;
  bool _isReloadingItems = false;
  bool _reloadQueued = false;
  String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;
  int _unreadNotifications = 0;
  String? _currentUserId;
  int _selectedIndex = 0;
  final List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  void _openAddItemPage() async {
    final result = await Navigator.pushNamed(
      context,
      '/addItem',
      arguments: {'categories': appCategories},
    );

    if (result != null && result is Map<String, dynamic>) {
      final newItem = Map<String, dynamic>.from(result)..remove('_persisted');
      setState(() {
        _items = [newItem, ..._items];
        _notifications.add({
          'title': "${newItem['name']} listed",
          'owner': _currentUserId ?? '',
          'timestamp': DateTime.now(),
        });
      });
    }
  }

  Future<void> _scheduleItemsReload() async {
    if (_isReloadingItems) {
      _reloadQueued = true;
      return;
    }

    _isReloadingItems = true;
    await _loadItems();
    _isReloadingItems = false;

    if (_reloadQueued) {
      _reloadQueued = false;
      await _scheduleItemsReload();
    }
  }

  void _listenToItemChanges() {
    _itemsChannel?.unsubscribe();

    final client = Supabase.instance.client;
    _itemsChannel = client
        .channel('public:items')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'items',
          callback: (payload) async => _scheduleItemsReload(),
        )
        .subscribe();
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _currentUserId = user.id;
    });

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        _userName = data['full_name'];
        _userEmail = data['email'];
        _avatarUrl = data['avatar_url'];
        final role = (data['role'] ?? '').toString().toLowerCase();
        _isAdmin = role == 'admin';
        _isBanned = data['is_banned'] == true;
      });
    } catch (e) {
      setState(() {
        _userName = user.userMetadata?['full_name'] ?? 'User';
        _userEmail = user.email;
        _avatarUrl = null;
        _isAdmin = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _loadItems();
    _listenToItemChanges();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
      _fetchUnreadCount();
    });

    MyAppStateNotifier.refresh = _fetchUnreadCount;
  }

  @override
  void dispose() {
    _itemsChannel?.unsubscribe();
    _itemsChannel = null;
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    final uid = currentUserId;
    if (uid == null) return;

    final res = await supabase
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .eq('handled', false);

    setState(() => _unreadNotifications = res.length);
  }

  Future<void> _loadItems() async {
    try {
      final data = await ItemService().fetchItems();
      if (!mounted) return;
      setState(() {
        _items = data;
      });
    } catch (e, st) {
      debugPrint('Failed to load items');
      debugPrint(e.toString());
      debugPrint(st.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteItem(int index) async {
    final id = _items[index]['id'];
    if (id == null) return;
    await supabase
        .from('items')
        .delete()
        .eq('id', id)
        .eq('owner_id', _currentUserId ?? '');
    if (mounted) setState(() => _items.removeAt(index));
  }

  Future<void> _updateItem(int index, Map<String, dynamic> updated) async {
    final id = _items[index]['id'];
    final alreadyPersisted = updated['_persisted'] == true;

    final Map<String, dynamic> payload = {};

    void addIfChanged(String key) {
      if (updated.containsKey(key)) {
        payload[key] = updated[key];
      }
    }

    addIfChanged('name');
    addIfChanged('price');
    addIfChanged('category');
    addIfChanged('condition');
    addIfChanged('location');
    addIfChanged('description');
    addIfChanged('status');
    addIfChanged('favorite');

    if (updated.containsKey('images')) {
      final raw = updated['images'];

      if (raw is List && raw.isNotEmpty) {
        payload['images'] = raw;
      } else if (raw is String && raw.isNotEmpty) {
        payload['images'] = [raw];
      } else if (raw is List && raw.isEmpty) {
        payload['images'] = raw;
      }
    }

    if (payload.isEmpty) return;

    if (!alreadyPersisted) {
      await supabase.from('items').update(payload).eq('id', id);
    }

    setState(() {
      if (alreadyPersisted) {
        final localItem = Map<String, dynamic>.from(updated)
          ..remove('_persisted');
        _items[index] = {..._items[index], ...localItem};
      } else {
        _items[index] = {..._items[index], ...payload};
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0) {
      if (_items.isEmpty) {
        setState(() => _loading = true);
        _loadItems();
      }
      _listenToItemChanges();
    } else {
      _itemsChannel?.unsubscribe();
      _itemsChannel = null;
    }
  }

  void _openProfilePage() {
    Navigator.pushNamed(context, '/profile');
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();

              if (context.mounted) Navigator.pop(context);

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginPage(client: supabase),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Samyog Rai ko Project',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      drawer: AppDrawer(
        userName: _userName,
        email: _userEmail,
        avatarUrl: _avatarUrl,
        onLogout: _logout,
        onProfileTap: _openProfilePage,
        isAdmin: _isAdmin,
        items: _items,
        currentUser: currentUserId,
        onDelete: (index) => _deleteItem(index),
        onUpdate: (index, data) => _updateItem(index, data),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF1E88E5),
        unselectedItemColor: Colors.grey.shade500,
        selectedFontSize: 13,
        unselectedFontSize: 12,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotifications > 99
                            ? '99+'
                            : '$_unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notification',
          ),
        ],
      ),
      body: _isBanned
          ? Center(
              child: Text(
                "🚫 Your account has been banned.\nContact admin.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
            )
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SearchPage(
                        items: _items,
                        categories: appCategories,
                        onUpdate: _updateItem,
                        onDelete: _deleteItem,
                        currentUser: currentUserId,
                      ),
                const NotificationsPage(),
              ],
            ),
      floatingActionButton: _isBanned
          ? null
          : FloatingActionButton(
              onPressed: _openAddItemPage,
              backgroundColor: const Color(0xFFFFC107),
              child: const Icon(Icons.add, color: Colors.black),
            ),
    );
  }
}
