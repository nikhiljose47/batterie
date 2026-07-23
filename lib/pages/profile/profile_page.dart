import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import 'profile_store.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _picking = false;

  Future<void> _editName() async {
    final controller =
        TextEditingController(text: ProfileStore.instance.name.value);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Enter your name'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await ProfileStore.instance.setName(result);
    }
  }

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        await ProfileStore.instance.setPhoto(file.path);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          _buildPhotoCard(),
          const SizedBox(height: AppSpacing.large),
          const _InfoTile(icon: Icons.cake_outlined, label: 'Age', value: '28'),
          const _InfoTile(icon: Icons.public_rounded, label: 'Country', value: 'India'),
          const _InfoTile(
            icon: Icons.monitor_heart_outlined,
            label: 'Details',
            value:
                'Uses sleep, activity, stress, pain, heat, and fitness signals to estimate physical and brain readiness.',
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return ValueListenableBuilder<String?>(
      valueListenable: ProfileStore.instance.photoPath,
      builder: (context, path, _) {
        final hasPhoto = path != null && File(path).existsSync();
        return Container(
          padding: const EdgeInsets.all(AppSpacing.large),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            children: <Widget>[
              GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.surfaceTint,
                      backgroundImage:
                          hasPhoto ? FileImage(File(path)) : null,
                      child: hasPhoto
                          ? null
                          : const Icon(Icons.person_rounded,
                              size: 42, color: AppColors.primary),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _picking
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt_rounded,
                                size: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<String>(
                valueListenable: ProfileStore.instance.name,
                builder: (_, displayName, __) => GestureDetector(
                  onTap: _editName,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        displayName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_rounded,
                          size: 15, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Energy Health profile',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              if (hasPhoto) ...<Widget>[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => ProfileStore.instance.clearPhoto(),
                  child: const Text(
                    'Remove photo',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: ListTile(
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          side: const BorderSide(color: AppColors.outline),
        ),
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
