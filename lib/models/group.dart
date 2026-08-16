// lib/models/group.dart
class Group {
  final int id;
  final String name;
  final bool isChannel;
  final String owner;
  final String inviteLink;
  final int avatarVersion;
  final String? externalServerId;
  final String? myRole;
  final int slowModeSeconds;
  final String description;
  final int? defaultRoleId;
  final int maxMembers;
  final int maxMessageLength;
  final int maxMessagesPerMinute;
  final Set<String> myPermissions;

  bool get isExternal => externalServerId != null;

  bool get canPost {
    if (!isChannel) return true;

    return myRole == 'owner' || myRole == 'moderator';
  }

  Group({
    required this.id,
    required this.name,
    required this.isChannel,
    required this.owner,
    required this.inviteLink,
    this.avatarVersion = 0,
    this.externalServerId,
    this.myRole,
    this.slowModeSeconds = 0,
    this.description = '',
    this.defaultRoleId,
    this.maxMembers = 0,
    this.maxMessageLength = 0,
    this.maxMessagesPerMinute = 0,
    this.myPermissions = const {},
  });

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'],
        name: json['name'],
        isChannel: json['is_channel'],
        owner: json['owner'],
        inviteLink: json['invite_link'] ?? '',
        avatarVersion: json['avatar_version'] ?? 0,
        externalServerId: json['external_server_id'],
        myRole: json['my_role'],
        slowModeSeconds: json['slow_mode_seconds'] ?? 0,
        description: json['description'] as String? ?? '',
        defaultRoleId: json['default_role_id'] as int?,
        maxMembers: json['max_members'] as int? ?? 0,
        maxMessageLength: json['max_message_length'] as int? ?? 0,
        maxMessagesPerMinute: json['max_messages_per_minute'] as int? ?? 0,
        myPermissions: (json['my_permissions'] as List?)?.map((e) => e as String).toSet() ?? {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_channel': isChannel,
        'owner': owner,
        'invite_link': inviteLink,
        'avatar_version': avatarVersion,
        'external_server_id': externalServerId,
        'my_role': myRole,
        'slow_mode_seconds': slowModeSeconds,
        'description': description,
        'default_role_id': defaultRoleId,
        'max_members': maxMembers,
        'max_message_length': maxMessageLength,
        'max_messages_per_minute': maxMessagesPerMinute,
        'my_permissions': myPermissions.toList(),
      };

  Group copyWith({
    int? id,
    String? name,
    bool? isChannel,
    String? owner,
    String? inviteLink,
    int? avatarVersion,
    String? externalServerId,
    String? myRole,
    int? slowModeSeconds,
    String? description,
    int? defaultRoleId,
    bool clearDefaultRoleId = false,
    int? maxMembers,
    int? maxMessageLength,
    int? maxMessagesPerMinute,
    Set<String>? myPermissions,
  }) =>
      Group(
        id: id ?? this.id,
        name: name ?? this.name,
        isChannel: isChannel ?? this.isChannel,
        owner: owner ?? this.owner,
        inviteLink: inviteLink ?? this.inviteLink,
        avatarVersion: avatarVersion ?? this.avatarVersion,
        externalServerId: externalServerId ?? this.externalServerId,
        myRole: myRole ?? this.myRole,
        slowModeSeconds: slowModeSeconds ?? this.slowModeSeconds,
        description: description ?? this.description,
        defaultRoleId: clearDefaultRoleId ? null : (defaultRoleId ?? this.defaultRoleId),
        maxMembers: maxMembers ?? this.maxMembers,
        maxMessageLength: maxMessageLength ?? this.maxMessageLength,
        maxMessagesPerMinute: maxMessagesPerMinute ?? this.maxMessagesPerMinute,
        myPermissions: myPermissions ?? this.myPermissions,
      );
}
