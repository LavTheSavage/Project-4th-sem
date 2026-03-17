import 'dart:io';

import 'package:flutter/material.dart';
import 'item_form_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'booking_page.dart';
import 'dart:convert';

class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final int index;
  final String? currentUser;
  final void Function(int, Map<String, dynamic>) onUpdate;
  final void Function(int) onDelete;
  final List<Map<String, dynamic>> allItems;

  const ItemDetailPage({
    super.key,
    required this.item,
    required this.index,
    required this.currentUser,
    required this.onUpdate,
    required this.onDelete,
    required this.allItems,
  });

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  late Map<String, dynamic> item;
  bool isFavorite = false;

  void _normalizeImages(dynamic rawImages) {
    if (rawImages == null) {
      images = [];
      return;
    }

    // Case 1: Proper List
    if (rawImages is List) {
      images = rawImages.whereType<String>().toList();
      return;
    }

    // Case 2: JSON string list
    if (rawImages is String) {
      try {
        final decoded = jsonDecode(rawImages);
        if (decoded is List) {
          images = decoded.whereType<String>().toList();
          return;
        }
      } catch (_) {
        // ignore
      }
    }

    images = [];
  }

  late List<String> images;
  late PageController _pageController;
  int _currentPage = 0;

  final List<String> _statuses = ['Available', 'Booked', 'Unavailable'];

  @override
  void initState() {
    super.initState();
    item = Map<String, dynamic>.from(widget.item);
    isFavorite = item['favorite'] == true;
    _normalizeImages(item['images']);

    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _editItem() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemFormPage(
          categories: const ['All', 'Electronics', 'Appliances', 'Tools'],
          existingItem: item,
        ),
      ),
    );
    if (res != null && res is Map<String, dynamic>) {
      setState(() {
        item = {...item, ...res};

        isFavorite = item['favorite'] == true;
        _normalizeImages(item['images']);
      });

      widget.onUpdate(widget.index, item);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDelete(widget.index);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  void _shareItem() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share link: ${item['name'] ?? 'item'}')),
    );
  }

  void _openImagePreview(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(backgroundColor: Colors.black),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: url.startsWith('http')
                  ? Image.network(url)
                  : Image.file(File(url)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard(
    dynamic icon,
    String title,
    String subtitle, {
    Color? color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon is IconData
                ? Icon(icon, color: color ?? Theme.of(context).primaryColor)
                : icon,
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusPicker() async {
    if (item['owner_id'] != widget.currentUser) return; // safety
    String current = (item['status'] as String?) ?? _statuses[0];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Change status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ..._statuses.map((s) {
              return RadioListTile<String>(
                title: Text(s),
                value: s,
                groupValue: current,
                onChanged: (v) {
                  Navigator.pop(ctx, v);
                },
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );

    if (selected != null && selected != current) {
      setState(() {
        item['status'] = selected;
      });
      widget.onUpdate(widget.index, item);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status updated to "$selected"')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner =
        widget.currentUser != null &&
        widget.currentUser!.isNotEmpty &&
        item['owner_id'] == widget.currentUser;

    final validImages = images
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList();

    debugPrint('RAW images: $images');
    debugPrint('VALID images: $validImages');

    final hasImages = validImages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(item['name'] ?? 'Item'),
        backgroundColor: const Color(0xFF1E88E5),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareItem),
          if (isOwner)
            IconButton(icon: const Icon(Icons.edit), onPressed: _editItem),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          physics: const BouncingScrollPhysics(),
          children: [
            // Image carousel / single image area (constrained to avoid overflow)
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    if (hasImages)
                      PageView.builder(
                        controller: _pageController,
                        itemCount: validImages.length,
                        onPageChanged: (p) => setState(() => _currentPage = p),
                        itemBuilder: (ctx, i) {
                          final imgPath = validImages[i];
                          return Hero(
                            tag:
                                'item_image_${widget.index}_${item['name']}_$i',
                            child: InkWell(
                              onTap: () => _openImagePreview(imgPath),
                              child: imgPath.startsWith('http')
                                  ? Image.network(
                                      imgPath,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      loadingBuilder: (c, w, p) {
                                        if (p == null) return w;
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        size: 48,
                                      ),
                                    )
                                  : Image.file(
                                      File(imgPath),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Colors.black26,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No image available',
                              style: TextStyle(color: Colors.black45),
                            ),
                          ],
                        ),
                      ),
                    // page indicator
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: List.generate(
                          validImages.length,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: _currentPage == i ? 10 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == i
                                  ? Colors.white
                                  : Colors.white70,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (hasImages)
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: validImages.length,
                  itemBuilder: (ctx, i) {
                    final p = validImages[i];
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 72,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: i == _currentPage
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: p.startsWith('http')
                                ? NetworkImage(p)
                                : FileImage(File(p)) as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (hasImages) const SizedBox(height: 12),

            // Title card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // LEFT: Item name
                    Expanded(
                      child: Text(
                        item['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // RIGHT: Price + status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/nepali_rupee_filled.svg',
                              width: 22,
                              height: 22,
                              colorFilter: const ColorFilter.mode(
                                Colors.green,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item['price'] ?? '0'}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: isOwner ? _showStatusPicker : null,
                          child: Chip(
                            backgroundColor: const Color(0xFFE3F2FD),
                            label: Text(
                              item['status'] ?? 'Available',
                              style: const TextStyle(color: Color(0xFF1E88E5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Individual small cards: use Wrap so they flow on small screens instead of overflowing
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  child: _infoCard(
                    Icons.category,
                    'Category',
                    item['category'] ?? 'N/A',
                  ),
                ),

                SizedBox(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  child: _infoCard(
                    Icons.person,
                    'Owner',
                    item['owner']?['full_name'] ?? 'Unknown',
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  child: _infoCard(
                    Icons.app_settings_alt,
                    'Condition',
                    item['condition'] ?? 'Good',
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  child: _infoCard(
                    Icons.location_on,
                    'Location',
                    item['location'] ?? 'N/A',
                    color: Colors.redAccent,
                  ),
                ),

                SizedBox(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  child: Builder(
                    builder: (_) {
                      final raw = item['createdAt'] ?? item['created_at'];
                      String dateStr = 'N/A';
                      if (raw != null) {
                        final dt = raw is DateTime
                            ? raw
                            : DateTime.tryParse(raw) ?? DateTime(2000);
                        dateStr =
                            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                      }
                      return _infoCard(
                        Icons.calendar_today,
                        'Listed Date',
                        dateStr,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 48) / 2,
                  child: Builder(
                    builder: (_) {
                      final raw = item['createdAt'] ?? item['created_at'];
                      String timeStr = 'N/A';
                      if (raw != null) {
                        final dt = raw is DateTime
                            ? raw
                            : DateTime.tryParse(raw) ?? DateTime(2000);
                        timeStr =
                            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      }
                      return _infoCard(
                        Icons.access_time,
                        'Listed Time',
                        timeStr,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(item['description'] ?? 'No description provided.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Action buttons: premium side-by-side large buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: isOwner
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookingPage(
                                    item: Map<String, dynamic>.from(item),
                                    currentUser: widget.currentUser,
                                    index: widget.index,
                                    onUpdate: widget.onUpdate,
                                    allItems: widget.allItems,
                                  ),
                                ),
                              );
                            },
                      icon: Icon(
                        Icons.shopping_cart,
                        color: isOwner ? const Color(0xFF263238) : Colors.white,
                      ),
                      label: Text(
                        isOwner ? 'Cannot book your own item' : 'Book Now',
                        style: TextStyle(
                          color: isOwner
                              ? const Color(0xFF263238)
                              : Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOwner
                            ? Colors.grey.shade300
                            : const Color(0xFF1E88E5),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: isOwner
                          ? _editItem
                          : () {
                              final ownerName =
                                  item['owner']?['full_name'] ?? 'Unknown';

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Contacted $ownerName (placeholder)',
                                  ),
                                ),
                              );
                            },
                      icon: Icon(isOwner ? Icons.edit : Icons.message),
                      label: Text(isOwner ? 'Edit' : 'Contact Owner'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black12),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
