import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'my_rentals_page.dart';
import 'payment_page.dart';

class ApprovalPage extends StatefulWidget {
  final String bookingId;
  final bool showMyRentalsShortcut;
  const ApprovalPage({
    super.key,
    required this.bookingId,
    this.showMyRentalsShortcut = false,
  });

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  bool loading = true;
  Map<String, dynamic>? booking;
  bool rentalsLoading = false;
  List<Map<String, dynamic>> myRentals = [];

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.showMyRentalsShortcut) {
      _loadMyRentals();
    }
  }

  Future<void> _load() async {
    final res = await Supabase.instance.client
        .from('bookings')
        .select('''
          *,
          item:items (name, images),
          renter:profiles!bookings_renter_id_fkey (full_name)
        ''')
        .eq('id', widget.bookingId)
        .single();

    setState(() {
      booking = res;
      loading = false;
    });
  }

  Future<void> _loadMyRentals() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => rentalsLoading = true);

    final res = await Supabase.instance.client
        .from('bookings')
        .select('''
          id,
          status,
          from_date,
          to_date,
          item:items (
            id,
            name,
            price,
            images,
            owner:profiles (full_name)
          )
        ''')
        .eq('renter_id', uid)
        .order('created_at', ascending: false)
        .limit(3);

    setState(() {
      myRentals = List<Map<String, dynamic>>.from(res);
      rentalsLoading = false;
    });
  }

  /// OWNER → APPROVE
  Future<void> _approveBooking() async {
    setState(() => loading = true);

    try {
      final supabase = Supabase.instance.client;
      final renterId = booking!['renter_id'];
      final itemName = booking!['item']['name'];

      await supabase.from('bookings').update({
        'status': 'approved',
        'owner_approved': true,
        'payment_status': 'pending',
      }).eq('id', widget.bookingId);

      await supabase
          .from('notifications')
          .update({'handled': true})
          .eq('booking_id', widget.bookingId);

      await supabase.from('notifications').insert({
        'user_id': renterId,
        'booking_id': widget.bookingId,
        'title': 'Booking approved for $itemName',
        'body': 'Your booking request has been approved. Payment is now required.',
        'type': 'booking_approved',
        'handled': false,
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error approving booking: $e')));
      debugPrint('Error :$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// OWNER → DECLINE (DELETE BOOKING)
  Future<void> _declineBooking(String reason) async {
    setState(() => loading = true);

    final supabase = Supabase.instance.client;
    final renterId = booking!['renter_id'];
    final itemName = booking!['item']['name'];

    await supabase
        .from('bookings')
        .update({'status': 'declined'})
        .eq('id', widget.bookingId);

    // mark any prior notifications for this booking handled, then insert a decline notice
    await supabase
        .from('notifications')
        .update({'handled': true})
        .eq('booking_id', widget.bookingId);

    await supabase.from('notifications').insert({
      'user_id': renterId,
      'booking_id': widget.bookingId,
      'title': 'Booking declined for $itemName',
      'body': 'Reason: $reason',
      'type': 'booking_declined',
      'handled': false,
    });

    if (mounted) Navigator.pop(context, true);
  }

  /// RENTER → ITEM RECEIVED
  Future<void> _markReceived() async {
    if (booking?['payment_status'] != 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete payment before confirming receipt.'),
        ),
      );
      return;
    }
    setState(() => loading = true);

    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'status': 'active', 'received_by_renter': true})
          .eq('id', widget.bookingId);

      await Supabase.instance.client.from('notifications').insert({
        'user_id': booking!['owner_id'],
        'booking_id': widget.bookingId,
        'title': 'Item Received',
        'body': 'Renter has confirmed receiving the item.',
        'type': 'item_received',
        'handled': false,
      });

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot activate booking: already in use')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> normalizeImages(dynamic raw) {
    if (raw is List) return raw.whereType<String>().toList();
    if (raw is String && raw.startsWith('[')) {
      try {
        return List<String>.from(jsonDecode(raw));
      } catch (_) {}
    }
    return [];
  }

  String formatRange(String from, String to) {
    final f = DateTime.parse(from);
    final t = DateTime.parse(to);

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
    return '${m[f.month - 1]} ${f.day} → ${m[t.month - 1]} ${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading || booking == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final isOwner = booking!['owner_id'] == currentUserId;
    final isRenter = booking!['renter_id'] == currentUserId;
    final status = booking!['status'];
    final paymentStatus = booking!['payment_status'] ?? 'pending';

    final images = normalizeImages(booking!['item']['images']);
    final thumb = images.isNotEmpty ? images.first : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details'), elevation: 0),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// HEADER
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: thumb != null
                                ? Image.network(
                                    thumb,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.inventory,
                                      size: 40,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking!['item']['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _statusChip(status),
                                const SizedBox(height: 8),
                                Text(
                                  'Period: ${booking!["from_date"]} -> ${booking!["to_date"]}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total: Rs ${booking!["total_price"]}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      /// PEOPLE SECTION
                      Text(
                        'People',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            child: Icon(Icons.person),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking!['renter']['full_name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'Renter',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      Divider(color: Colors.grey[300]),
                      const SizedBox(height: 20),

                      /// SUMMARY
                      Text(
                        'Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _infoTile('Days', booking!['total_days'].toString()),
                          _infoTile(
                            'Total Price',
                            'Rs ${booking!['total_price']}',
                          ),
                        ],
                      ),

                      if (isRenter && status == 'approved') ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: paymentStatus == 'paid'
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paymentStatus == 'paid'
                                    ? 'Payment completed'
                                    : 'Payment required',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                paymentStatus == 'paid'
                                    ? 'You can now confirm that you received the item.'
                                    : 'Pay after the seller approves your request.',
                              ),
                              if (paymentStatus != 'paid') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.payment),
                                    label: const Text('Choose payment method'),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PaymentPage(
                                            bookingId: widget.bookingId,
                                            itemName:
                                                booking!['item']['name']
                                                    ?.toString() ??
                                                'Booking',
                                            totalPrice:
                                                booking!['total_price'],
                                          ),
                                        ),
                                      );
                                      if (mounted) await _load();
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      /// ACTIONS
                      if (widget.showMyRentalsShortcut) ...[
                        const Text(
                          'My Rentals',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (rentalsLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (myRentals.isEmpty)
                          const Text(
                            'No rentals yet',
                            style: TextStyle(color: Colors.grey),
                          )
                        else
                          Column(
                            children: myRentals.map((r) {
                              final item = r['item'];
                              final status = r['status'] ?? '';
                              final from = r['from_date'];
                              final to = r['to_date'];
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.shopping_bag),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item?['name'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (from != null && to != null)
                                              Text(
                                                formatRange(
                                                  from.toString(),
                                                  to.toString(),
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      _statusChip(status.toString()),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.shopping_cart),
                            label: const Text('My Rentals'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyRentalsPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (isOwner && status == 'pending') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: loading ? null : _approveBooking,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('Decline'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: loading
                                    ? null
                                    : () => _declineBooking('Owner declined'),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (isRenter &&
                          status == 'approved' &&
                          paymentStatus == 'paid') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Item Received'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: loading ? null : _markReceived,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (loading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ],
  );

  Widget _statusChip(String status) {
    final color =
        {
          'pending': Colors.orange,
          'approved': Colors.blue,
          'active': Colors.green,
          'completed': Colors.grey,
          'declined': Colors.red,
        }[status] ??
        Colors.black;

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }
}




