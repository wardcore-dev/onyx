// lib/models/chat_message.dart
import '../enums/delivery_mode.dart';
import '../enums/mesh_delivery_status.dart';

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

  /// When the message content was last edited (used for WardLink edit sync).
  DateTime? editedAt;

  /// True when this message arrived on this device via WardLink sync from
  /// the device that actually sent it, rather than being sent from here.
  /// This device doesn't "own" the message as far as the server is
  /// concerned, so edit/delete must not be offered for it here — only the
  /// originating device can change or delete it. Never persisted across
  /// server-authoritative reloads; only set on WardLink-imported copies.
  bool isWardLinkCopy;

  /// Name of the device this WardLink copy was pulled from (the device that
  /// actually sent it). Null when [isWardLinkCopy] is false. Shown as a
  /// small badge on the message so the user knows where it originated.
  String? syncedFromDeviceName;

  /// OS of the device named in [syncedFromDeviceName] ('android'/'ios'/
  /// 'windows'/'macos'/'linux', per WardLinkPairedDevice.os), used to pick
  /// a phone vs. computer icon for the sync badge.
  String? syncedFromDeviceOs;

  /// Mesh-only: delivery progress for outgoing bleMesh messages.
  MeshDeliveryStatus? meshDeliveryStatus;

  /// Mesh-only: packet ID used to match incoming ACKs to this message.
  int? meshPacketId;

  /// Mesh-only: which transport was actually used ('wifi' | 'ble' | null=unknown).
  String? meshTransportUsed;

  // ── Mesh file transfer fields (bleMesh only) ──────────────────────────────
  final String? meshFileId;        // unique 16-char hex transfer ID
  final String? meshFileName;      // original filename
  final String? meshFileMimeType;  // e.g. "image/jpeg", "video/mp4"
  final int? meshFileSize;         // total bytes
  String? meshFileLocalPath;       // set when fully received
  double meshFileProgress = 0.0;   // 0.0..1.0, in-memory only

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
    this.editedAt,
    this.isWardLinkCopy = false,
    this.syncedFromDeviceName,
    this.syncedFromDeviceOs,
    this.meshDeliveryStatus,
    this.meshPacketId,
    this.meshFileId,
    this.meshFileName,
    this.meshFileMimeType,
    this.meshFileSize,
    this.meshFileLocalPath,
    this.meshTransportUsed,
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
    if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
    if (isWardLinkCopy) 'isWardLinkCopy': true,
    if (syncedFromDeviceName != null)
      'syncedFromDeviceName': syncedFromDeviceName,
    if (syncedFromDeviceOs != null) 'syncedFromDeviceOs': syncedFromDeviceOs,
    if (meshDeliveryStatus != null) 'meshDeliveryStatus': meshDeliveryStatus!.name,
    if (meshPacketId != null) 'meshPacketId': meshPacketId,
    if (meshFileId != null) 'meshFileId': meshFileId,
    if (meshFileName != null) 'meshFileName': meshFileName,
    if (meshFileMimeType != null) 'meshFileMimeType': meshFileMimeType,
    if (meshFileSize != null) 'meshFileSize': meshFileSize,
    if (meshFileLocalPath != null) 'meshFileLocalPath': meshFileLocalPath,
    if (meshTransportUsed != null) 'meshTransportUsed': meshTransportUsed,
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
      editedAt: j['editedAt'] != null
          ? DateTime.tryParse(j['editedAt'].toString())
          : null,
      isWardLinkCopy: j['isWardLinkCopy'] == true,
      syncedFromDeviceName: j['syncedFromDeviceName']?.toString(),
      syncedFromDeviceOs: j['syncedFromDeviceOs']?.toString(),
      meshDeliveryStatus: _parseMeshDeliveryStatus(j['meshDeliveryStatus']),
      meshPacketId: j['meshPacketId'] is int
          ? j['meshPacketId'] as int
          : (j['meshPacketId'] != null ? int.tryParse(j['meshPacketId'].toString()) : null),
      meshFileId: j['meshFileId']?.toString(),
      meshFileName: j['meshFileName']?.toString(),
      meshFileMimeType: j['meshFileMimeType']?.toString(),
      meshFileSize: j['meshFileSize'] is int
          ? j['meshFileSize'] as int
          : (j['meshFileSize'] != null ? int.tryParse(j['meshFileSize'].toString()) : null),
      meshFileLocalPath: j['meshFileLocalPath']?.toString(),
      meshTransportUsed: j['meshTransportUsed']?.toString(),
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
    if (str == 'blemesh' || str == 'mesh') return DeliveryMode.bleMesh;
    return DeliveryMode.internet;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value != null) return int.tryParse(value.toString());
    return null;
  }

  static MeshDeliveryStatus? _parseMeshDeliveryStatus(dynamic value) {
    if (value == null) return null;
    switch (value.toString()) {
      case 'sending':   return MeshDeliveryStatus.sending;
      case 'relayed':   return MeshDeliveryStatus.relayed;
      case 'delivered': return MeshDeliveryStatus.delivered;
      case 'failed':    return MeshDeliveryStatus.failed;
      default:          return null;
    }
  }
}