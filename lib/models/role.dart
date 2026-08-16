// lib/models/role.dart
const List<String> kAllPermissions = [
  'kick_members',
  'ban_members',
  'mute_members',
  'manage_roles',
  'manage_settings',
  'manage_donations',
  'create_polls',
  'post_in_channel',
  'delete_messages',
  'manage_members',
  'manage_slow_mode',
  'view_ban_list',
  'view_mute_list',
  'view_invite_link',
];

class Role {
  final int id;
  final String name;
  final String color;
  final Set<String> permissions;
  final bool isSystem;
  final int memberCount;

  const Role({
    required this.id,
    required this.name,
    required this.color,
    required this.permissions,
    required this.isSystem,
    required this.memberCount,
  });

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: json['id'] as int,
        name: json['name'] as String,
        color: json['color'] as String,
        permissions: (json['permissions'] as List).map((e) => e as String).toSet(),
        isSystem: json['is_system'] == true || json['is_system'] == 1,
        memberCount: json['member_count'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'permissions': permissions.toList(),
        'is_system': isSystem,
        'member_count': memberCount,
      };
}
