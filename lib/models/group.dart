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
      };
}