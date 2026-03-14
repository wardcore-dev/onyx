import 'package:flutter/foundation.dart';

class FavoriteChat {
  final String id;
  final String title;
  final String? avatarPath;
  final DateTime createdAt;

  const FavoriteChat({
    required this.id,
    required this.title,
    this.avatarPath,
    required this.createdAt,
  });

  factory FavoriteChat.create(String title) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return FavoriteChat(
      id: id,
      title: title,
      createdAt: DateTime.now(),
    );
  }

  factory FavoriteChat.fromJson(Map<String, dynamic> json) => FavoriteChat(
        id: json['id'] as String,
        title: json['title'] as String,
        avatarPath: json['avatarPath'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'avatarPath': avatarPath,
        'createdAt': createdAt.toIso8601String(),
      };

  FavoriteChat copyWith({
    String? id,
    String? title,
    String? avatarPath,
    DateTime? createdAt,
  }) {
    return FavoriteChat(
      id: id ?? this.id,
      title: title ?? this.title,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}