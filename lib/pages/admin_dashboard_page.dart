import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  final ValueNotifier<bool> darkMode = ValueNotifier(false);
  final TextEditingController _searchController = TextEditingController();

  List users = [];
  List items = [];
  int _selectedTab = 0;
  String _searchQuery = '';

  static const List<String> _tabTitles = [
    'Overview',
    'Users',
    'Items',
    'Banned Users',
    'Flagged Items',
    'Reports',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    darkMode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    users = await supabase
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    items = await supabase
        .from('items')
        .select()
        .neq('status', 'deleted')
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _showFlagDialog(Map item) async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Flag Item'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter reason for flagging',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();

              if (reason.isEmpty) return;

              /// 1️⃣ Update item FIRST
              await supabase
                  .from('items')
                  .update({
                    'status': 'flagged',
                    'flag_reason': reason,
                    'flagged_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', item['id']);

              /// 2️⃣ Send notification AFTER update
              await _sendNotification(
                userId: item['owner_id'],
                title: "Your item was flagged",
                body: "Your item '${item['name']}' was flagged for: $reason",
                type: "item_flagged",
              );

              await _load();

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Flag'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUserDetails(Map user) async {
    final userItems = await supabase
        .from('items')
        .select()
        .eq('owner_id', user['id'])
        .neq('status', 'deleted');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage:
                        user['avatar_url'] != null &&
                            user['avatar_url'].toString().startsWith('http')
                        ? NetworkImage(user['avatar_url'])
                        : null,
                    child: Text(
                      _initials(user['full_name'] ?? 'U'),
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  user['full_name'] ?? '',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 6),

                Text(
                  user['email'] ?? '',
                  style: TextStyle(color: muted),
                  textAlign: TextAlign.center,
                ),

                const Divider(height: 30),

                _detailRow("Warnings", "${user['warnings']}"),
                _detailRow("Banned", user['is_banned'] ? "Yes" : "No"),
                _detailRow("Role", user['role'] ?? "user"),

                const Divider(height: 30),

                Text(
                  "User Items (${userItems.length})",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: text,
                  ),
                ),

                const SizedBox(height: 10),

                ...userItems.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['name'], style: TextStyle(color: text)),
                    subtitle: Text(
                      "Rs ${item['price']} • ${item['status']}",
                      style: TextStyle(color: muted),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showItemDetails(item);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showItemDetails(Map item) async {
    final owner = await supabase
        .from('profiles')
        .select('full_name,email')
        .eq('id', item['owner_id'])
        .maybeSingle();

    final images = parseImages(item['images']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                /// DRAG HANDLE
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                /// TITLE
                Text(
                  item['name'] ?? '',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),

                const SizedBox(height: 10),

                /// IMAGE
                if (images.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      images.first,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),

                const SizedBox(height: 20),

                /// BASIC INFO
                _detailRow("Price", "Rs ${item['price'] ?? 0}"),
                _detailRow("Location", item['location'] ?? "-"),
                _detailRow("Status", item['status'] ?? "-"),

                const Divider(height: 30),

                /// DESCRIPTION
                Text(
                  "Description",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(item['description'] ?? '', style: TextStyle(color: muted)),

                const Divider(height: 30),

                /// OWNER
                Text(
                  "Owner",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  owner?['full_name'] ?? "Unknown",
                  style: TextStyle(color: muted),
                ),
                Text(owner?['email'] ?? "", style: TextStyle(color: muted)),

                if (item['status'] == 'flagged') ...[
                  const Divider(height: 30),
                  Text(
                    "Flag Reason",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: danger,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['flag_reason'] ?? '',
                    style: TextStyle(color: danger),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500, color: muted),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: text, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
  }) async {
    await supabase.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type ?? 'system',
      'handled': false,
    });
  }

  List<String> parseImages(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        if (raw.startsWith('http')) return [raw];
      }
    }
    return [];
  }

  Color get bg =>
      darkMode.value ? const Color(0xFF121212) : const Color(0xFFF4F6F9);
  Color get card => darkMode.value ? const Color(0xFF1E1E1E) : Colors.white;
  Color get text => darkMode.value ? Colors.white : const Color(0xFF263238);
  Color get muted => text.withValues(alpha: 0.6);
  Color get primary => const Color(0xFF1E88E5);
  Color get danger => Colors.redAccent;
  Color get warn => Colors.orange;

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _searchQuery.trim().toLowerCase();
    final all = List<Map<String, dynamic>>.from(users);
    if (q.isEmpty) return all;
    return all.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredItems {
    final q = _searchQuery.trim().toLowerCase();
    final all = List<Map<String, dynamic>>.from(items);
    if (q.isEmpty) return all;
    return all.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final location = (item['location'] ?? '').toString().toLowerCase();
      return name.contains(q) || location.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: darkMode,
      builder: (_, __, ___) {
        return Scaffold(
          backgroundColor: bg,
          drawer: _drawer(),
          appBar: AppBar(
            title: Text(_tabTitles[_selectedTab]),
            backgroundColor: primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ],
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      children: [
                        if (_selectedTab >= 1 && _selectedTab <= 4)
                          _searchBox(),
                        Expanded(child: _selectedView()),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _searchBox() {
    String hint = 'Search';
    if (_selectedTab == 1 || _selectedTab == 3) {
      hint = 'Search users by name or email';
    } else if (_selectedTab == 2 || _selectedTab == 4) {
      hint = 'Search items by name or location';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          filled: true,
          fillColor: card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _selectedView() {
    switch (_selectedTab) {
      case 0:
        return _overview();
      case 1:
        return _users(_filteredUsers);
      case 2:
        return _itemsList(_filteredItems);
      case 3:
        return _bannedUsers(
          _filteredUsers.where((u) => u['is_banned'] == true).toList(),
        );
      case 4:
        return _flaggedItems(
          _filteredItems.where((i) => i['status'] == 'flagged').toList(),
        );
      default:
        return _reports();
    }
  }

  void _selectTab(int index) {
    Navigator.of(context).pop();
    setState(() {
      _selectedTab = index;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Widget _drawerItem({
    required int index,
    required IconData icon,
    required String label,
    int? badge,
  }) {
    return ListTile(
      selected: _selectedTab == index,
      selectedTileColor: primary.withValues(alpha: 0.1),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          if (badge != null && badge > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: danger,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
      title: Text(label),
      onTap: () => _selectTab(index),
    );
  }

  Drawer _drawer() {
    final bannedCount = users.where((u) => u['is_banned'] == true).length;
    final flaggedCount = items.where((i) => i['status'] == 'flagged').length;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(color: primary),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.admin_panel_settings, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Admin Panel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${users.length} users  |  ${items.length} items',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _drawerItem(index: 0, icon: Icons.dashboard, label: 'Overview'),
          _drawerItem(index: 1, icon: Icons.people, label: 'Users'),
          _drawerItem(index: 2, icon: Icons.inventory_2, label: 'Items'),
          _drawerItem(
            index: 3,
            icon: Icons.person_off,
            label: 'Banned Users',
            badge: bannedCount,
          ),
          _drawerItem(
            index: 4,
            icon: Icons.flag,
            label: 'Flagged Items',
            badge: flaggedCount,
          ),
          _drawerItem(index: 5, icon: Icons.assessment, label: 'Reports'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: darkMode.value,
            onChanged: (v) => darkMode.value = v,
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Refresh Data'),
            onTap: () async {
              Navigator.of(context).pop();
              await _load();
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async => supabase.auth.signOut(),
          ),
        ],
      ),
    );
  }

  Widget _overview() {
    final banned = users.where((u) => u['is_banned'] == true).length;
    final flagged = items.where((i) => i['status'] == 'flagged').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
        children: [
          _stat('Users', users.length, () => setState(() => _selectedTab = 1)),
          _stat('Items', items.length, () => setState(() => _selectedTab = 2)),
          _stat(
            'Banned Users',
            banned,
            () => setState(() => _selectedTab = 3),
            danger,
          ),
          _stat(
            'Flagged Items',
            flagged,
            () => setState(() => _selectedTab = 4),
            warn,
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, VoidCallback onTap, [Color? color]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: _card(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color ?? text,
              ),
            ),
            Text(label, style: TextStyle(color: muted)),
          ],
        ),
      ),
    );
  }

  Widget _users(List<Map<String, dynamic>> list) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: list.map((u) {
          final warnings = u['warnings'] ?? 0;
          final banned = u['is_banned'] == true;
          final locked = banned || warnings >= 3;

          return _userTile(u, warnings, banned, locked);
        }).toList(),
      ),
    );
  }

  Widget _bannedUsers(List<Map<String, dynamic>> bannedUsers) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: bannedUsers.map((u) {
          return _userTile(u, u['warnings'] ?? 0, true, true);
        }).toList(),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'U';
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  Widget _userAvatar(Map u) {
    final name = (u['full_name'] ?? 'User').toString();
    final avatarUrl = (u['avatar_url'] ?? '').toString();
    final validUrl = avatarUrl.startsWith('http');

    return CircleAvatar(
      radius: 22,
      backgroundColor: primary.withValues(alpha: 0.12),
      foregroundImage: validUrl ? NetworkImage(avatarUrl) : null,
      child: Text(
        _initials(name),
        style: TextStyle(color: primary, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _userTile(Map u, int warnings, bool banned, bool locked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _card(),
      child: GestureDetector(
        onTap: () => _showUserDetails(u),
        child: ListTile(
          leading: _userAvatar(u),
          title: Text(u['full_name'] ?? 'User', style: TextStyle(color: text)),
          subtitle: Text(
            'Warnings: $warnings | ${u['email']}',
            style: TextStyle(color: muted),
          ),
          trailing: locked
              ? IconButton(
                  icon: const Icon(Icons.lock_open, color: Colors.green),
                  onPressed: () async {
                    await supabase
                        .from('profiles')
                        .update({'is_banned': false, 'warnings': 0})
                        .eq('id', u['id']);
                    _load();
                  },
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.warning, color: warn),
                      onPressed: () async {
                        final newWarn = warnings + 1;
                        await supabase
                            .from('profiles')
                            .update({
                              'warnings': newWarn,
                              'is_banned': newWarn >= 3,
                            })
                            .eq('id', u['id']);

                        await _sendNotification(
                          userId: u['id'],
                          title: "Warning Issued",
                          body:
                              "You received a warning from admin. Total warnings: $newWarn",
                          type: "user_warning",
                        );

                        _load();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.block, color: danger),
                      onPressed: () async {
                        await supabase
                            .from('profiles')
                            .update({'is_banned': true})
                            .eq('id', u['id']);

                        await _sendNotification(
                          userId: u['id'],
                          title: "Account Banned",
                          body: "Your account has been banned by admin.",
                          type: "user_banned",
                        );

                        _load();
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _itemsList(List<Map<String, dynamic>> list) {
    return _itemList(list);
  }

  Widget _flaggedItems(List<Map<String, dynamic>> flagged) {
    return _itemList(flagged);
  }

  Widget _itemList(List list) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: list.map((item) {
          final images = parseImages(item['images']);
          final flagged = item['status'] == 'flagged';

          return GestureDetector(
            onTap: () => _showItemDetails(item),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: _card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (images.isNotEmpty)
                    Image.network(
                      images.first,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      height: 180,
                      width: double.infinity,
                      color: muted.withValues(alpha: 0.12),
                      alignment: Alignment.center,
                      child: Icon(Icons.image_not_supported, color: muted),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'Unnamed item',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: text,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Price: Rs ${item['price'] ?? '0'}',
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!flagged)
                              IconButton(
                                icon: Icon(Icons.flag, color: warn),
                                onPressed: () => _showFlagDialog(item),
                              ),
                            if (flagged)
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                onPressed: () async {
                                  await supabase
                                      .from('items')
                                      .update({
                                        'status': 'approved',
                                        'flag_reason': null,
                                      })
                                      .eq('id', item['id']);
                                  _load();
                                },
                              ),
                            IconButton(
                              icon: Icon(Icons.delete, color: danger),
                              onPressed: () async {
                                await supabase
                                    .from('items')
                                    .update({'status': 'deleted'})
                                    .eq('id', item['id']);

                                await _sendNotification(
                                  userId: item['owner_id'],
                                  title: "Your item was removed",
                                  body:
                                      "Your item '${item['name']}' was removed by admin.",
                                  type: "item_deleted",
                                );

                                _load();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _reports() {
    final banned = users.where((u) => u['is_banned'] == true).length;
    final flagged = items.where((i) => i['status'] == 'flagged').length;
    final bannedRate = users.isEmpty ? 0 : ((banned / users.length) * 100);
    final flaggedRate = items.isEmpty ? 0 : ((flagged / items.length) * 100);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _reportTile('Total Users', users.length.toString()),
        _reportTile('Total Items', items.length.toString()),
        _reportTile('Banned User Rate', '${bannedRate.toStringAsFixed(1)}%'),
        _reportTile('Flagged Item Rate', '${flaggedRate.toStringAsFixed(1)}%'),
      ],
    );
  }

  Widget _reportTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _card(),
      child: ListTile(
        title: Text(label, style: TextStyle(color: muted)),
        trailing: Text(
          value,
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  BoxDecoration _card() => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(blurRadius: 8, color: Colors.black.withValues(alpha: 0.08)),
    ],
  );
}
