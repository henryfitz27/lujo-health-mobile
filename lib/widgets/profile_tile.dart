import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/models/profile.dart';
import '../app/router.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.radius = 20,
  });

  final String name;
  final String avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
          : null,
    );
  }
}

/// Fila de perfil que navega al perfil público al tocarla.
class ProfileTile extends StatelessWidget {
  const ProfileTile({super.key, required this.profile, this.trailing});

  final ProfileSummary profile;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final username = profile.username;
    return ListTile(
      leading: ProfileAvatar(name: profile.name, avatarUrl: profile.avatarUrl),
      title: Text(profile.name.isNotEmpty ? profile.name : (username ?? '')),
      subtitle: username != null ? Text('@$username') : null,
      trailing: trailing,
      onTap: username != null
          ? () => context.push(Routes.user(username))
          : null,
    );
  }
}
