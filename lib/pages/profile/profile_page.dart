import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../services/google_calendar_service.dart';
import '../auth/auth_page.dart';
import '../settings/settings_page.dart';
import 'profile_bloc.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _picking = false;

  Future<void> _editName() async {
    final profileBloc = context.read<ProfileBloc>();
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _EditNamePage(initialName: profileBloc.state.name),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await profileBloc.setName(result);
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
        await context.read<ProfileBloc>().setPhoto(file.path);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text(
            'You will need to sign in again to sync calendar and profile data.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;
    await GoogleCalendarService.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AuthPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.large,
          AppSpacing.medium,
          AppSpacing.large,
          AppSpacing.xLarge,
        ),
        children: <Widget>[
          _buildPhotoCard(),
          const SizedBox(height: 14),
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            initialData: FirebaseAuth.instance.currentUser,
            builder: (context, snapshot) {
              final signedIn = snapshot.data != null;
              return _ActionGroup(
                children: <Widget>[
                  _ActionTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Edit profile',
                    value: 'Name and photo',
                    onTap: _editName,
                  ),
                  _ActionTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    value: 'App preferences',
                    onTap: _openSettings,
                  ),
                  _ActionTile(
                    icon: signedIn ? Icons.logout_rounded : Icons.login_rounded,
                    label: signedIn ? 'Logout' : 'Login',
                    value: signedIn
                        ? (snapshot.data!.email ?? 'Signed in')
                        : 'Email or Google',
                    onTap: signedIn ? _logout : _openLogin,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, profile) {
              return _ProfileDetailsPanel(
                age: profile.age,
                userId: profile.userId,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, profile) {
        final path = profile.photoPath;
        final hasPhoto = path != null && File(path).existsSync();
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.34),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: <Widget>[
                    ProfileAvatar(
                      key: ValueKey<String?>(path),
                      radius: 44,
                      backgroundColor: AppColors.surfaceTint,
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
              const SizedBox(width: 14),
              Expanded(
                child: BlocSelector<ProfileBloc, ProfileState, String>(
                  selector: (state) => state.name,
                  builder: (_, displayName) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 19,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Energy Health profile',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _SmallProfileButton(
                            icon: Icons.edit_rounded,
                            label: 'Edit name',
                            onTap: _editName,
                          ),
                          if (hasPhoto)
                            _SmallProfileButton(
                              icon: Icons.delete_outline_rounded,
                              label: 'Remove photo',
                              onTap: () =>
                                  context.read<ProfileBloc>().clearPhoto(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditNamePage extends StatefulWidget {
  const _EditNamePage({required this.initialName});

  final String initialName;

  @override
  State<_EditNamePage> createState() => _EditNamePageState();
}

class _EditNamePageState extends State<_EditNamePage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.large,
          AppSpacing.large,
          AppSpacing.large,
          AppSpacing.xLarge,
        ),
        children: <Widget>[
          Text(
            'Name',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.onSurface.withOpacity(0.62),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(
              hintText: 'Enter your name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallProfileButton extends StatelessWidget {
  const _SmallProfileButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.outline.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: colors.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.onSurface.withOpacity(0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.18)),
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: colors.outline.withOpacity(0.14),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(0.09),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: colors.onSurface.withOpacity(0.55),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.onSurface.withOpacity(0.38),
      ),
    );
  }
}

class _ProfileDetailsPanel extends StatelessWidget {
  const _ProfileDetailsPanel({
    required this.age,
    required this.userId,
  });

  final int? age;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.16)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _DetailPill(
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: age == null ? 'Not set' : '$age',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _DetailPill(
                  icon: Icons.public_rounded,
                  label: 'Country',
                  value: 'India',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.monitor_heart_outlined,
                size: 17,
                color: colors.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Uses sleep, activity, weather, focus, and goal progress to keep your daily view personal.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    color: colors.onSurface.withOpacity(0.62),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ID ${userId.length > 10 ? userId.substring(0, 10) : userId}',
              style: TextStyle(
                fontSize: 9.5,
                color: colors.onSurface.withOpacity(0.4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withOpacity(0.14)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: colors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: colors.onSurface.withOpacity(0.48),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withOpacity(0.82),
                    fontWeight: FontWeight.w700,
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
