import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

final supabase = Supabase.instance.client;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  bool _editing = false;

  String? name;
  String? email;
  String? avatarUrl;
  String? phone;
  String? address;
  DateTime? joinedAt;

  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('profiles')
          .select(
            'full_name, email, phone, default_address, avatar_url, created_at',
          )
          .eq('id', user.id)
          .single();

      setState(() {
        name = data['full_name'];
        email = data['email'];
        phone = data['phone'];
        address = data['default_address'];
        avatarUrl = data['avatar_url'];
        joinedAt = DateTime.tryParse(data['created_at']);

        _phoneController.text = phone ?? '';
        _addressController.text = address ?? '';
        _loading = false;
      });
    } catch (e) {
      print('❌ Failed to load profile: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      await supabase
          .from('profiles')
          .update({
            'phone': _phoneController.text.trim(),
            'default_address': _addressController.text.trim(),
          })
          .eq('id', user.id);

      setState(() {
        phone = _phoneController.text.trim();
        address = _addressController.text.trim();
        _editing = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to update profile: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final ext = picked.path.split('.').last;
    final filePath = 'avatars/${user.id}.$ext';

    setState(() => _loading = true);

    try {
      // Upload to Supabase Storage
      await supabase.storage
          .from('avatars')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      // Get public URL
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      // Update profile table
      await supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      setState(() {
        avatarUrl = publicUrl;
      });
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                _editing = !_editing;
                _phoneController.text = phone ?? '';
                _addressController.text = address ?? '';
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _ProfileHeader(
              name: name ?? 'User',
              email: email ?? '',
              avatarUrl: avatarUrl,
              onAvatarTap: _pickAndUploadAvatar,
            ),

            const SizedBox(height: 16),

            _InfoCard(
              title: 'Personal Information',
              children: [
                _editing
                    ? _EditableField(
                        icon: Icons.phone,
                        label: 'Phone Number',
                        controller: _phoneController,
                      )
                    : _InfoTile(
                        icon: Icons.phone,
                        label: 'Phone Number',
                        value: phone ?? 'Not added',
                      ),
                _editing
                    ? _EditableField(
                        icon: Icons.location_on,
                        label: 'Default Address',
                        controller: _addressController,
                        maxLines: 2,
                      )
                    : _InfoTile(
                        icon: Icons.location_on,
                        label: 'Default Address',
                        value: address ?? 'Used as default while listing items',
                      ),
              ],
            ),

            _InfoCard(
              title: 'Account Details',
              children: [
                _InfoTile(
                  icon: Icons.email,
                  label: 'Email',
                  value: email ?? '',
                ),
                _InfoTile(
                  icon: Icons.calendar_today,
                  label: 'Joined On',
                  value: joinedAt != null
                      ? '${joinedAt!.day}/${joinedAt!.month}/${joinedAt!.year}'
                      : '—',
                ),
              ],
            ),

            if (_editing)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ================= UI COMPONENTS ================= */

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;

  const _ProfileHeader({
    required this.name,
    required this.email,
    this.avatarUrl,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onAvatarTap,
            borderRadius: BorderRadius.circular(50),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 42,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                backgroundColor: const Color(0xFF90CAF9),
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF1E88E5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final int maxLines;

  const _EditableField({
    required this.icon,
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF1E88E5)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
