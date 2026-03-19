import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:project/main.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'approval_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool loading = true;
  List<Map<String, dynamic>> notifications = [];
  final supabase = Supabase.instance.client;
  static const _appBarColor = Color(0xFF1E88E5);
  static const _pageBg = Color(0xFFF6F8FB);

  @override
  void initState() {
    supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', supabase.auth.currentUser!.id)
        .listen((data) {
          fetchNotifications();
        });
    super.initState();
    fetchNotifications();
    MyAppStateNotifier.refresh?.call();
  }

  // ================= FETCH =================
  Future<void> fetchNotifications() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => loading = false);
        return;
      }

      final res = await supabase
          .from('notifications')
          .select('''
          id,
          title,
          body,
          created_at,
          handled,
          type,
          user_id,
          booking_id,
          booking:bookings (
            id,
            from_date,
            to_date,
            total_days,
            total_price,
            status,
            received_by_renter,
            item:items (name, images),
            renter:profiles!bookings_renter_id_fkey (id, full_name)
          )
        ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      debugPrint('Notifications fetched: ${res.length}');

      final raw = List<Map<String, dynamic>>.from(res);

      final toDelete = <String>[];
      final toHandle = <String>[];
      for (final n in raw) {
        if (_shouldAutoDeleteDeclined(n)) {
          toDelete.add(n['id'].toString());
          continue;
        }
        if (_shouldAutoArchiveApproved(n)) {
          toHandle.add(n['id'].toString());
        }
      }

      if (toDelete.isNotEmpty) {
        await supabase.from('notifications').delete().inFilter('id', toDelete);
        MyAppStateNotifier.refresh?.call();
      }

      if (toHandle.isNotEmpty) {
        await supabase
            .from('notifications')
            .update({'handled': true})
            .inFilter('id', toHandle);
        MyAppStateNotifier.refresh?.call();
      }

      setState(() {
        notifications = raw
            .where((n) => !toDelete.contains(n['id'].toString()))
            .toList();
        for (final n in notifications) {
          if (toHandle.contains(n['id'].toString())) {
            n['handled'] = true;
          }
        }
        loading = false;
      });
    } catch (e) {
      debugPrint('Fetch error: $e');
      setState(() => loading = false);
    }
  }

  // ================= HELPERS =================
  String formatDateTime(dynamic ts) {
    if (ts == null) return '';
    return DateFormat(
      'yyyy MMM dd, hh:mm a',
    ).format(DateTime.parse(ts).toLocal());
  }

  List<String> normalizeImages(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.whereType<String>().toList();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.whereType<String>().toList();
      } catch (_) {
        if (raw.startsWith('http')) return [raw];
      }
    }
    return [];
  }

  String formatRangeShort(dynamic from, dynamic to) {
    if (from == null || to == null) return '';
    final f = DateTime.parse(from.toString());
    final t = DateTime.parse(to.toString());
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[f.month - 1]} ${f.day} - ${m[t.month - 1]} ${t.day}';
  }

  bool _shouldAutoDeleteDeclined(Map<String, dynamic> n) {
    final createdAt = n['created_at'];
    if (createdAt == null) return false;

    final booking = n['booking'];
    final bookingStatus = booking?['status']?.toString();
    final type = n['type']?.toString();
    final isDeclined =
        bookingStatus == 'declined' ||
        bookingStatus == 'rejected' ||
        type == 'booking_declined';
    if (!isDeclined) return false;

    final created = DateTime.parse(createdAt.toString()).toUtc();
    final threshold = DateTime.now().toUtc().subtract(const Duration(days: 7));
    return created.isBefore(threshold);
  }

  bool _shouldAutoArchiveApproved(Map<String, dynamic> n) {
    final booking = n['booking'];
    final bookingStatus = booking?['status']?.toString();
    final type = n['type']?.toString();
    return bookingStatus == 'completed' && type == 'booking_approved';
  }

  Future<void> markHandled(String id) async {
    await supabase.from('notifications').update({'handled': true}).eq('id', id);
    await fetchNotifications();
    MyAppStateNotifier.refresh?.call();
  }

  Widget statusChip(String? status) {
    final color =
        {
          'pending': Colors.orange,
          'approved': Colors.blue,
          'declined': Colors.red,
          'active': Colors.green,
        }[status] ??
        Colors.grey;

    return Chip(
      label: Text(
        status?.toUpperCase() ?? '',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  // ================= RECEIVED BUTTON =================
  Future<void> markReceived({
    required String bookingId,
    required String notificationId,
  }) async {
    await supabase
        .from('bookings')
        .update({'received_by_renter': true, 'status': 'active'})
        .eq('id', bookingId);

    await markHandled(notificationId);
    fetchNotifications();
  }

  Future<void> deleteNotification(
    BuildContext context,
    Map<String, dynamic> n,
  ) async {
    final id = n['id'].toString();
    await supabase.from('notifications').delete().eq('id', id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await supabase.from('notifications').insert({
              'user_id': n['user_id'],
              'booking_id': n['booking_id'],
              'title': n['title'],
              'body': n['body'],
              'type': n['type'],
              'handled': n['handled'] ?? false,
            });
            await fetchNotifications();
            MyAppStateNotifier.refresh?.call();
          },
        ),
      ),
    );

    await fetchNotifications();
    MyAppStateNotifier.refresh?.call();
  }

  Widget _notificationCard({
    required BuildContext context,
    required Map<String, dynamic> n,
    required dynamic booking,
    required dynamic renter,
    required String? thumb,
    required dynamic item,
    required bool isHandled,
    required bool canOpen,
    required bool showReceivedBtn,
    required bool canDelete,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isHandled ? 0.55 : 1.0,
      child: GestureDetector(
        onLongPress: () async {
          final action = await showModalBottomSheet<String>(
            context: context,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canDelete)
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text('Delete notification'),
                      onTap: () => Navigator.pop(context, 'delete'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.mark_email_read),
                    title: const Text('Mark as unread'),
                    onTap: () => Navigator.pop(context, 'unread'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );

          if (action == 'delete') {
            await deleteNotification(context, n);
          }

          if (action == 'unread') {
            await supabase
                .from('notifications')
                .update({'handled': false})
                .eq('id', n['id']);
            await fetchNotifications();
            MyAppStateNotifier.refresh?.call();
          }
        },
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.08),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: canOpen
                ? () async {
                    if (!isHandled) {
                      await markHandled(n['id'].toString());
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApprovalPage(
                          bookingId: n['booking_id'].toString(),
                          showMyRentalsShortcut: true,
                        ),
                      ),
                    );
                  }
                : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: thumb != null
                                ? Image.network(
                                    thumb,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, progress) {
                                      if (progress == null) return child;
                                      return const SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image),
                                  )
                                : Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.blue.shade100,
                                    child: Icon(
                                      Icons.notifications,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                          ),
                          if (!isHandled)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _appBarColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    n['title'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                statusChip(booking?['status']),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (item?['name'] != null)
                              Text(
                                item['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            if (booking?['from_date'] != null &&
                                booking?['to_date'] != null)
                              Text(
                                formatRangeShort(
                                  booking['from_date'],
                                  booking['to_date'],
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              formatDateTime(n['created_at']),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),

                  // ===== RECEIVED BUTTON =====
                  if (showReceivedBtn) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text("Received Item"),
                        onPressed: () => markReceived(
                          bookingId: booking['id'].toString(),
                          notificationId: n['id'].toString(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget _systemNotificationCard(Map<String, dynamic> n) {
      final type = n['type'];
      IconData icon;
      Color color;

      switch (type) {
        case 'user_warning':
          icon = Icons.warning;
          color = Colors.orange;
          break;
        case 'user_banned':
          icon = Icons.block;
          color = Colors.red;
          break;
        case 'item_flagged':
          icon = Icons.flag;
          color = Colors.deepOrange;
          break;
        case 'item_deleted':
          icon = Icons.delete;
          color = Colors.redAccent;
          break;
        default:
          icon = Icons.notifications;
          color = Colors.blue;
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n['body'] ?? '',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatDateTime(n['created_at']),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _pageBg,
      body: RefreshIndicator(
        onRefresh: fetchNotifications,
        child: notifications.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text("No notifications yet")),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  final booking = n['booking'];
                  final type = n['type']?.toString();
                  final isSystem =
                      type == 'user_warning' ||
                      type == 'user_banned' ||
                      type == 'item_flagged' ||
                      type == 'item_deleted';
                  final item = booking?['item'];
                  final renter = booking?['renter'];
                  final bool isHandled = n['handled'] == true;

                  final images = normalizeImages(item?['images']);
                  final thumb = images.isNotEmpty ? images.first : null;

                  final canOpen = booking != null;
                  final canDelete =
                      booking == null || booking['status'] != 'approved';
                  final showReceivedBtn =
                      booking?['status'] == 'approved' &&
                      booking?['received_by_renter'] == false &&
                      renter?['id'] == supabase.auth.currentUser!.id;
                  if (isSystem) {
                    return _systemNotificationCard(n);
                  }

                  return _notificationCard(
                    context: context,
                    n: n,
                    booking: booking,
                    renter: renter,
                    item: item,
                    thumb: thumb,
                    isHandled: isHandled,
                    canOpen: canOpen,
                    showReceivedBtn: showReceivedBtn,
                    canDelete: canDelete,
                  );
                },
              ),
      ),
    );
  }
}
