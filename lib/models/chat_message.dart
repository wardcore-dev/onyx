// lib/models/chat_message.dart
import 'package:flutter/foundation.dart';
import '../enums/delivery_mode.dart';

class ChatMessage {
  final String id;
  final String from;
  final String to;
  bool outgoing;
  bool delivered;
  bool isRead;
  bool pendingSend = false; // true = WS was offline when sent, queued for retry
  final DateTime time;
  final String? rawEnvelopePreview;
  final String? encryptedForDevice;
  int? serverMessageId;
  
  final int? replyToId;
  final String? replyToSender;
  final String? replyToContent;
  final DeliveryMode deliveryMode;
  
  DateTime? deliveredAt;

  /// emoji → [usernames], cached from server
  Map<String, List<String>> reactions;

  String _content;


  String get content => _content;

  ChatMessage({
    required this.id,
    required this.from,
    required this.to,
    required String content,
    required this.outgoing,
    this.delivered = false,
    this.isRead = true,
    DateTime? time,
    this.rawEnvelopePreview,
    this.encryptedForDevice,
    this.serverMessageId,
    this.replyToId,
    this.replyToSender,
    this.replyToContent,
    DeliveryMode? deliveryMode,
    this.deliveredAt,
    Map<String, List<String>>? reactions,
  })  : reactions = reactions ?? {},
        _content = content,
        deliveryMode = deliveryMode ?? DeliveryMode.internet,
        time = time ?? DateTime.now();

  bool get canEditOrDelete {
    if (!outgoing) return false;
    
    if (!delivered && serverMessageId != null) return true;
    final da = deliveredAt;
    if (da == null) return false;
    return DateTime.now().difference(da).inSeconds < 30;
  }

  int get editSecondsLeft {
    
    if (!delivered && serverMessageId != null) return -1;
    final da = deliveredAt;
    if (da == null) return 0;
    final elapsed = DateTime.now().difference(da).inSeconds;
    final left = 30 - elapsed;
    return left > 0 ? left : 0;
  }

  void updateContent(String newContent) {
    _content = newContent;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'content': _content,
    'outgoing': outgoing,
    'delivered': delivered,
    'isRead': isRead,
    'time': time.toIso8601String(),
    'rawEnvelopePreview': rawEnvelopePreview,
    'encryptedForDevice': encryptedForDevice,
    'serverMessageId': serverMessageId,
    'replyToId': replyToId,
    'replyToSender': replyToSender,
    'replyToContent': replyToContent,
    'deliveryMode': deliveryMode.name,
    'deliveredAt': deliveredAt?.toIso8601String(),
    if (reactions.isNotEmpty)
      'reactions': reactions.map((e, u) => MapEntry(e, u)),
  };

  static ChatMessage fromJson(Map<String, dynamic> j) {
    return ChatMessage(
      id: j['id'].toString(),
      from: j['from'] ?? '',
      to: j['to'] ?? '',
      content: j['content'] ?? '',
      outgoing: j['outgoing'] == true,
      delivered: j['delivered'] == true,
      isRead: j['isRead'] != false,
      time: DateTime.tryParse(j['time'] ?? '') ?? DateTime.now(),
      rawEnvelopePreview: j['rawEnvelopePreview'],
      encryptedForDevice: j['encryptedForDevice']?.toString(),
      serverMessageId: j['serverMessageId'] is int
          ? j['serverMessageId'] as int
          : (j['serverMessageId'] != null
                ? int.tryParse(j['serverMessageId'].toString())
                : null),
      replyToId: _parseInt(j['replyToId'] ?? j['reply_to_id']),
      replyToSender: (j['replyToSender'] ?? j['reply_to_sender'])?.toString(),
      replyToContent: (j['replyToContent'] ?? j['reply_to_content'])?.toString(),
      deliveryMode: _parseDeliveryMode(j['deliveryMode']),
      deliveredAt: j['deliveredAt'] != null
          ? DateTime.tryParse(j['deliveredAt'].toString())
          : null,
      reactions: _parseReactions(j['reactions']),
    );
  }

  static Map<String, List<String>> _parseReactions(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(
          k.toString(),
          (v is List) ? v.map((e) => e.toString()).toList() : <String>[],
        ));
  }

  static DeliveryMode _parseDeliveryMode(dynamic value) {
    if (value == null) return DeliveryMode.internet;                              
    final str = value.toString().toLowerCase();
    if (str == 'lan') return DeliveryMode.lan;
    return DeliveryMode.internet;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value != null) return int.tryParse(value.toString());
    return null;
  }
}