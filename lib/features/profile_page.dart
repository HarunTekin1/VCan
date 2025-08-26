import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _saving = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    _nameCtrl.text = data['displayName'] ?? '';
    _bioCtrl.text = data['bio'] ?? '';
    setState(() { _avatarUrl = data['avatarUrl']; });
  }

  Future<void> _pickAndUploadAvatar() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);
    if (file == null) return;
    setState(() => _saving = true);
    try {
      final ref = FirebaseStorage.instance.ref().child('avatars').child('${u.uid}.jpg');
  await ref.putFile(File(file.path));
  final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({'avatarUrl': url}, SetOptions(merge: true));
  if (!mounted) return;
  setState(() { _avatarUrl = url; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Hochladen: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'displayName': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'avatarUrl': _avatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil gespeichert')));
    } catch (e) {
  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAndUploadAvatar,
              child: CircleAvatar(
                radius: 48,
                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) as ImageProvider : null,
                child: _avatarUrl == null ? const Icon(Icons.person, size: 48) : null,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _pickAndUploadAvatar, child: const Text('Avatar ändern')),
            const SizedBox(height: 12),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: _bioCtrl, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 4),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height:18,width:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text('Speichern')),
            )
          ],
        ),
      ),
    );
  }
}
