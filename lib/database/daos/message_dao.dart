import 'dart:convert';
import 'package:drift/drift.dart';
import '../../enums/delivery_mode.dart';
import '../../enums/mesh_delivery_status.dart';
import '../../models/chat_message.dart';
import '../app_database.dart';

part 'message_dao.g.dart';

@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Paginated message list for a chat, newest-first.
  Future<List<Message>> getMessagesPage(
    String chatId,
    String accountId,
    String serverHost, {
    int limit = 50,
    int offset = 0,
  }) {
    return (select(messages)
          ..where((t) =>
              t.chatId.equals(chatId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost))
          ..orderBy([(t) => OrderingTerm.desc(t.timeMs)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Reactive stream of ALL messages for a chat (UI listens to this).
  Stream<List<Message>> watchMessages(
    String chatId,
    String accountId,
    String serverHost,
  ) {
    return (select(messages)
          ..where((t) =>
              t.chatId.equals(chatId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost))
          ..orderBy([(t) => OrderingTerm.asc(t.timeMs)]))
        .watch();
  }

  /// Returns distinct chat IDs with the time of the last message — used to
  /// build the chat list screen.
  Future<List<({String chatId, int lastTimeMs, int unreadCount})>>
      getChatList(String accountId, String serverHost) async {
    final query = customSelect(
      '''
      SELECT chat_id,
             MAX(time_ms) AS last_time_ms,
             SUM(CASE WHEN is_read = 0 AND outgoing = 0 THEN 1 ELSE 0 END)
               AS unread_count
      FROM messages
      WHERE account_id = ? AND server_host = ?
      GROUP BY chat_id
      ORDER BY last_time_ms DESC
      ''',
      variables: [Variable.withString(accountId), Variable.withString(serverHost)],
      readsFrom: {messages},
    );
    final rows = await query.get();
    return rows
        .map((r) => (
              chatId: r.read<String>('chat_id'),
              lastTimeMs: r.read<int>('last_time_ms'),
              unreadCount: r.read<int>('unread_count'),
            ))
        .toList();
  }

  Future<int> getUnreadCount(
    String chatId,
    String accountId,
    String serverHost,
  ) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM messages '
      'WHERE chat_id = ? AND account_id = ? AND server_host = ? '
      'AND is_read = 0 AND outgoing = 0',
      variables: [
        Variable.withString(chatId),
        Variable.withString(accountId),
        Variable.withString(serverHost),
      ],
      readsFrom: {messages},
    ).getSingle();
    return result.read<int>('cnt');
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  Future<void> upsertMessage(MessagesCompanion entry) {
    return into(messages).insertOnConflictUpdate(entry);
  }

  Future<void> upsertMessages(List<MessagesCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(messages, entries));
  }

  Future<void> updateDelivered(
    String messageId,
    String accountId,
    String serverHost, {
    required bool delivered,
    int? serverMsgId,
    DateTime? deliveredAt,
  }) {
    return (update(messages)
          ..where((t) =>
              t.messageId.equals(messageId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .write(MessagesCompanion(
      delivered: Value(delivered),
      serverMessageId:
          serverMsgId != null ? Value(serverMsgId) : const Value.absent(),
      deliveredAtMs: deliveredAt != null
          ? Value(deliveredAt.millisecondsSinceEpoch)
          : const Value.absent(),
    ));
  }

  Future<void> markAllRead(
    String chatId,
    String accountId,
    String serverHost,
  ) {
    return (update(messages)
          ..where((t) =>
              t.chatId.equals(chatId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost) &
              t.outgoing.equals(false)))
        .write(const MessagesCompanion(isRead: Value(true)));
  }

  Future<void> updateContent(
    String messageId,
    String accountId,
    String serverHost,
    String newContent,
  ) {
    return (update(messages)
          ..where((t) =>
              t.messageId.equals(messageId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .write(MessagesCompanion(content: Value(newContent)));
  }

  Future<void> updateReactions(
    String messageId,
    String accountId,
    String serverHost,
    Map<String, List<String>> reactions,
  ) {
    return (update(messages)
          ..where((t) =>
              t.messageId.equals(messageId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .write(MessagesCompanion(
            reactionsJson: Value(jsonEncode(reactions))));
  }

  Future<int> deleteMessage(
    String messageId,
    String accountId,
    String serverHost,
  ) {
    return (delete(messages)
          ..where((t) =>
              t.messageId.equals(messageId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .go();
  }

  Future<int> deleteChat(
    String chatId,
    String accountId,
    String serverHost,
  ) {
    return (delete(messages)
          ..where((t) =>
              t.chatId.equals(chatId) &
              t.accountId.equals(accountId) &
              t.serverHost.equals(serverHost)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // Conversion helpers
  // ---------------------------------------------------------------------------

  static MessagesCompanion fromChatMessage(
    ChatMessage msg,
    String chatId,
    String accountId,
    String serverHost,
  ) {
    return MessagesCompanion(
      messageId: Value(msg.id),
      chatId: Value(chatId),
      accountId: Value(accountId),
      serverHost: Value(serverHost),
      fromUser: Value(msg.from),
      toUser: Value(msg.to),
      content: Value(msg.content),
      outgoing: Value(msg.outgoing),
      delivered: Value(msg.delivered),
      isRead: Value(msg.isRead),
      pendingSend: Value(msg.pendingSend),
      timeMs: Value(msg.time.millisecondsSinceEpoch),
      rawEnvelopePreview: Value(msg.rawEnvelopePreview),
      encryptedForDevice: Value(msg.encryptedForDevice),
      serverMessageId: Value(msg.serverMessageId),
      replyToId: Value(msg.replyToId),
      replyToSender: Value(msg.replyToSender),
      replyToContent: Value(msg.replyToContent),
      deliveryMode: Value(msg.deliveryMode.name),
      deliveredAtMs:
          Value(msg.deliveredAt?.millisecondsSinceEpoch),
      reactionsJson: msg.reactions.isEmpty
          ? const Value(null)
          : Value(jsonEncode(msg.reactions)),
      meshMetaJson: _encodeMeshMeta(msg),
    );
  }

  static Value<String?> _encodeMeshMeta(ChatMessage msg) {
    if (msg.meshFileId == null &&
        msg.meshFileName == null &&
        msg.meshFileMimeType == null &&
        msg.meshFileSize == null &&
        msg.meshFileLocalPath == null &&
        msg.meshTransportUsed == null &&
        msg.meshDeliveryStatus == null) {
      return const Value(null);
    }
    return Value(jsonEncode({
      if (msg.meshFileId != null) 'fileId': msg.meshFileId,
      if (msg.meshFileName != null) 'fileName': msg.meshFileName,
      if (msg.meshFileMimeType != null) 'mimeType': msg.meshFileMimeType,
      if (msg.meshFileSize != null) 'fileSize': msg.meshFileSize,
      if (msg.meshFileLocalPath != null) 'localPath': msg.meshFileLocalPath,
      if (msg.meshTransportUsed != null) 'transport': msg.meshTransportUsed,
      if (msg.meshDeliveryStatus != null) 'deliveryStatus': msg.meshDeliveryStatus!.name,
    }));
  }

  static ChatMessage toChatMessage(Message row) {
    Map<String, List<String>> reactions = {};
    if (row.reactionsJson != null) {
      try {
        final decoded = jsonDecode(row.reactionsJson!) as Map<String, dynamic>;
        reactions = decoded.map((k, v) => MapEntry(
              k,
              (v as List).map((e) => e.toString()).toList(),
            ));
      } catch (_) {}
    }
    Map<String, dynamic> meshMeta = {};
    if (row.meshMetaJson != null) {
      try {
        meshMeta = jsonDecode(row.meshMetaJson!) as Map<String, dynamic>;
      } catch (_) {}
    }
    MeshDeliveryStatus? meshDeliveryStatus;
    final statusStr = meshMeta['deliveryStatus'] as String?;
    if (statusStr != null) {
      meshDeliveryStatus = MeshDeliveryStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => MeshDeliveryStatus.delivered,
      );
    }
    return ChatMessage(
      id: row.messageId,
      from: row.fromUser,
      to: row.toUser,
      content: row.content,
      outgoing: row.outgoing,
      delivered: row.delivered,
      isRead: row.isRead,
      time: DateTime.fromMillisecondsSinceEpoch(row.timeMs),
      rawEnvelopePreview: row.rawEnvelopePreview,
      encryptedForDevice: row.encryptedForDevice,
      serverMessageId: row.serverMessageId,
      replyToId: row.replyToId,
      replyToSender: row.replyToSender,
      replyToContent: row.replyToContent,
      deliveryMode: row.deliveryMode == 'lan'
          ? DeliveryMode.lan
          : row.deliveryMode == 'bleMesh'
              ? DeliveryMode.bleMesh
              : DeliveryMode.internet,
      deliveredAt: row.deliveredAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(row.deliveredAtMs!)
          : null,
      reactions: reactions,
      meshFileId: meshMeta['fileId'] as String?,
      meshFileName: meshMeta['fileName'] as String?,
      meshFileMimeType: meshMeta['mimeType'] as String?,
      meshFileSize: meshMeta['fileSize'] as int?,
      meshFileLocalPath: meshMeta['localPath'] as String?,
      meshTransportUsed: meshMeta['transport'] as String?,
      meshDeliveryStatus: meshDeliveryStatus,
    )..pendingSend = row.pendingSend;
  }
}
