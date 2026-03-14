// lib/models/external_server.dart
import 'dart:convert';

class ExternalServer {
  final String id; 
  final String host;
  final int port;
  final String name; 
  final String description;
  final String username; 
  final String displayName;
  final String publicKey; 
  final String privateKey; 
  final String token; 
  final String passwordHash; 
  final String mediaProvider;
  final int maxFileSizeMb;
  final int maxMembersPerGroup;
  final List<String> features;
  final DateTime joinedAt;

  ExternalServer({
    required this.id,
    required this.host,
    required this.port,
    required this.name,
    this.description = '',
    required this.username,
    required this.displayName,
    required this.publicKey,
    required this.privateKey,
    required this.token,
    this.passwordHash = '',
    this.mediaProvider = 'local',
    this.maxFileSizeMb = 50,
    this.maxMembersPerGroup = 500,
    this.features = const [],
    required this.joinedAt,
  });

  String get baseUrl => 'http://$host:$port';

  String get wsUrl {
    
    if (token.startsWith('public:')) {
      final publicToken = token.substring('public:'.length);
      return 'ws://$host:$port/ws/public/$publicToken';
    }
    
    return 'ws://$host:$port/ws?token=${Uri.encodeComponent(token)}';
  }

  ExternalServer copyWith({String? token, String? name, String? description, String? passwordHash}) {
    return ExternalServer(
      id: id,
      host: host,
      port: port,
      name: name ?? this.name,
      description: description ?? this.description,
      username: username,
      displayName: displayName,
      publicKey: publicKey,
      privateKey: privateKey,
      token: token ?? this.token,
      passwordHash: passwordHash ?? this.passwordHash,
      mediaProvider: mediaProvider,
      maxFileSizeMb: maxFileSizeMb,
      maxMembersPerGroup: maxMembersPerGroup,
      features: features,
      joinedAt: joinedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'host': host,
    'port': port,
    'name': name,
    'description': description,
    'username': username,
    'display_name': displayName,
    'public_key': publicKey,
    'private_key': privateKey,
    'token': token,
    'password_hash': passwordHash,
    'media_provider': mediaProvider,
    'max_file_size_mb': maxFileSizeMb,
    'max_members_per_group': maxMembersPerGroup,
    'features': features,
    'joined_at': joinedAt.toIso8601String(),
  };

  factory ExternalServer.fromJson(Map<String, dynamic> json) => ExternalServer(
    id: json['id'],
    host: json['host'],
    port: json['port'],
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    username: json['username'],
    displayName: json['display_name'] ?? json['username'],
    publicKey: json['public_key'],
    privateKey: json['private_key'],
    token: json['token'],
    passwordHash: json['password_hash'] ?? '',
    mediaProvider: json['media_provider'] ?? 'local',
    maxFileSizeMb: json['max_file_size_mb'] ?? 50,
    maxMembersPerGroup: json['max_members_per_group'] ?? 500,
    features: (json['features'] as List<dynamic>?)?.cast<String>() ?? [],
    joinedAt: DateTime.tryParse(json['joined_at'] ?? '') ?? DateTime.now(),
  );

  static String encodeList(List<ExternalServer> servers) =>
      jsonEncode(servers.map((s) => s.toJson()).toList());

  static List<ExternalServer> decodeList(String json) =>
      (jsonDecode(json) as List<dynamic>)
          .map((e) => ExternalServer.fromJson(e as Map<String, dynamic>))
          .toList();
}