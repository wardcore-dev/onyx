// lib/models/profile_preset.dart
import 'dart:convert';

/// A saved username/password profile the user can pick from when joining
/// an external group/channel server, instead of retyping credentials.
class ProfilePreset {
  final String id;
  final String label;
  final int colorIndex; // index into AppTheme.values, Finder-tag style
  final String note;
  final String username;
  final String password;
  final DateTime createdAt;

  ProfilePreset({
    required this.id,
    required this.label,
    required this.colorIndex,
    this.note = '',
    required this.username,
    required this.password,
    required this.createdAt,
  });

  ProfilePreset copyWith({
    String? label,
    int? colorIndex,
    String? note,
    String? username,
    String? password,
  }) {
    return ProfilePreset(
      id: id,
      label: label ?? this.label,
      colorIndex: colorIndex ?? this.colorIndex,
      note: note ?? this.note,
      username: username ?? this.username,
      password: password ?? this.password,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'color_index': colorIndex,
    'note': note,
    'username': username,
    'password': password,
    'created_at': createdAt.toIso8601String(),
  };

  factory ProfilePreset.fromJson(Map<String, dynamic> json) => ProfilePreset(
    id: json['id'],
    label: json['label'] ?? '',
    colorIndex: json['color_index'] ?? 0,
    note: json['note'] ?? '',
    username: json['username'] ?? '',
    password: json['password'] ?? '',
    createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
  );

  static String encodeList(List<ProfilePreset> presets) =>
      jsonEncode(presets.map((p) => p.toJson()).toList());

  static List<ProfilePreset> decodeList(String json) =>
      (jsonDecode(json) as List<dynamic>)
          .map((e) => ProfilePreset.fromJson(e as Map<String, dynamic>))
          .toList();
}
