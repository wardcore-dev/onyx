// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
      'chat_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverHostMeta =
      const VerificationMeta('serverHost');
  @override
  late final GeneratedColumn<String> serverHost = GeneratedColumn<String>(
      'server_host', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fromUserMeta =
      const VerificationMeta('fromUser');
  @override
  late final GeneratedColumn<String> fromUser = GeneratedColumn<String>(
      'from_user', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _toUserMeta = const VerificationMeta('toUser');
  @override
  late final GeneratedColumn<String> toUser = GeneratedColumn<String>(
      'to_user', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _outgoingMeta =
      const VerificationMeta('outgoing');
  @override
  late final GeneratedColumn<bool> outgoing = GeneratedColumn<bool>(
      'outgoing', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("outgoing" IN (0, 1))'));
  static const VerificationMeta _deliveredMeta =
      const VerificationMeta('delivered');
  @override
  late final GeneratedColumn<bool> delivered = GeneratedColumn<bool>(
      'delivered', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("delivered" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
      'is_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_read" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _pendingSendMeta =
      const VerificationMeta('pendingSend');
  @override
  late final GeneratedColumn<bool> pendingSend = GeneratedColumn<bool>(
      'pending_send', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("pending_send" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _timeMsMeta = const VerificationMeta('timeMs');
  @override
  late final GeneratedColumn<int> timeMs = GeneratedColumn<int>(
      'time_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rawEnvelopePreviewMeta =
      const VerificationMeta('rawEnvelopePreview');
  @override
  late final GeneratedColumn<String> rawEnvelopePreview =
      GeneratedColumn<String>('raw_envelope_preview', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _encryptedForDeviceMeta =
      const VerificationMeta('encryptedForDevice');
  @override
  late final GeneratedColumn<String> encryptedForDevice =
      GeneratedColumn<String>('encrypted_for_device', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _serverMessageIdMeta =
      const VerificationMeta('serverMessageId');
  @override
  late final GeneratedColumn<int> serverMessageId = GeneratedColumn<int>(
      'server_message_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _replyToIdMeta =
      const VerificationMeta('replyToId');
  @override
  late final GeneratedColumn<int> replyToId = GeneratedColumn<int>(
      'reply_to_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _replyToSenderMeta =
      const VerificationMeta('replyToSender');
  @override
  late final GeneratedColumn<String> replyToSender = GeneratedColumn<String>(
      'reply_to_sender', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _replyToContentMeta =
      const VerificationMeta('replyToContent');
  @override
  late final GeneratedColumn<String> replyToContent = GeneratedColumn<String>(
      'reply_to_content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deliveryModeMeta =
      const VerificationMeta('deliveryMode');
  @override
  late final GeneratedColumn<String> deliveryMode = GeneratedColumn<String>(
      'delivery_mode', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('internet'));
  static const VerificationMeta _deliveredAtMsMeta =
      const VerificationMeta('deliveredAtMs');
  @override
  late final GeneratedColumn<int> deliveredAtMs = GeneratedColumn<int>(
      'delivered_at_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _reactionsJsonMeta =
      const VerificationMeta('reactionsJson');
  @override
  late final GeneratedColumn<String> reactionsJson = GeneratedColumn<String>(
      'reactions_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _meshMetaJsonMeta =
      const VerificationMeta('meshMetaJson');
  @override
  late final GeneratedColumn<String> meshMetaJson = GeneratedColumn<String>(
      'mesh_meta_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        messageId,
        chatId,
        accountId,
        serverHost,
        fromUser,
        toUser,
        content,
        outgoing,
        delivered,
        isRead,
        pendingSend,
        timeMs,
        rawEnvelopePreview,
        encryptedForDevice,
        serverMessageId,
        replyToId,
        replyToSender,
        replyToContent,
        deliveryMode,
        deliveredAtMs,
        reactionsJson,
        meshMetaJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<Message> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(_chatIdMeta,
          chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta));
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('server_host')) {
      context.handle(
          _serverHostMeta,
          serverHost.isAcceptableOrUnknown(
              data['server_host']!, _serverHostMeta));
    } else if (isInserting) {
      context.missing(_serverHostMeta);
    }
    if (data.containsKey('from_user')) {
      context.handle(_fromUserMeta,
          fromUser.isAcceptableOrUnknown(data['from_user']!, _fromUserMeta));
    } else if (isInserting) {
      context.missing(_fromUserMeta);
    }
    if (data.containsKey('to_user')) {
      context.handle(_toUserMeta,
          toUser.isAcceptableOrUnknown(data['to_user']!, _toUserMeta));
    } else if (isInserting) {
      context.missing(_toUserMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('outgoing')) {
      context.handle(_outgoingMeta,
          outgoing.isAcceptableOrUnknown(data['outgoing']!, _outgoingMeta));
    } else if (isInserting) {
      context.missing(_outgoingMeta);
    }
    if (data.containsKey('delivered')) {
      context.handle(_deliveredMeta,
          delivered.isAcceptableOrUnknown(data['delivered']!, _deliveredMeta));
    }
    if (data.containsKey('is_read')) {
      context.handle(_isReadMeta,
          isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta));
    }
    if (data.containsKey('pending_send')) {
      context.handle(
          _pendingSendMeta,
          pendingSend.isAcceptableOrUnknown(
              data['pending_send']!, _pendingSendMeta));
    }
    if (data.containsKey('time_ms')) {
      context.handle(_timeMsMeta,
          timeMs.isAcceptableOrUnknown(data['time_ms']!, _timeMsMeta));
    } else if (isInserting) {
      context.missing(_timeMsMeta);
    }
    if (data.containsKey('raw_envelope_preview')) {
      context.handle(
          _rawEnvelopePreviewMeta,
          rawEnvelopePreview.isAcceptableOrUnknown(
              data['raw_envelope_preview']!, _rawEnvelopePreviewMeta));
    }
    if (data.containsKey('encrypted_for_device')) {
      context.handle(
          _encryptedForDeviceMeta,
          encryptedForDevice.isAcceptableOrUnknown(
              data['encrypted_for_device']!, _encryptedForDeviceMeta));
    }
    if (data.containsKey('server_message_id')) {
      context.handle(
          _serverMessageIdMeta,
          serverMessageId.isAcceptableOrUnknown(
              data['server_message_id']!, _serverMessageIdMeta));
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
          _replyToIdMeta,
          replyToId.isAcceptableOrUnknown(
              data['reply_to_id']!, _replyToIdMeta));
    }
    if (data.containsKey('reply_to_sender')) {
      context.handle(
          _replyToSenderMeta,
          replyToSender.isAcceptableOrUnknown(
              data['reply_to_sender']!, _replyToSenderMeta));
    }
    if (data.containsKey('reply_to_content')) {
      context.handle(
          _replyToContentMeta,
          replyToContent.isAcceptableOrUnknown(
              data['reply_to_content']!, _replyToContentMeta));
    }
    if (data.containsKey('delivery_mode')) {
      context.handle(
          _deliveryModeMeta,
          deliveryMode.isAcceptableOrUnknown(
              data['delivery_mode']!, _deliveryModeMeta));
    }
    if (data.containsKey('delivered_at_ms')) {
      context.handle(
          _deliveredAtMsMeta,
          deliveredAtMs.isAcceptableOrUnknown(
              data['delivered_at_ms']!, _deliveredAtMsMeta));
    }
    if (data.containsKey('reactions_json')) {
      context.handle(
          _reactionsJsonMeta,
          reactionsJson.isAcceptableOrUnknown(
              data['reactions_json']!, _reactionsJsonMeta));
    }
    if (data.containsKey('mesh_meta_json')) {
      context.handle(
          _meshMetaJsonMeta,
          meshMetaJson.isAcceptableOrUnknown(
              data['mesh_meta_json']!, _meshMetaJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, accountId, serverHost};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      chatId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      serverHost: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_host'])!,
      fromUser: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_user'])!,
      toUser: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_user'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      outgoing: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}outgoing'])!,
      delivered: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}delivered'])!,
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
      pendingSend: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pending_send'])!,
      timeMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time_ms'])!,
      rawEnvelopePreview: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}raw_envelope_preview']),
      encryptedForDevice: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}encrypted_for_device']),
      serverMessageId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_message_id']),
      replyToId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reply_to_id']),
      replyToSender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reply_to_sender']),
      replyToContent: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reply_to_content']),
      deliveryMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}delivery_mode'])!,
      deliveredAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}delivered_at_ms']),
      reactionsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reactions_json']),
      meshMetaJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mesh_meta_json']),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String messageId;
  final String chatId;
  final String accountId;
  final String serverHost;
  final String fromUser;
  final String toUser;
  final String content;
  final bool outgoing;
  final bool delivered;
  final bool isRead;
  final bool pendingSend;
  final int timeMs;
  final String? rawEnvelopePreview;
  final String? encryptedForDevice;
  final int? serverMessageId;
  final int? replyToId;
  final String? replyToSender;
  final String? replyToContent;
  final String deliveryMode;
  final int? deliveredAtMs;
  final String? reactionsJson;
  final String? meshMetaJson;
  const Message(
      {required this.messageId,
      required this.chatId,
      required this.accountId,
      required this.serverHost,
      required this.fromUser,
      required this.toUser,
      required this.content,
      required this.outgoing,
      required this.delivered,
      required this.isRead,
      required this.pendingSend,
      required this.timeMs,
      this.rawEnvelopePreview,
      this.encryptedForDevice,
      this.serverMessageId,
      this.replyToId,
      this.replyToSender,
      this.replyToContent,
      required this.deliveryMode,
      this.deliveredAtMs,
      this.reactionsJson,
      this.meshMetaJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['chat_id'] = Variable<String>(chatId);
    map['account_id'] = Variable<String>(accountId);
    map['server_host'] = Variable<String>(serverHost);
    map['from_user'] = Variable<String>(fromUser);
    map['to_user'] = Variable<String>(toUser);
    map['content'] = Variable<String>(content);
    map['outgoing'] = Variable<bool>(outgoing);
    map['delivered'] = Variable<bool>(delivered);
    map['is_read'] = Variable<bool>(isRead);
    map['pending_send'] = Variable<bool>(pendingSend);
    map['time_ms'] = Variable<int>(timeMs);
    if (!nullToAbsent || rawEnvelopePreview != null) {
      map['raw_envelope_preview'] = Variable<String>(rawEnvelopePreview);
    }
    if (!nullToAbsent || encryptedForDevice != null) {
      map['encrypted_for_device'] = Variable<String>(encryptedForDevice);
    }
    if (!nullToAbsent || serverMessageId != null) {
      map['server_message_id'] = Variable<int>(serverMessageId);
    }
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<int>(replyToId);
    }
    if (!nullToAbsent || replyToSender != null) {
      map['reply_to_sender'] = Variable<String>(replyToSender);
    }
    if (!nullToAbsent || replyToContent != null) {
      map['reply_to_content'] = Variable<String>(replyToContent);
    }
    map['delivery_mode'] = Variable<String>(deliveryMode);
    if (!nullToAbsent || deliveredAtMs != null) {
      map['delivered_at_ms'] = Variable<int>(deliveredAtMs);
    }
    if (!nullToAbsent || reactionsJson != null) {
      map['reactions_json'] = Variable<String>(reactionsJson);
    }
    if (!nullToAbsent || meshMetaJson != null) {
      map['mesh_meta_json'] = Variable<String>(meshMetaJson);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      messageId: Value(messageId),
      chatId: Value(chatId),
      accountId: Value(accountId),
      serverHost: Value(serverHost),
      fromUser: Value(fromUser),
      toUser: Value(toUser),
      content: Value(content),
      outgoing: Value(outgoing),
      delivered: Value(delivered),
      isRead: Value(isRead),
      pendingSend: Value(pendingSend),
      timeMs: Value(timeMs),
      rawEnvelopePreview: rawEnvelopePreview == null && nullToAbsent
          ? const Value.absent()
          : Value(rawEnvelopePreview),
      encryptedForDevice: encryptedForDevice == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedForDevice),
      serverMessageId: serverMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverMessageId),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      replyToSender: replyToSender == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToSender),
      replyToContent: replyToContent == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToContent),
      deliveryMode: Value(deliveryMode),
      deliveredAtMs: deliveredAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAtMs),
      reactionsJson: reactionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(reactionsJson),
      meshMetaJson: meshMetaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(meshMetaJson),
    );
  }

  factory Message.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      messageId: serializer.fromJson<String>(json['messageId']),
      chatId: serializer.fromJson<String>(json['chatId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      serverHost: serializer.fromJson<String>(json['serverHost']),
      fromUser: serializer.fromJson<String>(json['fromUser']),
      toUser: serializer.fromJson<String>(json['toUser']),
      content: serializer.fromJson<String>(json['content']),
      outgoing: serializer.fromJson<bool>(json['outgoing']),
      delivered: serializer.fromJson<bool>(json['delivered']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      pendingSend: serializer.fromJson<bool>(json['pendingSend']),
      timeMs: serializer.fromJson<int>(json['timeMs']),
      rawEnvelopePreview:
          serializer.fromJson<String?>(json['rawEnvelopePreview']),
      encryptedForDevice:
          serializer.fromJson<String?>(json['encryptedForDevice']),
      serverMessageId: serializer.fromJson<int?>(json['serverMessageId']),
      replyToId: serializer.fromJson<int?>(json['replyToId']),
      replyToSender: serializer.fromJson<String?>(json['replyToSender']),
      replyToContent: serializer.fromJson<String?>(json['replyToContent']),
      deliveryMode: serializer.fromJson<String>(json['deliveryMode']),
      deliveredAtMs: serializer.fromJson<int?>(json['deliveredAtMs']),
      reactionsJson: serializer.fromJson<String?>(json['reactionsJson']),
      meshMetaJson: serializer.fromJson<String?>(json['meshMetaJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'chatId': serializer.toJson<String>(chatId),
      'accountId': serializer.toJson<String>(accountId),
      'serverHost': serializer.toJson<String>(serverHost),
      'fromUser': serializer.toJson<String>(fromUser),
      'toUser': serializer.toJson<String>(toUser),
      'content': serializer.toJson<String>(content),
      'outgoing': serializer.toJson<bool>(outgoing),
      'delivered': serializer.toJson<bool>(delivered),
      'isRead': serializer.toJson<bool>(isRead),
      'pendingSend': serializer.toJson<bool>(pendingSend),
      'timeMs': serializer.toJson<int>(timeMs),
      'rawEnvelopePreview': serializer.toJson<String?>(rawEnvelopePreview),
      'encryptedForDevice': serializer.toJson<String?>(encryptedForDevice),
      'serverMessageId': serializer.toJson<int?>(serverMessageId),
      'replyToId': serializer.toJson<int?>(replyToId),
      'replyToSender': serializer.toJson<String?>(replyToSender),
      'replyToContent': serializer.toJson<String?>(replyToContent),
      'deliveryMode': serializer.toJson<String>(deliveryMode),
      'deliveredAtMs': serializer.toJson<int?>(deliveredAtMs),
      'reactionsJson': serializer.toJson<String?>(reactionsJson),
      'meshMetaJson': serializer.toJson<String?>(meshMetaJson),
    };
  }

  Message copyWith(
          {String? messageId,
          String? chatId,
          String? accountId,
          String? serverHost,
          String? fromUser,
          String? toUser,
          String? content,
          bool? outgoing,
          bool? delivered,
          bool? isRead,
          bool? pendingSend,
          int? timeMs,
          Value<String?> rawEnvelopePreview = const Value.absent(),
          Value<String?> encryptedForDevice = const Value.absent(),
          Value<int?> serverMessageId = const Value.absent(),
          Value<int?> replyToId = const Value.absent(),
          Value<String?> replyToSender = const Value.absent(),
          Value<String?> replyToContent = const Value.absent(),
          String? deliveryMode,
          Value<int?> deliveredAtMs = const Value.absent(),
          Value<String?> reactionsJson = const Value.absent(),
          Value<String?> meshMetaJson = const Value.absent()}) =>
      Message(
        messageId: messageId ?? this.messageId,
        chatId: chatId ?? this.chatId,
        accountId: accountId ?? this.accountId,
        serverHost: serverHost ?? this.serverHost,
        fromUser: fromUser ?? this.fromUser,
        toUser: toUser ?? this.toUser,
        content: content ?? this.content,
        outgoing: outgoing ?? this.outgoing,
        delivered: delivered ?? this.delivered,
        isRead: isRead ?? this.isRead,
        pendingSend: pendingSend ?? this.pendingSend,
        timeMs: timeMs ?? this.timeMs,
        rawEnvelopePreview: rawEnvelopePreview.present
            ? rawEnvelopePreview.value
            : this.rawEnvelopePreview,
        encryptedForDevice: encryptedForDevice.present
            ? encryptedForDevice.value
            : this.encryptedForDevice,
        serverMessageId: serverMessageId.present
            ? serverMessageId.value
            : this.serverMessageId,
        replyToId: replyToId.present ? replyToId.value : this.replyToId,
        replyToSender:
            replyToSender.present ? replyToSender.value : this.replyToSender,
        replyToContent:
            replyToContent.present ? replyToContent.value : this.replyToContent,
        deliveryMode: deliveryMode ?? this.deliveryMode,
        deliveredAtMs:
            deliveredAtMs.present ? deliveredAtMs.value : this.deliveredAtMs,
        reactionsJson:
            reactionsJson.present ? reactionsJson.value : this.reactionsJson,
        meshMetaJson:
            meshMetaJson.present ? meshMetaJson.value : this.meshMetaJson,
      );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      serverHost:
          data.serverHost.present ? data.serverHost.value : this.serverHost,
      fromUser: data.fromUser.present ? data.fromUser.value : this.fromUser,
      toUser: data.toUser.present ? data.toUser.value : this.toUser,
      content: data.content.present ? data.content.value : this.content,
      outgoing: data.outgoing.present ? data.outgoing.value : this.outgoing,
      delivered: data.delivered.present ? data.delivered.value : this.delivered,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      pendingSend:
          data.pendingSend.present ? data.pendingSend.value : this.pendingSend,
      timeMs: data.timeMs.present ? data.timeMs.value : this.timeMs,
      rawEnvelopePreview: data.rawEnvelopePreview.present
          ? data.rawEnvelopePreview.value
          : this.rawEnvelopePreview,
      encryptedForDevice: data.encryptedForDevice.present
          ? data.encryptedForDevice.value
          : this.encryptedForDevice,
      serverMessageId: data.serverMessageId.present
          ? data.serverMessageId.value
          : this.serverMessageId,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      replyToSender: data.replyToSender.present
          ? data.replyToSender.value
          : this.replyToSender,
      replyToContent: data.replyToContent.present
          ? data.replyToContent.value
          : this.replyToContent,
      deliveryMode: data.deliveryMode.present
          ? data.deliveryMode.value
          : this.deliveryMode,
      deliveredAtMs: data.deliveredAtMs.present
          ? data.deliveredAtMs.value
          : this.deliveredAtMs,
      reactionsJson: data.reactionsJson.present
          ? data.reactionsJson.value
          : this.reactionsJson,
      meshMetaJson: data.meshMetaJson.present
          ? data.meshMetaJson.value
          : this.meshMetaJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('messageId: $messageId, ')
          ..write('chatId: $chatId, ')
          ..write('accountId: $accountId, ')
          ..write('serverHost: $serverHost, ')
          ..write('fromUser: $fromUser, ')
          ..write('toUser: $toUser, ')
          ..write('content: $content, ')
          ..write('outgoing: $outgoing, ')
          ..write('delivered: $delivered, ')
          ..write('isRead: $isRead, ')
          ..write('pendingSend: $pendingSend, ')
          ..write('timeMs: $timeMs, ')
          ..write('rawEnvelopePreview: $rawEnvelopePreview, ')
          ..write('encryptedForDevice: $encryptedForDevice, ')
          ..write('serverMessageId: $serverMessageId, ')
          ..write('replyToId: $replyToId, ')
          ..write('replyToSender: $replyToSender, ')
          ..write('replyToContent: $replyToContent, ')
          ..write('deliveryMode: $deliveryMode, ')
          ..write('deliveredAtMs: $deliveredAtMs, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('meshMetaJson: $meshMetaJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        messageId,
        chatId,
        accountId,
        serverHost,
        fromUser,
        toUser,
        content,
        outgoing,
        delivered,
        isRead,
        pendingSend,
        timeMs,
        rawEnvelopePreview,
        encryptedForDevice,
        serverMessageId,
        replyToId,
        replyToSender,
        replyToContent,
        deliveryMode,
        deliveredAtMs,
        reactionsJson,
        meshMetaJson
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.messageId == this.messageId &&
          other.chatId == this.chatId &&
          other.accountId == this.accountId &&
          other.serverHost == this.serverHost &&
          other.fromUser == this.fromUser &&
          other.toUser == this.toUser &&
          other.content == this.content &&
          other.outgoing == this.outgoing &&
          other.delivered == this.delivered &&
          other.isRead == this.isRead &&
          other.pendingSend == this.pendingSend &&
          other.timeMs == this.timeMs &&
          other.rawEnvelopePreview == this.rawEnvelopePreview &&
          other.encryptedForDevice == this.encryptedForDevice &&
          other.serverMessageId == this.serverMessageId &&
          other.replyToId == this.replyToId &&
          other.replyToSender == this.replyToSender &&
          other.replyToContent == this.replyToContent &&
          other.deliveryMode == this.deliveryMode &&
          other.deliveredAtMs == this.deliveredAtMs &&
          other.reactionsJson == this.reactionsJson &&
          other.meshMetaJson == this.meshMetaJson);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> messageId;
  final Value<String> chatId;
  final Value<String> accountId;
  final Value<String> serverHost;
  final Value<String> fromUser;
  final Value<String> toUser;
  final Value<String> content;
  final Value<bool> outgoing;
  final Value<bool> delivered;
  final Value<bool> isRead;
  final Value<bool> pendingSend;
  final Value<int> timeMs;
  final Value<String?> rawEnvelopePreview;
  final Value<String?> encryptedForDevice;
  final Value<int?> serverMessageId;
  final Value<int?> replyToId;
  final Value<String?> replyToSender;
  final Value<String?> replyToContent;
  final Value<String> deliveryMode;
  final Value<int?> deliveredAtMs;
  final Value<String?> reactionsJson;
  final Value<String?> meshMetaJson;
  final Value<int> rowid;
  const MessagesCompanion({
    this.messageId = const Value.absent(),
    this.chatId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.serverHost = const Value.absent(),
    this.fromUser = const Value.absent(),
    this.toUser = const Value.absent(),
    this.content = const Value.absent(),
    this.outgoing = const Value.absent(),
    this.delivered = const Value.absent(),
    this.isRead = const Value.absent(),
    this.pendingSend = const Value.absent(),
    this.timeMs = const Value.absent(),
    this.rawEnvelopePreview = const Value.absent(),
    this.encryptedForDevice = const Value.absent(),
    this.serverMessageId = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.replyToSender = const Value.absent(),
    this.replyToContent = const Value.absent(),
    this.deliveryMode = const Value.absent(),
    this.deliveredAtMs = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.meshMetaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String messageId,
    required String chatId,
    required String accountId,
    required String serverHost,
    required String fromUser,
    required String toUser,
    required String content,
    required bool outgoing,
    this.delivered = const Value.absent(),
    this.isRead = const Value.absent(),
    this.pendingSend = const Value.absent(),
    required int timeMs,
    this.rawEnvelopePreview = const Value.absent(),
    this.encryptedForDevice = const Value.absent(),
    this.serverMessageId = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.replyToSender = const Value.absent(),
    this.replyToContent = const Value.absent(),
    this.deliveryMode = const Value.absent(),
    this.deliveredAtMs = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.meshMetaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : messageId = Value(messageId),
        chatId = Value(chatId),
        accountId = Value(accountId),
        serverHost = Value(serverHost),
        fromUser = Value(fromUser),
        toUser = Value(toUser),
        content = Value(content),
        outgoing = Value(outgoing),
        timeMs = Value(timeMs);
  static Insertable<Message> custom({
    Expression<String>? messageId,
    Expression<String>? chatId,
    Expression<String>? accountId,
    Expression<String>? serverHost,
    Expression<String>? fromUser,
    Expression<String>? toUser,
    Expression<String>? content,
    Expression<bool>? outgoing,
    Expression<bool>? delivered,
    Expression<bool>? isRead,
    Expression<bool>? pendingSend,
    Expression<int>? timeMs,
    Expression<String>? rawEnvelopePreview,
    Expression<String>? encryptedForDevice,
    Expression<int>? serverMessageId,
    Expression<int>? replyToId,
    Expression<String>? replyToSender,
    Expression<String>? replyToContent,
    Expression<String>? deliveryMode,
    Expression<int>? deliveredAtMs,
    Expression<String>? reactionsJson,
    Expression<String>? meshMetaJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (chatId != null) 'chat_id': chatId,
      if (accountId != null) 'account_id': accountId,
      if (serverHost != null) 'server_host': serverHost,
      if (fromUser != null) 'from_user': fromUser,
      if (toUser != null) 'to_user': toUser,
      if (content != null) 'content': content,
      if (outgoing != null) 'outgoing': outgoing,
      if (delivered != null) 'delivered': delivered,
      if (isRead != null) 'is_read': isRead,
      if (pendingSend != null) 'pending_send': pendingSend,
      if (timeMs != null) 'time_ms': timeMs,
      if (rawEnvelopePreview != null)
        'raw_envelope_preview': rawEnvelopePreview,
      if (encryptedForDevice != null)
        'encrypted_for_device': encryptedForDevice,
      if (serverMessageId != null) 'server_message_id': serverMessageId,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyToSender != null) 'reply_to_sender': replyToSender,
      if (replyToContent != null) 'reply_to_content': replyToContent,
      if (deliveryMode != null) 'delivery_mode': deliveryMode,
      if (deliveredAtMs != null) 'delivered_at_ms': deliveredAtMs,
      if (reactionsJson != null) 'reactions_json': reactionsJson,
      if (meshMetaJson != null) 'mesh_meta_json': meshMetaJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith(
      {Value<String>? messageId,
      Value<String>? chatId,
      Value<String>? accountId,
      Value<String>? serverHost,
      Value<String>? fromUser,
      Value<String>? toUser,
      Value<String>? content,
      Value<bool>? outgoing,
      Value<bool>? delivered,
      Value<bool>? isRead,
      Value<bool>? pendingSend,
      Value<int>? timeMs,
      Value<String?>? rawEnvelopePreview,
      Value<String?>? encryptedForDevice,
      Value<int?>? serverMessageId,
      Value<int?>? replyToId,
      Value<String?>? replyToSender,
      Value<String?>? replyToContent,
      Value<String>? deliveryMode,
      Value<int?>? deliveredAtMs,
      Value<String?>? reactionsJson,
      Value<String?>? meshMetaJson,
      Value<int>? rowid}) {
    return MessagesCompanion(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      accountId: accountId ?? this.accountId,
      serverHost: serverHost ?? this.serverHost,
      fromUser: fromUser ?? this.fromUser,
      toUser: toUser ?? this.toUser,
      content: content ?? this.content,
      outgoing: outgoing ?? this.outgoing,
      delivered: delivered ?? this.delivered,
      isRead: isRead ?? this.isRead,
      pendingSend: pendingSend ?? this.pendingSend,
      timeMs: timeMs ?? this.timeMs,
      rawEnvelopePreview: rawEnvelopePreview ?? this.rawEnvelopePreview,
      encryptedForDevice: encryptedForDevice ?? this.encryptedForDevice,
      serverMessageId: serverMessageId ?? this.serverMessageId,
      replyToId: replyToId ?? this.replyToId,
      replyToSender: replyToSender ?? this.replyToSender,
      replyToContent: replyToContent ?? this.replyToContent,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      deliveredAtMs: deliveredAtMs ?? this.deliveredAtMs,
      reactionsJson: reactionsJson ?? this.reactionsJson,
      meshMetaJson: meshMetaJson ?? this.meshMetaJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (serverHost.present) {
      map['server_host'] = Variable<String>(serverHost.value);
    }
    if (fromUser.present) {
      map['from_user'] = Variable<String>(fromUser.value);
    }
    if (toUser.present) {
      map['to_user'] = Variable<String>(toUser.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (outgoing.present) {
      map['outgoing'] = Variable<bool>(outgoing.value);
    }
    if (delivered.present) {
      map['delivered'] = Variable<bool>(delivered.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (pendingSend.present) {
      map['pending_send'] = Variable<bool>(pendingSend.value);
    }
    if (timeMs.present) {
      map['time_ms'] = Variable<int>(timeMs.value);
    }
    if (rawEnvelopePreview.present) {
      map['raw_envelope_preview'] = Variable<String>(rawEnvelopePreview.value);
    }
    if (encryptedForDevice.present) {
      map['encrypted_for_device'] = Variable<String>(encryptedForDevice.value);
    }
    if (serverMessageId.present) {
      map['server_message_id'] = Variable<int>(serverMessageId.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<int>(replyToId.value);
    }
    if (replyToSender.present) {
      map['reply_to_sender'] = Variable<String>(replyToSender.value);
    }
    if (replyToContent.present) {
      map['reply_to_content'] = Variable<String>(replyToContent.value);
    }
    if (deliveryMode.present) {
      map['delivery_mode'] = Variable<String>(deliveryMode.value);
    }
    if (deliveredAtMs.present) {
      map['delivered_at_ms'] = Variable<int>(deliveredAtMs.value);
    }
    if (reactionsJson.present) {
      map['reactions_json'] = Variable<String>(reactionsJson.value);
    }
    if (meshMetaJson.present) {
      map['mesh_meta_json'] = Variable<String>(meshMetaJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('chatId: $chatId, ')
          ..write('accountId: $accountId, ')
          ..write('serverHost: $serverHost, ')
          ..write('fromUser: $fromUser, ')
          ..write('toUser: $toUser, ')
          ..write('content: $content, ')
          ..write('outgoing: $outgoing, ')
          ..write('delivered: $delivered, ')
          ..write('isRead: $isRead, ')
          ..write('pendingSend: $pendingSend, ')
          ..write('timeMs: $timeMs, ')
          ..write('rawEnvelopePreview: $rawEnvelopePreview, ')
          ..write('encryptedForDevice: $encryptedForDevice, ')
          ..write('serverMessageId: $serverMessageId, ')
          ..write('replyToId: $replyToId, ')
          ..write('replyToSender: $replyToSender, ')
          ..write('replyToContent: $replyToContent, ')
          ..write('deliveryMode: $deliveryMode, ')
          ..write('deliveredAtMs: $deliveredAtMs, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('meshMetaJson: $meshMetaJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupsTable extends Groups with TableInfo<$GroupsTable, GroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
      'group_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverHostMeta =
      const VerificationMeta('serverHost');
  @override
  late final GeneratedColumn<String> serverHost = GeneratedColumn<String>(
      'server_host', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isChannelMeta =
      const VerificationMeta('isChannel');
  @override
  late final GeneratedColumn<bool> isChannel = GeneratedColumn<bool>(
      'is_channel', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_channel" IN (0, 1))'));
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
      'owner', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _inviteLinkMeta =
      const VerificationMeta('inviteLink');
  @override
  late final GeneratedColumn<String> inviteLink = GeneratedColumn<String>(
      'invite_link', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _avatarVersionMeta =
      const VerificationMeta('avatarVersion');
  @override
  late final GeneratedColumn<int> avatarVersion = GeneratedColumn<int>(
      'avatar_version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _externalServerIdMeta =
      const VerificationMeta('externalServerId');
  @override
  late final GeneratedColumn<String> externalServerId = GeneratedColumn<String>(
      'external_server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _myRoleMeta = const VerificationMeta('myRole');
  @override
  late final GeneratedColumn<String> myRole = GeneratedColumn<String>(
      'my_role', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        groupId,
        accountId,
        serverHost,
        name,
        isChannel,
        owner,
        inviteLink,
        avatarVersion,
        externalServerId,
        myRole
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(Insertable<GroupRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('server_host')) {
      context.handle(
          _serverHostMeta,
          serverHost.isAcceptableOrUnknown(
              data['server_host']!, _serverHostMeta));
    } else if (isInserting) {
      context.missing(_serverHostMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_channel')) {
      context.handle(_isChannelMeta,
          isChannel.isAcceptableOrUnknown(data['is_channel']!, _isChannelMeta));
    } else if (isInserting) {
      context.missing(_isChannelMeta);
    }
    if (data.containsKey('owner')) {
      context.handle(
          _ownerMeta, owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta));
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('invite_link')) {
      context.handle(
          _inviteLinkMeta,
          inviteLink.isAcceptableOrUnknown(
              data['invite_link']!, _inviteLinkMeta));
    }
    if (data.containsKey('avatar_version')) {
      context.handle(
          _avatarVersionMeta,
          avatarVersion.isAcceptableOrUnknown(
              data['avatar_version']!, _avatarVersionMeta));
    }
    if (data.containsKey('external_server_id')) {
      context.handle(
          _externalServerIdMeta,
          externalServerId.isAcceptableOrUnknown(
              data['external_server_id']!, _externalServerIdMeta));
    }
    if (data.containsKey('my_role')) {
      context.handle(_myRoleMeta,
          myRole.isAcceptableOrUnknown(data['my_role']!, _myRoleMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, accountId, serverHost};
  @override
  GroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupRow(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}group_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      serverHost: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_host'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      isChannel: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_channel'])!,
      owner: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner'])!,
      inviteLink: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}invite_link'])!,
      avatarVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}avatar_version'])!,
      externalServerId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}external_server_id']),
      myRole: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_role']),
    );
  }

  @override
  $GroupsTable createAlias(String alias) {
    return $GroupsTable(attachedDatabase, alias);
  }
}

class GroupRow extends DataClass implements Insertable<GroupRow> {
  final int groupId;
  final String accountId;
  final String serverHost;
  final String name;
  final bool isChannel;
  final String owner;
  final String inviteLink;
  final int avatarVersion;
  final String? externalServerId;
  final String? myRole;
  const GroupRow(
      {required this.groupId,
      required this.accountId,
      required this.serverHost,
      required this.name,
      required this.isChannel,
      required this.owner,
      required this.inviteLink,
      required this.avatarVersion,
      this.externalServerId,
      this.myRole});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<int>(groupId);
    map['account_id'] = Variable<String>(accountId);
    map['server_host'] = Variable<String>(serverHost);
    map['name'] = Variable<String>(name);
    map['is_channel'] = Variable<bool>(isChannel);
    map['owner'] = Variable<String>(owner);
    map['invite_link'] = Variable<String>(inviteLink);
    map['avatar_version'] = Variable<int>(avatarVersion);
    if (!nullToAbsent || externalServerId != null) {
      map['external_server_id'] = Variable<String>(externalServerId);
    }
    if (!nullToAbsent || myRole != null) {
      map['my_role'] = Variable<String>(myRole);
    }
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      groupId: Value(groupId),
      accountId: Value(accountId),
      serverHost: Value(serverHost),
      name: Value(name),
      isChannel: Value(isChannel),
      owner: Value(owner),
      inviteLink: Value(inviteLink),
      avatarVersion: Value(avatarVersion),
      externalServerId: externalServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalServerId),
      myRole:
          myRole == null && nullToAbsent ? const Value.absent() : Value(myRole),
    );
  }

  factory GroupRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupRow(
      groupId: serializer.fromJson<int>(json['groupId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      serverHost: serializer.fromJson<String>(json['serverHost']),
      name: serializer.fromJson<String>(json['name']),
      isChannel: serializer.fromJson<bool>(json['isChannel']),
      owner: serializer.fromJson<String>(json['owner']),
      inviteLink: serializer.fromJson<String>(json['inviteLink']),
      avatarVersion: serializer.fromJson<int>(json['avatarVersion']),
      externalServerId: serializer.fromJson<String?>(json['externalServerId']),
      myRole: serializer.fromJson<String?>(json['myRole']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<int>(groupId),
      'accountId': serializer.toJson<String>(accountId),
      'serverHost': serializer.toJson<String>(serverHost),
      'name': serializer.toJson<String>(name),
      'isChannel': serializer.toJson<bool>(isChannel),
      'owner': serializer.toJson<String>(owner),
      'inviteLink': serializer.toJson<String>(inviteLink),
      'avatarVersion': serializer.toJson<int>(avatarVersion),
      'externalServerId': serializer.toJson<String?>(externalServerId),
      'myRole': serializer.toJson<String?>(myRole),
    };
  }

  GroupRow copyWith(
          {int? groupId,
          String? accountId,
          String? serverHost,
          String? name,
          bool? isChannel,
          String? owner,
          String? inviteLink,
          int? avatarVersion,
          Value<String?> externalServerId = const Value.absent(),
          Value<String?> myRole = const Value.absent()}) =>
      GroupRow(
        groupId: groupId ?? this.groupId,
        accountId: accountId ?? this.accountId,
        serverHost: serverHost ?? this.serverHost,
        name: name ?? this.name,
        isChannel: isChannel ?? this.isChannel,
        owner: owner ?? this.owner,
        inviteLink: inviteLink ?? this.inviteLink,
        avatarVersion: avatarVersion ?? this.avatarVersion,
        externalServerId: externalServerId.present
            ? externalServerId.value
            : this.externalServerId,
        myRole: myRole.present ? myRole.value : this.myRole,
      );
  GroupRow copyWithCompanion(GroupsCompanion data) {
    return GroupRow(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      serverHost:
          data.serverHost.present ? data.serverHost.value : this.serverHost,
      name: data.name.present ? data.name.value : this.name,
      isChannel: data.isChannel.present ? data.isChannel.value : this.isChannel,
      owner: data.owner.present ? data.owner.value : this.owner,
      inviteLink:
          data.inviteLink.present ? data.inviteLink.value : this.inviteLink,
      avatarVersion: data.avatarVersion.present
          ? data.avatarVersion.value
          : this.avatarVersion,
      externalServerId: data.externalServerId.present
          ? data.externalServerId.value
          : this.externalServerId,
      myRole: data.myRole.present ? data.myRole.value : this.myRole,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupRow(')
          ..write('groupId: $groupId, ')
          ..write('accountId: $accountId, ')
          ..write('serverHost: $serverHost, ')
          ..write('name: $name, ')
          ..write('isChannel: $isChannel, ')
          ..write('owner: $owner, ')
          ..write('inviteLink: $inviteLink, ')
          ..write('avatarVersion: $avatarVersion, ')
          ..write('externalServerId: $externalServerId, ')
          ..write('myRole: $myRole')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, accountId, serverHost, name,
      isChannel, owner, inviteLink, avatarVersion, externalServerId, myRole);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupRow &&
          other.groupId == this.groupId &&
          other.accountId == this.accountId &&
          other.serverHost == this.serverHost &&
          other.name == this.name &&
          other.isChannel == this.isChannel &&
          other.owner == this.owner &&
          other.inviteLink == this.inviteLink &&
          other.avatarVersion == this.avatarVersion &&
          other.externalServerId == this.externalServerId &&
          other.myRole == this.myRole);
}

class GroupsCompanion extends UpdateCompanion<GroupRow> {
  final Value<int> groupId;
  final Value<String> accountId;
  final Value<String> serverHost;
  final Value<String> name;
  final Value<bool> isChannel;
  final Value<String> owner;
  final Value<String> inviteLink;
  final Value<int> avatarVersion;
  final Value<String?> externalServerId;
  final Value<String?> myRole;
  final Value<int> rowid;
  const GroupsCompanion({
    this.groupId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.serverHost = const Value.absent(),
    this.name = const Value.absent(),
    this.isChannel = const Value.absent(),
    this.owner = const Value.absent(),
    this.inviteLink = const Value.absent(),
    this.avatarVersion = const Value.absent(),
    this.externalServerId = const Value.absent(),
    this.myRole = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsCompanion.insert({
    required int groupId,
    required String accountId,
    required String serverHost,
    required String name,
    required bool isChannel,
    required String owner,
    this.inviteLink = const Value.absent(),
    this.avatarVersion = const Value.absent(),
    this.externalServerId = const Value.absent(),
    this.myRole = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        accountId = Value(accountId),
        serverHost = Value(serverHost),
        name = Value(name),
        isChannel = Value(isChannel),
        owner = Value(owner);
  static Insertable<GroupRow> custom({
    Expression<int>? groupId,
    Expression<String>? accountId,
    Expression<String>? serverHost,
    Expression<String>? name,
    Expression<bool>? isChannel,
    Expression<String>? owner,
    Expression<String>? inviteLink,
    Expression<int>? avatarVersion,
    Expression<String>? externalServerId,
    Expression<String>? myRole,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (accountId != null) 'account_id': accountId,
      if (serverHost != null) 'server_host': serverHost,
      if (name != null) 'name': name,
      if (isChannel != null) 'is_channel': isChannel,
      if (owner != null) 'owner': owner,
      if (inviteLink != null) 'invite_link': inviteLink,
      if (avatarVersion != null) 'avatar_version': avatarVersion,
      if (externalServerId != null) 'external_server_id': externalServerId,
      if (myRole != null) 'my_role': myRole,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsCompanion copyWith(
      {Value<int>? groupId,
      Value<String>? accountId,
      Value<String>? serverHost,
      Value<String>? name,
      Value<bool>? isChannel,
      Value<String>? owner,
      Value<String>? inviteLink,
      Value<int>? avatarVersion,
      Value<String?>? externalServerId,
      Value<String?>? myRole,
      Value<int>? rowid}) {
    return GroupsCompanion(
      groupId: groupId ?? this.groupId,
      accountId: accountId ?? this.accountId,
      serverHost: serverHost ?? this.serverHost,
      name: name ?? this.name,
      isChannel: isChannel ?? this.isChannel,
      owner: owner ?? this.owner,
      inviteLink: inviteLink ?? this.inviteLink,
      avatarVersion: avatarVersion ?? this.avatarVersion,
      externalServerId: externalServerId ?? this.externalServerId,
      myRole: myRole ?? this.myRole,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (serverHost.present) {
      map['server_host'] = Variable<String>(serverHost.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isChannel.present) {
      map['is_channel'] = Variable<bool>(isChannel.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (inviteLink.present) {
      map['invite_link'] = Variable<String>(inviteLink.value);
    }
    if (avatarVersion.present) {
      map['avatar_version'] = Variable<int>(avatarVersion.value);
    }
    if (externalServerId.present) {
      map['external_server_id'] = Variable<String>(externalServerId.value);
    }
    if (myRole.present) {
      map['my_role'] = Variable<String>(myRole.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('groupId: $groupId, ')
          ..write('accountId: $accountId, ')
          ..write('serverHost: $serverHost, ')
          ..write('name: $name, ')
          ..write('isChannel: $isChannel, ')
          ..write('owner: $owner, ')
          ..write('inviteLink: $inviteLink, ')
          ..write('avatarVersion: $avatarVersion, ')
          ..write('externalServerId: $externalServerId, ')
          ..write('myRole: $myRole, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupMessagesTable extends GroupMessages
    with TableInfo<$GroupMessagesTable, GroupMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
      'group_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverHostMeta =
      const VerificationMeta('serverHost');
  @override
  late final GeneratedColumn<String> serverHost = GeneratedColumn<String>(
      'server_host', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverMsgIdMeta =
      const VerificationMeta('serverMsgId');
  @override
  late final GeneratedColumn<int> serverMsgId = GeneratedColumn<int>(
      'server_msg_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _timeMsMeta = const VerificationMeta('timeMs');
  @override
  late final GeneratedColumn<int> timeMs = GeneratedColumn<int>(
      'time_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rawJsonMeta =
      const VerificationMeta('rawJson');
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
      'raw_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, groupId, accountId, serverHost, serverMsgId, timeMs, rawJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_messages';
  @override
  VerificationContext validateIntegrity(Insertable<GroupMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('server_host')) {
      context.handle(
          _serverHostMeta,
          serverHost.isAcceptableOrUnknown(
              data['server_host']!, _serverHostMeta));
    } else if (isInserting) {
      context.missing(_serverHostMeta);
    }
    if (data.containsKey('server_msg_id')) {
      context.handle(
          _serverMsgIdMeta,
          serverMsgId.isAcceptableOrUnknown(
              data['server_msg_id']!, _serverMsgIdMeta));
    }
    if (data.containsKey('time_ms')) {
      context.handle(_timeMsMeta,
          timeMs.isAcceptableOrUnknown(data['time_ms']!, _timeMsMeta));
    } else if (isInserting) {
      context.missing(_timeMsMeta);
    }
    if (data.containsKey('raw_json')) {
      context.handle(_rawJsonMeta,
          rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta));
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}group_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      serverHost: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_host'])!,
      serverMsgId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_msg_id']),
      timeMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time_ms'])!,
      rawJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_json'])!,
    );
  }

  @override
  $GroupMessagesTable createAlias(String alias) {
    return $GroupMessagesTable(attachedDatabase, alias);
  }
}

class GroupMessage extends DataClass implements Insertable<GroupMessage> {
  final int id;
  final int groupId;
  final String accountId;
  final String serverHost;
  final int? serverMsgId;
  final int timeMs;
  final String rawJson;
  const GroupMessage(
      {required this.id,
      required this.groupId,
      required this.accountId,
      required this.serverHost,
      this.serverMsgId,
      required this.timeMs,
      required this.rawJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['group_id'] = Variable<int>(groupId);
    map['account_id'] = Variable<String>(accountId);
    map['server_host'] = Variable<String>(serverHost);
    if (!nullToAbsent || serverMsgId != null) {
      map['server_msg_id'] = Variable<int>(serverMsgId);
    }
    map['time_ms'] = Variable<int>(timeMs);
    map['raw_json'] = Variable<String>(rawJson);
    return map;
  }

  GroupMessagesCompanion toCompanion(bool nullToAbsent) {
    return GroupMessagesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      accountId: Value(accountId),
      serverHost: Value(serverHost),
      serverMsgId: serverMsgId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverMsgId),
      timeMs: Value(timeMs),
      rawJson: Value(rawJson),
    );
  }

  factory GroupMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMessage(
      id: serializer.fromJson<int>(json['id']),
      groupId: serializer.fromJson<int>(json['groupId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      serverHost: serializer.fromJson<String>(json['serverHost']),
      serverMsgId: serializer.fromJson<int?>(json['serverMsgId']),
      timeMs: serializer.fromJson<int>(json['timeMs']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'groupId': serializer.toJson<int>(groupId),
      'accountId': serializer.toJson<String>(accountId),
      'serverHost': serializer.toJson<String>(serverHost),
      'serverMsgId': serializer.toJson<int?>(serverMsgId),
      'timeMs': serializer.toJson<int>(timeMs),
      'rawJson': serializer.toJson<String>(rawJson),
    };
  }

  GroupMessage copyWith(
          {int? id,
          int? groupId,
          String? accountId,
          String? serverHost,
          Value<int?> serverMsgId = const Value.absent(),
          int? timeMs,
          String? rawJson}) =>
      GroupMessage(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        accountId: accountId ?? this.accountId,
        serverHost: serverHost ?? this.serverHost,
        serverMsgId: serverMsgId.present ? serverMsgId.value : this.serverMsgId,
        timeMs: timeMs ?? this.timeMs,
        rawJson: rawJson ?? this.rawJson,
      );
  GroupMessage copyWithCompanion(GroupMessagesCompanion data) {
    return GroupMessage(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      serverHost:
          data.serverHost.present ? data.serverHost.value : this.serverHost,
      serverMsgId:
          data.serverMsgId.present ? data.serverMsgId.value : this.serverMsgId,
      timeMs: data.timeMs.present ? data.timeMs.value : this.timeMs,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMessage(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('accountId: $accountId, ')
          ..write('serverHost: $serverHost, ')
          ..write('serverMsgId: $serverMsgId, ')
          ..write('timeMs: $timeMs, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, groupId, accountId, serverHost, serverMsgId, timeMs, rawJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMessage &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.accountId == this.accountId &&
          other.serverHost == this.serverHost &&
          other.serverMsgId == this.serverMsgId &&
          other.timeMs == this.timeMs &&
          other.rawJson == this.rawJson);
}

class GroupMessagesCompanion extends UpdateCompanion<GroupMessage> {
  final Value<int> id;
  final Value<int> groupId;
  final Value<String> accountId;
  final Value<String> serverHost;
  final Value<int?> serverMsgId;
  final Value<int> timeMs;
  final Value<String> rawJson;
  const GroupMessagesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.serverHost = const Value.absent(),
    this.serverMsgId = const Value.absent(),
    this.timeMs = const Value.absent(),
    this.rawJson = const Value.absent(),
  });
  GroupMessagesCompanion.insert({
    this.id = const Value.absent(),
    required int groupId,
    required String accountId,
    required String serverHost,
    this.serverMsgId = const Value.absent(),
    required int timeMs,
    required String rawJson,
  })  : groupId = Value(groupId),
        accountId = Value(accountId),
        serverHost = Value(serverHost),
        timeMs = Value(timeMs),
        rawJson = Value(rawJson);
  static Insertable<GroupMessage> custom({
    Expression<int>? id,
    Expression<int>? groupId,
    Expression<String>? accountId,
    Expression<String>? serverHost,
    Expression<int>? serverMsgId,
    Expression<int>? timeMs,
    Expression<String>? rawJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (accountId != null) 'account_id': accountId,
      if (serverHost != null) 'server_host': serverHost,
      if (serverMsgId != null) 'server_msg_id': serverMsgId,
      if (timeMs != null) 'time_ms': timeMs,
      if (rawJson != null) 'raw_json': rawJson,
    });
  }

  GroupMessagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? groupId,
      Value<String>? accountId,
      Value<String>? serverHost,
      Value<int?>? serverMsgId,
      Value<int>? timeMs,
      Value<String>? rawJson}) {
    return GroupMessagesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      accountId: accountId ?? this.accountId,
      serverHost: serverHost ?? this.serverHost,
      serverMsgId: serverMsgId ?? this.serverMsgId,
      timeMs: timeMs ?? this.timeMs,
      rawJson: rawJson ?? this.rawJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (serverHost.present) {
      map['server_host'] = Variable<String>(serverHost.value);
    }
    if (serverMsgId.present) {
      map['server_msg_id'] = Variable<int>(serverMsgId.value);
    }
    if (timeMs.present) {
      map['time_ms'] = Variable<int>(timeMs.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMessagesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('accountId: $accountId, ')
          ..write('serverHost: $serverHost, ')
          ..write('serverMsgId: $serverMsgId, ')
          ..write('timeMs: $timeMs, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }
}

class $FavoriteChatsTable extends FavoriteChats
    with TableInfo<$FavoriteChatsTable, FavoriteChatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteChatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _favIdMeta = const VerificationMeta('favId');
  @override
  late final GeneratedColumn<String> favId = GeneratedColumn<String>(
      'fav_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverHostMeta =
      const VerificationMeta('serverHost');
  @override
  late final GeneratedColumn<String> serverHost = GeneratedColumn<String>(
      'server_host', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarPathMeta =
      const VerificationMeta('avatarPath');
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
      'avatar_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMsMeta =
      const VerificationMeta('createdAtMs');
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
      'created_at_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [favId, accountId, serverHost, title, avatarPath, createdAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_chats';
  @override
  VerificationContext validateIntegrity(Insertable<FavoriteChatRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('fav_id')) {
      context.handle(
          _favIdMeta, favId.isAcceptableOrUnknown(data['fav_id']!, _favIdMeta));
    } else if (isInserting) {
      context.missing(_favIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('server_host')) {
      context.handle(
          _serverHostMeta,
          serverHost.isAcceptableOrUnknown(
              data['server_host']!, _serverHostMeta));
    } else if (isInserting) {
      context.missing(_serverHostMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
          _avatarPathMeta,
          avatarPath.isAcceptableOrUnknown(
              data['avatar_path']!, _avatarPathMeta));
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
          _createdAtMsMeta,
          createdAtMs.isAcceptableOrUnknown(
              data['created_at_ms']!, _createdAtMsMeta));
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {favId, accountId, serverHost};
  @override
  FavoriteChatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteChatRow(
      favId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fav_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      serverHost: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_host'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      avatarPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_path']),
      createdAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at_ms'])!,
    );
  }

  @override
  $FavoriteChatsTable createAlias(String alias) {
    return $FavoriteChatsTable(attachedDatabase, alias);
  }
}

class FavoriteChatRow extends DataClass implements Insertable<FavoriteChatRow> {
  final String favId;
  final String accountId;
  final String serverHost;
  final String title;
  final String? avatarPath;
  final int createdAtMs;
  const FavoriteChatRow(
      {required this.favId,
      required this.accountId,
      required this.serverHost,
      required this.title,
      this.avatarPath,
      required this.createdAtMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['fav_id'] = Variable<String>(favId);
    map['account_id'] = Variable<String>(accountId);
    map['server_host'] = Variable<String>(serverHost);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  FavoriteChatsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteChatsCompanion(
      favId: Value(favId),
      accountId: Value(accountId),
      serverHost: Value(serverHost),
      title: Value(title),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory FavoriteChatRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteChatRow(
      favId: serializer.fromJson<String>(json['favId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      serverHost: serializer.fromJson<String>(json['serverHost']),
      title: serializer.fromJson<String>(json['title']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'favId': serializer.toJson<String>(favId),
      'accountId': serializer.toJson<String>(accountId),
      'serverHost': serializer.toJson<String>(serverHost),
      'title': serializer.toJson<String>(title),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  FavoriteChatRow copyWith(
          {String? favId,
          String? accountId,
          String? serverHost,
          String? title,
          Value<String?> avatarPath = const Value.absent(),
          int? createdAtMs}) =>
      FavoriteChatRow(
        favId: favId ?? this.favId,
        accountId: accountId ?? this.accountId,
        serverHost: serverHost ?? this.serverHost,
        title: title ?? this.title,
        avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
        createdAtMs: createdAtMs ?? this.createdAtMs,
      );
  FavoriteChatRow copyWithCompanion(FavoriteChatsCompanion data) {
    return FavoriteChatRow(
      favId: data.favId.present ? data.favId.value : this.favId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      serverHost:
          data.serverHost.present ? data.serverHost.value : this.serverHost,
      title: data.title.present ? data.title.value : this.title,
      avatarPath:
          data.avatarPath.present ? data.avatarPath.value : this.avatarPath,
      createdAtMs:
          data.createdAtMs.present ? data.createdAtMs.value : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteChatRow(')
          ..write('favId: $favId, ')
          ..write('accountId: $accountId, ')
          ..write('serverHost: $serverHost, ')
          ..write('title: $title, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(favId, accountId, serverHost, title, avatarPath, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteChatRow &&
          other.favId == this.favId &&
          other.accountId == this.accountId &&
          other.serverHost == this.serverHost &&
          other.title == this.title &&
          other.avatarPath == this.avatarPath &&
          other.createdAtMs == this.createdAtMs);
}

class FavoriteChatsCompanion extends UpdateCompanion<FavoriteChatRow> {
  final Value<String> favId;
  final Value<String> accountId;
  final Value<String> serverHost;
  final Value<String> title;
  final Value<String?> avatarPath;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const FavoriteChatsCompanion({
    this.favId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.serverHost = const Value.absent(),
    this.title = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteChatsCompanion.insert({
    required String favId,
    required String accountId,
    required String serverHost,
    required String title,
    this.avatarPath = const Value.absent(),
    required int createdAtMs,
    this.rowid = const Value.absent(),
  })  : favId = Value(favId),
        accountId = Value(accountId),
        serverHost = Value(serverHost),
        title = Value(title),
        createdAtMs = Value(createdAtMs);
  static Insertable<FavoriteChatRow> custom({
    Expression<String>? favId,
    Expression<String>? accountId,
    Expression<String>? serverHost,
    Expression<String>? title,
    Expression<String>? avatarPath,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (favId != null) 'fav_id': favId,
      if (accountId != null) 'account_id': accountId,
      if (serverHost != null) 'server_host': serverHost,
      if (title != null) 'title': title,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteChatsCompanion copyWith(
      {Value<String>? favId,
      Value<String>? accountId,
      Value<String>? serverHost,
      Value<String>? title,
      Value<String?>? avatarPath,
      Value<int>? createdAtMs,
      Value<int>? rowid}) {
    return FavoriteChatsCompanion(
      favId: favId ?? this.favId,
      accountId: accountId ?? this.accountId,
      serverHost: serverHost ?? this.serverHost,
      title: title ?? this.title,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (favId.present) {
      map['fav_id'] = Variable<String>(favId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (serverHost.present) {
      map['server_host'] = Variable<String>(serverHost.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteChatsCompanion(')
          ..write('favId: $favId, ')
          ..write('accountId: $accountId, ')
          ..write('serverHost: $serverHost, ')
          ..write('title: $title, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageRemindersTable extends MessageReminders
    with TableInfo<$MessageRemindersTable, MessageReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageRemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reminderIdMeta =
      const VerificationMeta('reminderId');
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>(
      'reminder_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverHostMeta =
      const VerificationMeta('serverHost');
  @override
  late final GeneratedColumn<String> serverHost = GeneratedColumn<String>(
      'server_host', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
      'chat_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatTypeMeta =
      const VerificationMeta('chatType');
  @override
  late final GeneratedColumn<String> chatType = GeneratedColumn<String>(
      'chat_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatTitleMeta =
      const VerificationMeta('chatTitle');
  @override
  late final GeneratedColumn<String> chatTitle = GeneratedColumn<String>(
      'chat_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messagePreviewMeta =
      const VerificationMeta('messagePreview');
  @override
  late final GeneratedColumn<String> messagePreview = GeneratedColumn<String>(
      'message_preview', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarPathMeta =
      const VerificationMeta('avatarPath');
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
      'avatar_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _externalServerIdMeta =
      const VerificationMeta('externalServerId');
  @override
  late final GeneratedColumn<String> externalServerId = GeneratedColumn<String>(
      'external_server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _otherUsernameMeta =
      const VerificationMeta('otherUsername');
  @override
  late final GeneratedColumn<String> otherUsername = GeneratedColumn<String>(
      'other_username', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _accentColorArgbMeta =
      const VerificationMeta('accentColorArgb');
  @override
  late final GeneratedColumn<int> accentColorArgb = GeneratedColumn<int>(
      'accent_color_argb', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _scheduledAtMsMeta =
      const VerificationMeta('scheduledAtMs');
  @override
  late final GeneratedColumn<int> scheduledAtMs = GeneratedColumn<int>(
      'scheduled_at_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMsMeta =
      const VerificationMeta('createdAtMs');
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
      'created_at_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _firedMeta = const VerificationMeta('fired');
  @override
  late final GeneratedColumn<bool> fired = GeneratedColumn<bool>(
      'fired', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("fired" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _cancelledMeta =
      const VerificationMeta('cancelled');
  @override
  late final GeneratedColumn<bool> cancelled = GeneratedColumn<bool>(
      'cancelled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("cancelled" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        reminderId,
        accountId,
        serverHost,
        messageId,
        chatId,
        chatType,
        chatTitle,
        messagePreview,
        avatarPath,
        externalServerId,
        otherUsername,
        accentColorArgb,
        scheduledAtMs,
        createdAtMs,
        fired,
        cancelled
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_reminders';
  @override
  VerificationContext validateIntegrity(Insertable<MessageReminderRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reminder_id')) {
      context.handle(
          _reminderIdMeta,
          reminderId.isAcceptableOrUnknown(
              data['reminder_id']!, _reminderIdMeta));
    } else if (isInserting) {
      context.missing(_reminderIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('server_host')) {
      context.handle(
          _serverHostMeta,
          serverHost.isAcceptableOrUnknown(
              data['server_host']!, _serverHostMeta));
    } else if (isInserting) {
      context.missing(_serverHostMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(_chatIdMeta,
          chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta));
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('chat_type')) {
      context.handle(_chatTypeMeta,
          chatType.isAcceptableOrUnknown(data['chat_type']!, _chatTypeMeta));
    } else if (isInserting) {
      context.missing(_chatTypeMeta);
    }
    if (data.containsKey('chat_title')) {
      context.handle(_chatTitleMeta,
          chatTitle.isAcceptableOrUnknown(data['chat_title']!, _chatTitleMeta));
    } else if (isInserting) {
      context.missing(_chatTitleMeta);
    }
    if (data.containsKey('message_preview')) {
      context.handle(
          _messagePreviewMeta,
          messagePreview.isAcceptableOrUnknown(
              data['message_preview']!, _messagePreviewMeta));
    } else if (isInserting) {
      context.missing(_messagePreviewMeta);
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
          _avatarPathMeta,
          avatarPath.isAcceptableOrUnknown(
              data['avatar_path']!, _avatarPathMeta));
    }
    if (data.containsKey('external_server_id')) {
      context.handle(
          _externalServerIdMeta,
          externalServerId.isAcceptableOrUnknown(
              data['external_server_id']!, _externalServerIdMeta));
    }
    if (data.containsKey('other_username')) {
      context.handle(
          _otherUsernameMeta,
          otherUsername.isAcceptableOrUnknown(
              data['other_username']!, _otherUsernameMeta));
    }
    if (data.containsKey('accent_color_argb')) {
      context.handle(
          _accentColorArgbMeta,
          accentColorArgb.isAcceptableOrUnknown(
              data['accent_color_argb']!, _accentColorArgbMeta));
    }
    if (data.containsKey('scheduled_at_ms')) {
      context.handle(
          _scheduledAtMsMeta,
          scheduledAtMs.isAcceptableOrUnknown(
              data['scheduled_at_ms']!, _scheduledAtMsMeta));
    } else if (isInserting) {
      context.missing(_scheduledAtMsMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
          _createdAtMsMeta,
          createdAtMs.isAcceptableOrUnknown(
              data['created_at_ms']!, _createdAtMsMeta));
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('fired')) {
      context.handle(
          _firedMeta, fired.isAcceptableOrUnknown(data['fired']!, _firedMeta));
    }
    if (data.containsKey('cancelled')) {
      context.handle(_cancelledMeta,
          cancelled.isAcceptableOrUnknown(data['cancelled']!, _cancelledMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reminderId, accountId, serverHost};
  @override
  MessageReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageReminderRow(
      reminderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reminder_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      serverHost: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_host'])!,
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      chatId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_id'])!,
      chatType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_type'])!,
      chatTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_title'])!,
      messagePreview: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}message_preview'])!,
      avatarPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_path']),
      externalServerId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}external_server_id']),
      otherUsername: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}other_username']),
      accentColorArgb: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}accent_color_argb']),
      scheduledAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}scheduled_at_ms'])!,
      createdAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at_ms'])!,
      fired: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}fired'])!,
      cancelled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}cancelled'])!,
    );
  }

  @override
  $MessageRemindersTable createAlias(String alias) {
    return $MessageRemindersTable(attachedDatabase, alias);
  }
}

class MessageReminderRow extends DataClass
    implements Insertable<MessageReminderRow> {
  final String reminderId;
  final String accountId;
  final String serverHost;
  final String messageId;
  final String chatId;
  final String chatType;
  final String chatTitle;
  final String messagePreview;
  final String? avatarPath;
  final String? externalServerId;
  final String? otherUsername;
  final int? accentColorArgb;
  final int scheduledAtMs;
  final int createdAtMs;
  final bool fired;
  final bool cancelled;
  const MessageReminderRow(
      {required this.reminderId,
      required this.accountId,
      required this.serverHost,
      required this.messageId,
      required this.chatId,
      required this.chatType,
      required this.chatTitle,
      required this.messagePreview,
      this.avatarPath,
      this.externalServerId,
      this.otherUsername,
      this.accentColorArgb,
      required this.scheduledAtMs,
      required this.createdAtMs,
      required this.fired,
      required this.cancelled});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reminder_id'] = Variable<String>(reminderId);
    map['account_id'] = Variable<String>(accountId);
    map['server_host'] = Variable<String>(serverHost);
    map['message_id'] = Variable<String>(messageId);
    map['chat_id'] = Variable<String>(chatId);
    map['chat_type'] = Variable<String>(chatType);
    map['chat_title'] = Variable<String>(chatTitle);
    map['message_preview'] = Variable<String>(messagePreview);
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    if (!nullToAbsent || externalServerId != null) {
      map['external_server_id'] = Variable<String>(externalServerId);
    }
    if (!nullToAbsent || otherUsername != null) {
      map['other_username'] = Variable<String>(otherUsername);
    }
    if (!nullToAbsent || accentColorArgb != null) {
      map['accent_color_argb'] = Variable<int>(accentColorArgb);
    }
    map['scheduled_at_ms'] = Variable<int>(scheduledAtMs);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['fired'] = Variable<bool>(fired);
    map['cancelled'] = Variable<bool>(cancelled);
    return map;
  }

  MessageRemindersCompanion toCompanion(bool nullToAbsent) {
    return MessageRemindersCompanion(
      reminderId: Value(reminderId),
      accountId: Value(accountId),
      serverHost: Value(serverHost),
      messageId: Value(messageId),
      chatId: Value(chatId),
      chatType: Value(chatType),
      chatTitle: Value(chatTitle),
      messagePreview: Value(messagePreview),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      externalServerId: externalServerId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalServerId),
      otherUsername: otherUsername == null && nullToAbsent
          ? const Value.absent()
          : Value(otherUsername),
      accentColorArgb: accentColorArgb == null && nullToAbsent
          ? const Value.absent()
          : Value(accentColorArgb),
      scheduledAtMs: Value(scheduledAtMs),
      createdAtMs: Value(createdAtMs),
      fired: Value(fired),
      cancelled: Value(cancelled),
    );
  }

  factory MessageReminderRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageReminderRow(
      reminderId: serializer.fromJson<String>(json['reminderId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      serverHost: serializer.fromJson<String>(json['serverHost']),
      messageId: serializer.fromJson<String>(json['messageId']),
      chatId: serializer.fromJson<String>(json['chatId']),
      chatType: serializer.fromJson<String>(json['chatType']),
      chatTitle: serializer.fromJson<String>(json['chatTitle']),
      messagePreview: serializer.fromJson<String>(json['messagePreview']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      externalServerId: serializer.fromJson<String?>(json['externalServerId']),
      otherUsername: serializer.fromJson<String?>(json['otherUsername']),
      accentColorArgb: serializer.fromJson<int?>(json['accentColorArgb']),
      scheduledAtMs: serializer.fromJson<int>(json['scheduledAtMs']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      fired: serializer.fromJson<bool>(json['fired']),
      cancelled: serializer.fromJson<bool>(json['cancelled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reminderId': serializer.toJson<String>(reminderId),
      'accountId': serializer.toJson<String>(accountId),
      'serverHost': serializer.toJson<String>(serverHost),
      'messageId': serializer.toJson<String>(messageId),
      'chatId': serializer.toJson<String>(chatId),
      'chatType': serializer.toJson<String>(chatType),
      'chatTitle': serializer.toJson<String>(chatTitle),
      'messagePreview': serializer.toJson<String>(messagePreview),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'externalServerId': serializer.toJson<String?>(externalServerId),
      'otherUsername': serializer.toJson<String?>(otherUsername),
      'accentColorArgb': serializer.toJson<int?>(accentColorArgb),
      'scheduledAtMs': serializer.toJson<int>(scheduledAtMs),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'fired': serializer.toJson<bool>(fired),
      'cancelled': serializer.toJson<bool>(cancelled),
    };
  }

  MessageReminderRow copyWith(
          {String? reminderId,
          String? accountId,
          String? serverHost,
          String? messageId,
          String? chatId,
          String? chatType,
          String? chatTitle,
          String? messagePreview,
          Value<String?> avatarPath = const Value.absent(),
          Value<String?> externalServerId = const Value.absent(),
          Value<String?> otherUsername = const Value.absent(),
          Value<int?> accentColorArgb = const Value.absent(),
          int? scheduledAtMs,
          int? createdAtMs,
          bool? fired,
          bool? cancelled}) =>
      MessageReminderRow(
        reminderId: reminderId ?? this.reminderId,
        accountId: accountId ?? this.accountId,
        serverHost: serverHost ?? this.serverHost,
        messageId: messageId ?? this.messageId,
        chatId: chatId ?? this.chatId,
        chatType: chatType ?? this.chatType,
        chatTitle: chatTitle ?? this.chatTitle,
        messagePreview: messagePreview ?? this.messagePreview,
        avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
        externalServerId: externalServerId.present
            ? externalServerId.value
            : this.externalServerId,
        otherUsername:
            otherUsername.present ? otherUsername.value : this.otherUsername,
        accentColorArgb: accentColorArgb.present
            ? accentColorArgb.value
            : this.accentColorArgb,
        scheduledAtMs: scheduledAtMs ?? this.scheduledAtMs,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        fired: fired ?? this.fired,
        cancelled: cancelled ?? this.cancelled,
      );
  MessageReminderRow copyWithCompanion(MessageRemindersCompanion data) {
    return MessageReminderRow(
      reminderId:
          data.reminderId.present ? data.reminderId.value : this.reminderId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      serverHost:
          data.serverHost.present ? data.serverHost.value : this.serverHost,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      chatType: data.chatType.present ? data.chatType.value : this.chatType,
      chatTitle: data.chatTitle.present ? data.chatTitle.value : this.chatTitle,
      messagePreview: data.messagePreview.present
          ? data.messagePreview.value
          : this.messagePreview,
      avatarPath:
          data.avatarPath.present ? data.avatarPath.value : this.avatarPath,
      externalServerId: data.externalServerId.present
          ? data.externalServerId.value
          : this.externalServerId,
      otherUsername: data.otherUsername.present
          ? data.otherUsername.value
          : this.otherUsername,
      accentColorArgb: data.accentColorArgb.present
          ? data.accentColorArgb.value
          : this.accentColorArgb,
      scheduledAtMs: data.scheduledAtMs.present
          ? data.scheduledAtMs.value
          : this.scheduledAtMs,
      createdAtMs:
          data.createdAtMs.present ? data.createdAtMs.value : this.createdAtMs,
      fired: data.fired.present ? data.fired.value : this.fired,
      cancelled: data.cancelled.present ? data.cancelled.value : this.cancelled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageReminderRow(')
          ..write('reminderId: $reminderId, ')
          ..write('accountId: $accountId, ')
          ..write('serverHost: $serverHost, ')
          ..write('messageId: $messageId, ')
          ..write('chatId: $chatId, ')
          ..write('chatType: $chatType, ')
          ..write('chatTitle: $chatTitle, ')
          ..write('messagePreview: $messagePreview, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('externalServerId: $externalServerId, ')
          ..write('otherUsername: $otherUsername, ')
          ..write('accentColorArgb: $accentColorArgb, ')
          ..write('scheduledAtMs: $scheduledAtMs, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('fired: $fired, ')
          ..write('cancelled: $cancelled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      reminderId,
      accountId,
      serverHost,
      messageId,
      chatId,
      chatType,
      chatTitle,
      messagePreview,
      avatarPath,
      externalServerId,
      otherUsername,
      accentColorArgb,
      scheduledAtMs,
      createdAtMs,
      fired,
      cancelled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageReminderRow &&
          other.reminderId == this.reminderId &&
          other.accountId == this.accountId &&
          other.serverHost == this.serverHost &&
          other.messageId == this.messageId &&
          other.chatId == this.chatId &&
          other.chatType == this.chatType &&
          other.chatTitle == this.chatTitle &&
          other.messagePreview == this.messagePreview &&
          other.avatarPath == this.avatarPath &&
          other.externalServerId == this.externalServerId &&
          other.otherUsername == this.otherUsername &&
          other.accentColorArgb == this.accentColorArgb &&
          other.scheduledAtMs == this.scheduledAtMs &&
          other.createdAtMs == this.createdAtMs &&
          other.fired == this.fired &&
          other.cancelled == this.cancelled);
}

class MessageRemindersCompanion extends UpdateCompanion<MessageReminderRow> {
  final Value<String> reminderId;
  final Value<String> accountId;
  final Value<String> serverHost;
  final Value<String> messageId;
  final Value<String> chatId;
  final Value<String> chatType;
  final Value<String> chatTitle;
  final Value<String> messagePreview;
  final Value<String?> avatarPath;
  final Value<String?> externalServerId;
  final Value<String?> otherUsername;
  final Value<int?> accentColorArgb;
  final Value<int> scheduledAtMs;
  final Value<int> createdAtMs;
  final Value<bool> fired;
  final Value<bool> cancelled;
  final Value<int> rowid;
  const MessageRemindersCompanion({
    this.reminderId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.serverHost = const Value.absent(),
    this.messageId = const Value.absent(),
    this.chatId = const Value.absent(),
    this.chatType = const Value.absent(),
    this.chatTitle = const Value.absent(),
    this.messagePreview = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.externalServerId = const Value.absent(),
    this.otherUsername = const Value.absent(),
    this.accentColorArgb = const Value.absent(),
    this.scheduledAtMs = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.fired = const Value.absent(),
    this.cancelled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageRemindersCompanion.insert({
    required String reminderId,
    required String accountId,
    required String serverHost,
    required String messageId,
    required String chatId,
    required String chatType,
    required String chatTitle,
    required String messagePreview,
    this.avatarPath = const Value.absent(),
    this.externalServerId = const Value.absent(),
    this.otherUsername = const Value.absent(),
    this.accentColorArgb = const Value.absent(),
    required int scheduledAtMs,
    required int createdAtMs,
    this.fired = const Value.absent(),
    this.cancelled = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : reminderId = Value(reminderId),
        accountId = Value(accountId),
        serverHost = Value(serverHost),
        messageId = Value(messageId),
        chatId = Value(chatId),
        chatType = Value(chatType),
        chatTitle = Value(chatTitle),
        messagePreview = Value(messagePreview),
        scheduledAtMs = Value(scheduledAtMs),
        createdAtMs = Value(createdAtMs);
  static Insertable<MessageReminderRow> custom({
    Expression<String>? reminderId,
    Expression<String>? accountId,
    Expression<String>? serverHost,
    Expression<String>? messageId,
    Expression<String>? chatId,
    Expression<String>? chatType,
    Expression<String>? chatTitle,
    Expression<String>? messagePreview,
    Expression<String>? avatarPath,
    Expression<String>? externalServerId,
    Expression<String>? otherUsername,
    Expression<int>? accentColorArgb,
    Expression<int>? scheduledAtMs,
    Expression<int>? createdAtMs,
    Expression<bool>? fired,
    Expression<bool>? cancelled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (reminderId != null) 'reminder_id': reminderId,
      if (accountId != null) 'account_id': accountId,
      if (serverHost != null) 'server_host': serverHost,
      if (messageId != null) 'message_id': messageId,
      if (chatId != null) 'chat_id': chatId,
      if (chatType != null) 'chat_type': chatType,
      if (chatTitle != null) 'chat_title': chatTitle,
      if (messagePreview != null) 'message_preview': messagePreview,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (externalServerId != null) 'external_server_id': externalServerId,
      if (otherUsername != null) 'other_username': otherUsername,
      if (accentColorArgb != null) 'accent_color_argb': accentColorArgb,
      if (scheduledAtMs != null) 'scheduled_at_ms': scheduledAtMs,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (fired != null) 'fired': fired,
      if (cancelled != null) 'cancelled': cancelled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageRemindersCompanion copyWith(
      {Value<String>? reminderId,
      Value<String>? accountId,
      Value<String>? serverHost,
      Value<String>? messageId,
      Value<String>? chatId,
      Value<String>? chatType,
      Value<String>? chatTitle,
      Value<String>? messagePreview,
      Value<String?>? avatarPath,
      Value<String?>? externalServerId,
      Value<String?>? otherUsername,
      Value<int?>? accentColorArgb,
      Value<int>? scheduledAtMs,
      Value<int>? createdAtMs,
      Value<bool>? fired,
      Value<bool>? cancelled,
      Value<int>? rowid}) {
    return MessageRemindersCompanion(
      reminderId: reminderId ?? this.reminderId,
      accountId: accountId ?? this.accountId,
      serverHost: serverHost ?? this.serverHost,
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      chatType: chatType ?? this.chatType,
      chatTitle: chatTitle ?? this.chatTitle,
      messagePreview: messagePreview ?? this.messagePreview,
      avatarPath: avatarPath ?? this.avatarPath,
      externalServerId: externalServerId ?? this.externalServerId,
      otherUsername: otherUsername ?? this.otherUsername,
      accentColorArgb: accentColorArgb ?? this.accentColorArgb,
      scheduledAtMs: scheduledAtMs ?? this.scheduledAtMs,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      fired: fired ?? this.fired,
      cancelled: cancelled ?? this.cancelled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (serverHost.present) {
      map['server_host'] = Variable<String>(serverHost.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (chatType.present) {
      map['chat_type'] = Variable<String>(chatType.value);
    }
    if (chatTitle.present) {
      map['chat_title'] = Variable<String>(chatTitle.value);
    }
    if (messagePreview.present) {
      map['message_preview'] = Variable<String>(messagePreview.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (externalServerId.present) {
      map['external_server_id'] = Variable<String>(externalServerId.value);
    }
    if (otherUsername.present) {
      map['other_username'] = Variable<String>(otherUsername.value);
    }
    if (accentColorArgb.present) {
      map['accent_color_argb'] = Variable<int>(accentColorArgb.value);
    }
    if (scheduledAtMs.present) {
      map['scheduled_at_ms'] = Variable<int>(scheduledAtMs.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (fired.present) {
      map['fired'] = Variable<bool>(fired.value);
    }
    if (cancelled.present) {
      map['cancelled'] = Variable<bool>(cancelled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageRemindersCompanion(')
          ..write('reminderId: $reminderId, ')
          ..write('accountId: $accountId, ')
          ..write('serverHost: $serverHost, ')
          ..write('messageId: $messageId, ')
          ..write('chatId: $chatId, ')
          ..write('chatType: $chatType, ')
          ..write('chatTitle: $chatTitle, ')
          ..write('messagePreview: $messagePreview, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('externalServerId: $externalServerId, ')
          ..write('otherUsername: $otherUsername, ')
          ..write('accentColorArgb: $accentColorArgb, ')
          ..write('scheduledAtMs: $scheduledAtMs, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('fired: $fired, ')
          ..write('cancelled: $cancelled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $GroupMessagesTable groupMessages = $GroupMessagesTable(this);
  late final $FavoriteChatsTable favoriteChats = $FavoriteChatsTable(this);
  late final $MessageRemindersTable messageReminders =
      $MessageRemindersTable(this);
  late final MessageDao messageDao = MessageDao(this as AppDatabase);
  late final GroupDao groupDao = GroupDao(this as AppDatabase);
  late final GroupMessageDao groupMessageDao =
      GroupMessageDao(this as AppDatabase);
  late final FavoriteChatDao favoriteChatDao =
      FavoriteChatDao(this as AppDatabase);
  late final MessageReminderDao messageReminderDao =
      MessageReminderDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [messages, groups, groupMessages, favoriteChats, messageReminders];
}

typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String messageId,
  required String chatId,
  required String accountId,
  required String serverHost,
  required String fromUser,
  required String toUser,
  required String content,
  required bool outgoing,
  Value<bool> delivered,
  Value<bool> isRead,
  Value<bool> pendingSend,
  required int timeMs,
  Value<String?> rawEnvelopePreview,
  Value<String?> encryptedForDevice,
  Value<int?> serverMessageId,
  Value<int?> replyToId,
  Value<String?> replyToSender,
  Value<String?> replyToContent,
  Value<String> deliveryMode,
  Value<int?> deliveredAtMs,
  Value<String?> reactionsJson,
  Value<String?> meshMetaJson,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> messageId,
  Value<String> chatId,
  Value<String> accountId,
  Value<String> serverHost,
  Value<String> fromUser,
  Value<String> toUser,
  Value<String> content,
  Value<bool> outgoing,
  Value<bool> delivered,
  Value<bool> isRead,
  Value<bool> pendingSend,
  Value<int> timeMs,
  Value<String?> rawEnvelopePreview,
  Value<String?> encryptedForDevice,
  Value<int?> serverMessageId,
  Value<int?> replyToId,
  Value<String?> replyToSender,
  Value<String?> replyToContent,
  Value<String> deliveryMode,
  Value<int?> deliveredAtMs,
  Value<String?> reactionsJson,
  Value<String?> meshMetaJson,
  Value<int> rowid,
});

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromUser => $composableBuilder(
      column: $table.fromUser, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toUser => $composableBuilder(
      column: $table.toUser, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get outgoing => $composableBuilder(
      column: $table.outgoing, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get delivered => $composableBuilder(
      column: $table.delivered, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get pendingSend => $composableBuilder(
      column: $table.pendingSend, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timeMs => $composableBuilder(
      column: $table.timeMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawEnvelopePreview => $composableBuilder(
      column: $table.rawEnvelopePreview,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get encryptedForDevice => $composableBuilder(
      column: $table.encryptedForDevice,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get serverMessageId => $composableBuilder(
      column: $table.serverMessageId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get replyToId => $composableBuilder(
      column: $table.replyToId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replyToSender => $composableBuilder(
      column: $table.replyToSender, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replyToContent => $composableBuilder(
      column: $table.replyToContent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deliveryMode => $composableBuilder(
      column: $table.deliveryMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deliveredAtMs => $composableBuilder(
      column: $table.deliveredAtMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meshMetaJson => $composableBuilder(
      column: $table.meshMetaJson, builder: (column) => ColumnFilters(column));
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromUser => $composableBuilder(
      column: $table.fromUser, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toUser => $composableBuilder(
      column: $table.toUser, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get outgoing => $composableBuilder(
      column: $table.outgoing, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get delivered => $composableBuilder(
      column: $table.delivered, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get pendingSend => $composableBuilder(
      column: $table.pendingSend, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timeMs => $composableBuilder(
      column: $table.timeMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawEnvelopePreview => $composableBuilder(
      column: $table.rawEnvelopePreview,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get encryptedForDevice => $composableBuilder(
      column: $table.encryptedForDevice,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get serverMessageId => $composableBuilder(
      column: $table.serverMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get replyToId => $composableBuilder(
      column: $table.replyToId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replyToSender => $composableBuilder(
      column: $table.replyToSender,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replyToContent => $composableBuilder(
      column: $table.replyToContent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deliveryMode => $composableBuilder(
      column: $table.deliveryMode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deliveredAtMs => $composableBuilder(
      column: $table.deliveredAtMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meshMetaJson => $composableBuilder(
      column: $table.meshMetaJson,
      builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => column);

  GeneratedColumn<String> get fromUser =>
      $composableBuilder(column: $table.fromUser, builder: (column) => column);

  GeneratedColumn<String> get toUser =>
      $composableBuilder(column: $table.toUser, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get outgoing =>
      $composableBuilder(column: $table.outgoing, builder: (column) => column);

  GeneratedColumn<bool> get delivered =>
      $composableBuilder(column: $table.delivered, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<bool> get pendingSend => $composableBuilder(
      column: $table.pendingSend, builder: (column) => column);

  GeneratedColumn<int> get timeMs =>
      $composableBuilder(column: $table.timeMs, builder: (column) => column);

  GeneratedColumn<String> get rawEnvelopePreview => $composableBuilder(
      column: $table.rawEnvelopePreview, builder: (column) => column);

  GeneratedColumn<String> get encryptedForDevice => $composableBuilder(
      column: $table.encryptedForDevice, builder: (column) => column);

  GeneratedColumn<int> get serverMessageId => $composableBuilder(
      column: $table.serverMessageId, builder: (column) => column);

  GeneratedColumn<int> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<String> get replyToSender => $composableBuilder(
      column: $table.replyToSender, builder: (column) => column);

  GeneratedColumn<String> get replyToContent => $composableBuilder(
      column: $table.replyToContent, builder: (column) => column);

  GeneratedColumn<String> get deliveryMode => $composableBuilder(
      column: $table.deliveryMode, builder: (column) => column);

  GeneratedColumn<int> get deliveredAtMs => $composableBuilder(
      column: $table.deliveredAtMs, builder: (column) => column);

  GeneratedColumn<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson, builder: (column) => column);

  GeneratedColumn<String> get meshMetaJson => $composableBuilder(
      column: $table.meshMetaJson, builder: (column) => column);
}

class $$MessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()> {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> messageId = const Value.absent(),
            Value<String> chatId = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> serverHost = const Value.absent(),
            Value<String> fromUser = const Value.absent(),
            Value<String> toUser = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<bool> outgoing = const Value.absent(),
            Value<bool> delivered = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<bool> pendingSend = const Value.absent(),
            Value<int> timeMs = const Value.absent(),
            Value<String?> rawEnvelopePreview = const Value.absent(),
            Value<String?> encryptedForDevice = const Value.absent(),
            Value<int?> serverMessageId = const Value.absent(),
            Value<int?> replyToId = const Value.absent(),
            Value<String?> replyToSender = const Value.absent(),
            Value<String?> replyToContent = const Value.absent(),
            Value<String> deliveryMode = const Value.absent(),
            Value<int?> deliveredAtMs = const Value.absent(),
            Value<String?> reactionsJson = const Value.absent(),
            Value<String?> meshMetaJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion(
            messageId: messageId,
            chatId: chatId,
            accountId: accountId,
            serverHost: serverHost,
            fromUser: fromUser,
            toUser: toUser,
            content: content,
            outgoing: outgoing,
            delivered: delivered,
            isRead: isRead,
            pendingSend: pendingSend,
            timeMs: timeMs,
            rawEnvelopePreview: rawEnvelopePreview,
            encryptedForDevice: encryptedForDevice,
            serverMessageId: serverMessageId,
            replyToId: replyToId,
            replyToSender: replyToSender,
            replyToContent: replyToContent,
            deliveryMode: deliveryMode,
            deliveredAtMs: deliveredAtMs,
            reactionsJson: reactionsJson,
            meshMetaJson: meshMetaJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String messageId,
            required String chatId,
            required String accountId,
            required String serverHost,
            required String fromUser,
            required String toUser,
            required String content,
            required bool outgoing,
            Value<bool> delivered = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<bool> pendingSend = const Value.absent(),
            required int timeMs,
            Value<String?> rawEnvelopePreview = const Value.absent(),
            Value<String?> encryptedForDevice = const Value.absent(),
            Value<int?> serverMessageId = const Value.absent(),
            Value<int?> replyToId = const Value.absent(),
            Value<String?> replyToSender = const Value.absent(),
            Value<String?> replyToContent = const Value.absent(),
            Value<String> deliveryMode = const Value.absent(),
            Value<int?> deliveredAtMs = const Value.absent(),
            Value<String?> reactionsJson = const Value.absent(),
            Value<String?> meshMetaJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            messageId: messageId,
            chatId: chatId,
            accountId: accountId,
            serverHost: serverHost,
            fromUser: fromUser,
            toUser: toUser,
            content: content,
            outgoing: outgoing,
            delivered: delivered,
            isRead: isRead,
            pendingSend: pendingSend,
            timeMs: timeMs,
            rawEnvelopePreview: rawEnvelopePreview,
            encryptedForDevice: encryptedForDevice,
            serverMessageId: serverMessageId,
            replyToId: replyToId,
            replyToSender: replyToSender,
            replyToContent: replyToContent,
            deliveryMode: deliveryMode,
            deliveredAtMs: deliveredAtMs,
            reactionsJson: reactionsJson,
            meshMetaJson: meshMetaJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessagesTable,
    Message,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
    Message,
    PrefetchHooks Function()>;
typedef $$GroupsTableCreateCompanionBuilder = GroupsCompanion Function({
  required int groupId,
  required String accountId,
  required String serverHost,
  required String name,
  required bool isChannel,
  required String owner,
  Value<String> inviteLink,
  Value<int> avatarVersion,
  Value<String?> externalServerId,
  Value<String?> myRole,
  Value<int> rowid,
});
typedef $$GroupsTableUpdateCompanionBuilder = GroupsCompanion Function({
  Value<int> groupId,
  Value<String> accountId,
  Value<String> serverHost,
  Value<String> name,
  Value<bool> isChannel,
  Value<String> owner,
  Value<String> inviteLink,
  Value<int> avatarVersion,
  Value<String?> externalServerId,
  Value<String?> myRole,
  Value<int> rowid,
});

class $$GroupsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isChannel => $composableBuilder(
      column: $table.isChannel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get inviteLink => $composableBuilder(
      column: $table.inviteLink, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get avatarVersion => $composableBuilder(
      column: $table.avatarVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get externalServerId => $composableBuilder(
      column: $table.externalServerId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get myRole => $composableBuilder(
      column: $table.myRole, builder: (column) => ColumnFilters(column));
}

class $$GroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isChannel => $composableBuilder(
      column: $table.isChannel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get inviteLink => $composableBuilder(
      column: $table.inviteLink, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get avatarVersion => $composableBuilder(
      column: $table.avatarVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get externalServerId => $composableBuilder(
      column: $table.externalServerId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get myRole => $composableBuilder(
      column: $table.myRole, builder: (column) => ColumnOrderings(column));
}

class $$GroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isChannel =>
      $composableBuilder(column: $table.isChannel, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get inviteLink => $composableBuilder(
      column: $table.inviteLink, builder: (column) => column);

  GeneratedColumn<int> get avatarVersion => $composableBuilder(
      column: $table.avatarVersion, builder: (column) => column);

  GeneratedColumn<String> get externalServerId => $composableBuilder(
      column: $table.externalServerId, builder: (column) => column);

  GeneratedColumn<String> get myRole =>
      $composableBuilder(column: $table.myRole, builder: (column) => column);
}

class $$GroupsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GroupsTable,
    GroupRow,
    $$GroupsTableFilterComposer,
    $$GroupsTableOrderingComposer,
    $$GroupsTableAnnotationComposer,
    $$GroupsTableCreateCompanionBuilder,
    $$GroupsTableUpdateCompanionBuilder,
    (GroupRow, BaseReferences<_$AppDatabase, $GroupsTable, GroupRow>),
    GroupRow,
    PrefetchHooks Function()> {
  $$GroupsTableTableManager(_$AppDatabase db, $GroupsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> groupId = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> serverHost = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<bool> isChannel = const Value.absent(),
            Value<String> owner = const Value.absent(),
            Value<String> inviteLink = const Value.absent(),
            Value<int> avatarVersion = const Value.absent(),
            Value<String?> externalServerId = const Value.absent(),
            Value<String?> myRole = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GroupsCompanion(
            groupId: groupId,
            accountId: accountId,
            serverHost: serverHost,
            name: name,
            isChannel: isChannel,
            owner: owner,
            inviteLink: inviteLink,
            avatarVersion: avatarVersion,
            externalServerId: externalServerId,
            myRole: myRole,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int groupId,
            required String accountId,
            required String serverHost,
            required String name,
            required bool isChannel,
            required String owner,
            Value<String> inviteLink = const Value.absent(),
            Value<int> avatarVersion = const Value.absent(),
            Value<String?> externalServerId = const Value.absent(),
            Value<String?> myRole = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GroupsCompanion.insert(
            groupId: groupId,
            accountId: accountId,
            serverHost: serverHost,
            name: name,
            isChannel: isChannel,
            owner: owner,
            inviteLink: inviteLink,
            avatarVersion: avatarVersion,
            externalServerId: externalServerId,
            myRole: myRole,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GroupsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GroupsTable,
    GroupRow,
    $$GroupsTableFilterComposer,
    $$GroupsTableOrderingComposer,
    $$GroupsTableAnnotationComposer,
    $$GroupsTableCreateCompanionBuilder,
    $$GroupsTableUpdateCompanionBuilder,
    (GroupRow, BaseReferences<_$AppDatabase, $GroupsTable, GroupRow>),
    GroupRow,
    PrefetchHooks Function()>;
typedef $$GroupMessagesTableCreateCompanionBuilder = GroupMessagesCompanion
    Function({
  Value<int> id,
  required int groupId,
  required String accountId,
  required String serverHost,
  Value<int?> serverMsgId,
  required int timeMs,
  required String rawJson,
});
typedef $$GroupMessagesTableUpdateCompanionBuilder = GroupMessagesCompanion
    Function({
  Value<int> id,
  Value<int> groupId,
  Value<String> accountId,
  Value<String> serverHost,
  Value<int?> serverMsgId,
  Value<int> timeMs,
  Value<String> rawJson,
});

class $$GroupMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $GroupMessagesTable> {
  $$GroupMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get serverMsgId => $composableBuilder(
      column: $table.serverMsgId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timeMs => $composableBuilder(
      column: $table.timeMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawJson => $composableBuilder(
      column: $table.rawJson, builder: (column) => ColumnFilters(column));
}

class $$GroupMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupMessagesTable> {
  $$GroupMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get serverMsgId => $composableBuilder(
      column: $table.serverMsgId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timeMs => $composableBuilder(
      column: $table.timeMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawJson => $composableBuilder(
      column: $table.rawJson, builder: (column) => ColumnOrderings(column));
}

class $$GroupMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupMessagesTable> {
  $$GroupMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => column);

  GeneratedColumn<int> get serverMsgId => $composableBuilder(
      column: $table.serverMsgId, builder: (column) => column);

  GeneratedColumn<int> get timeMs =>
      $composableBuilder(column: $table.timeMs, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);
}

class $$GroupMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GroupMessagesTable,
    GroupMessage,
    $$GroupMessagesTableFilterComposer,
    $$GroupMessagesTableOrderingComposer,
    $$GroupMessagesTableAnnotationComposer,
    $$GroupMessagesTableCreateCompanionBuilder,
    $$GroupMessagesTableUpdateCompanionBuilder,
    (
      GroupMessage,
      BaseReferences<_$AppDatabase, $GroupMessagesTable, GroupMessage>
    ),
    GroupMessage,
    PrefetchHooks Function()> {
  $$GroupMessagesTableTableManager(_$AppDatabase db, $GroupMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> groupId = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> serverHost = const Value.absent(),
            Value<int?> serverMsgId = const Value.absent(),
            Value<int> timeMs = const Value.absent(),
            Value<String> rawJson = const Value.absent(),
          }) =>
              GroupMessagesCompanion(
            id: id,
            groupId: groupId,
            accountId: accountId,
            serverHost: serverHost,
            serverMsgId: serverMsgId,
            timeMs: timeMs,
            rawJson: rawJson,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int groupId,
            required String accountId,
            required String serverHost,
            Value<int?> serverMsgId = const Value.absent(),
            required int timeMs,
            required String rawJson,
          }) =>
              GroupMessagesCompanion.insert(
            id: id,
            groupId: groupId,
            accountId: accountId,
            serverHost: serverHost,
            serverMsgId: serverMsgId,
            timeMs: timeMs,
            rawJson: rawJson,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GroupMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GroupMessagesTable,
    GroupMessage,
    $$GroupMessagesTableFilterComposer,
    $$GroupMessagesTableOrderingComposer,
    $$GroupMessagesTableAnnotationComposer,
    $$GroupMessagesTableCreateCompanionBuilder,
    $$GroupMessagesTableUpdateCompanionBuilder,
    (
      GroupMessage,
      BaseReferences<_$AppDatabase, $GroupMessagesTable, GroupMessage>
    ),
    GroupMessage,
    PrefetchHooks Function()>;
typedef $$FavoriteChatsTableCreateCompanionBuilder = FavoriteChatsCompanion
    Function({
  required String favId,
  required String accountId,
  required String serverHost,
  required String title,
  Value<String?> avatarPath,
  required int createdAtMs,
  Value<int> rowid,
});
typedef $$FavoriteChatsTableUpdateCompanionBuilder = FavoriteChatsCompanion
    Function({
  Value<String> favId,
  Value<String> accountId,
  Value<String> serverHost,
  Value<String> title,
  Value<String?> avatarPath,
  Value<int> createdAtMs,
  Value<int> rowid,
});

class $$FavoriteChatsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteChatsTable> {
  $$FavoriteChatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get favId => $composableBuilder(
      column: $table.favId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => ColumnFilters(column));
}

class $$FavoriteChatsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteChatsTable> {
  $$FavoriteChatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get favId => $composableBuilder(
      column: $table.favId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => ColumnOrderings(column));
}

class $$FavoriteChatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteChatsTable> {
  $$FavoriteChatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get favId =>
      $composableBuilder(column: $table.favId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => column);
}

class $$FavoriteChatsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FavoriteChatsTable,
    FavoriteChatRow,
    $$FavoriteChatsTableFilterComposer,
    $$FavoriteChatsTableOrderingComposer,
    $$FavoriteChatsTableAnnotationComposer,
    $$FavoriteChatsTableCreateCompanionBuilder,
    $$FavoriteChatsTableUpdateCompanionBuilder,
    (
      FavoriteChatRow,
      BaseReferences<_$AppDatabase, $FavoriteChatsTable, FavoriteChatRow>
    ),
    FavoriteChatRow,
    PrefetchHooks Function()> {
  $$FavoriteChatsTableTableManager(_$AppDatabase db, $FavoriteChatsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteChatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteChatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteChatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> favId = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> serverHost = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> avatarPath = const Value.absent(),
            Value<int> createdAtMs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoriteChatsCompanion(
            favId: favId,
            accountId: accountId,
            serverHost: serverHost,
            title: title,
            avatarPath: avatarPath,
            createdAtMs: createdAtMs,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String favId,
            required String accountId,
            required String serverHost,
            required String title,
            Value<String?> avatarPath = const Value.absent(),
            required int createdAtMs,
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoriteChatsCompanion.insert(
            favId: favId,
            accountId: accountId,
            serverHost: serverHost,
            title: title,
            avatarPath: avatarPath,
            createdAtMs: createdAtMs,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FavoriteChatsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FavoriteChatsTable,
    FavoriteChatRow,
    $$FavoriteChatsTableFilterComposer,
    $$FavoriteChatsTableOrderingComposer,
    $$FavoriteChatsTableAnnotationComposer,
    $$FavoriteChatsTableCreateCompanionBuilder,
    $$FavoriteChatsTableUpdateCompanionBuilder,
    (
      FavoriteChatRow,
      BaseReferences<_$AppDatabase, $FavoriteChatsTable, FavoriteChatRow>
    ),
    FavoriteChatRow,
    PrefetchHooks Function()>;
typedef $$MessageRemindersTableCreateCompanionBuilder
    = MessageRemindersCompanion Function({
  required String reminderId,
  required String accountId,
  required String serverHost,
  required String messageId,
  required String chatId,
  required String chatType,
  required String chatTitle,
  required String messagePreview,
  Value<String?> avatarPath,
  Value<String?> externalServerId,
  Value<String?> otherUsername,
  Value<int?> accentColorArgb,
  required int scheduledAtMs,
  required int createdAtMs,
  Value<bool> fired,
  Value<bool> cancelled,
  Value<int> rowid,
});
typedef $$MessageRemindersTableUpdateCompanionBuilder
    = MessageRemindersCompanion Function({
  Value<String> reminderId,
  Value<String> accountId,
  Value<String> serverHost,
  Value<String> messageId,
  Value<String> chatId,
  Value<String> chatType,
  Value<String> chatTitle,
  Value<String> messagePreview,
  Value<String?> avatarPath,
  Value<String?> externalServerId,
  Value<String?> otherUsername,
  Value<int?> accentColorArgb,
  Value<int> scheduledAtMs,
  Value<int> createdAtMs,
  Value<bool> fired,
  Value<bool> cancelled,
  Value<int> rowid,
});

class $$MessageRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $MessageRemindersTable> {
  $$MessageRemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get reminderId => $composableBuilder(
      column: $table.reminderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chatType => $composableBuilder(
      column: $table.chatType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chatTitle => $composableBuilder(
      column: $table.chatTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messagePreview => $composableBuilder(
      column: $table.messagePreview,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get externalServerId => $composableBuilder(
      column: $table.externalServerId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get otherUsername => $composableBuilder(
      column: $table.otherUsername, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accentColorArgb => $composableBuilder(
      column: $table.accentColorArgb,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get scheduledAtMs => $composableBuilder(
      column: $table.scheduledAtMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get fired => $composableBuilder(
      column: $table.fired, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get cancelled => $composableBuilder(
      column: $table.cancelled, builder: (column) => ColumnFilters(column));
}

class $$MessageRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageRemindersTable> {
  $$MessageRemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get reminderId => $composableBuilder(
      column: $table.reminderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatType => $composableBuilder(
      column: $table.chatType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatTitle => $composableBuilder(
      column: $table.chatTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messagePreview => $composableBuilder(
      column: $table.messagePreview,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get externalServerId => $composableBuilder(
      column: $table.externalServerId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get otherUsername => $composableBuilder(
      column: $table.otherUsername,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accentColorArgb => $composableBuilder(
      column: $table.accentColorArgb,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scheduledAtMs => $composableBuilder(
      column: $table.scheduledAtMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get fired => $composableBuilder(
      column: $table.fired, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get cancelled => $composableBuilder(
      column: $table.cancelled, builder: (column) => ColumnOrderings(column));
}

class $$MessageRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageRemindersTable> {
  $$MessageRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get reminderId => $composableBuilder(
      column: $table.reminderId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get serverHost => $composableBuilder(
      column: $table.serverHost, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get chatType =>
      $composableBuilder(column: $table.chatType, builder: (column) => column);

  GeneratedColumn<String> get chatTitle =>
      $composableBuilder(column: $table.chatTitle, builder: (column) => column);

  GeneratedColumn<String> get messagePreview => $composableBuilder(
      column: $table.messagePreview, builder: (column) => column);

  GeneratedColumn<String> get avatarPath => $composableBuilder(
      column: $table.avatarPath, builder: (column) => column);

  GeneratedColumn<String> get externalServerId => $composableBuilder(
      column: $table.externalServerId, builder: (column) => column);

  GeneratedColumn<String> get otherUsername => $composableBuilder(
      column: $table.otherUsername, builder: (column) => column);

  GeneratedColumn<int> get accentColorArgb => $composableBuilder(
      column: $table.accentColorArgb, builder: (column) => column);

  GeneratedColumn<int> get scheduledAtMs => $composableBuilder(
      column: $table.scheduledAtMs, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => column);

  GeneratedColumn<bool> get fired =>
      $composableBuilder(column: $table.fired, builder: (column) => column);

  GeneratedColumn<bool> get cancelled =>
      $composableBuilder(column: $table.cancelled, builder: (column) => column);
}

class $$MessageRemindersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessageRemindersTable,
    MessageReminderRow,
    $$MessageRemindersTableFilterComposer,
    $$MessageRemindersTableOrderingComposer,
    $$MessageRemindersTableAnnotationComposer,
    $$MessageRemindersTableCreateCompanionBuilder,
    $$MessageRemindersTableUpdateCompanionBuilder,
    (
      MessageReminderRow,
      BaseReferences<_$AppDatabase, $MessageRemindersTable, MessageReminderRow>
    ),
    MessageReminderRow,
    PrefetchHooks Function()> {
  $$MessageRemindersTableTableManager(
      _$AppDatabase db, $MessageRemindersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageRemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> reminderId = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> serverHost = const Value.absent(),
            Value<String> messageId = const Value.absent(),
            Value<String> chatId = const Value.absent(),
            Value<String> chatType = const Value.absent(),
            Value<String> chatTitle = const Value.absent(),
            Value<String> messagePreview = const Value.absent(),
            Value<String?> avatarPath = const Value.absent(),
            Value<String?> externalServerId = const Value.absent(),
            Value<String?> otherUsername = const Value.absent(),
            Value<int?> accentColorArgb = const Value.absent(),
            Value<int> scheduledAtMs = const Value.absent(),
            Value<int> createdAtMs = const Value.absent(),
            Value<bool> fired = const Value.absent(),
            Value<bool> cancelled = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessageRemindersCompanion(
            reminderId: reminderId,
            accountId: accountId,
            serverHost: serverHost,
            messageId: messageId,
            chatId: chatId,
            chatType: chatType,
            chatTitle: chatTitle,
            messagePreview: messagePreview,
            avatarPath: avatarPath,
            externalServerId: externalServerId,
            otherUsername: otherUsername,
            accentColorArgb: accentColorArgb,
            scheduledAtMs: scheduledAtMs,
            createdAtMs: createdAtMs,
            fired: fired,
            cancelled: cancelled,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String reminderId,
            required String accountId,
            required String serverHost,
            required String messageId,
            required String chatId,
            required String chatType,
            required String chatTitle,
            required String messagePreview,
            Value<String?> avatarPath = const Value.absent(),
            Value<String?> externalServerId = const Value.absent(),
            Value<String?> otherUsername = const Value.absent(),
            Value<int?> accentColorArgb = const Value.absent(),
            required int scheduledAtMs,
            required int createdAtMs,
            Value<bool> fired = const Value.absent(),
            Value<bool> cancelled = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessageRemindersCompanion.insert(
            reminderId: reminderId,
            accountId: accountId,
            serverHost: serverHost,
            messageId: messageId,
            chatId: chatId,
            chatType: chatType,
            chatTitle: chatTitle,
            messagePreview: messagePreview,
            avatarPath: avatarPath,
            externalServerId: externalServerId,
            otherUsername: otherUsername,
            accentColorArgb: accentColorArgb,
            scheduledAtMs: scheduledAtMs,
            createdAtMs: createdAtMs,
            fired: fired,
            cancelled: cancelled,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessageRemindersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessageRemindersTable,
    MessageReminderRow,
    $$MessageRemindersTableFilterComposer,
    $$MessageRemindersTableOrderingComposer,
    $$MessageRemindersTableAnnotationComposer,
    $$MessageRemindersTableCreateCompanionBuilder,
    $$MessageRemindersTableUpdateCompanionBuilder,
    (
      MessageReminderRow,
      BaseReferences<_$AppDatabase, $MessageRemindersTable, MessageReminderRow>
    ),
    MessageReminderRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$GroupMessagesTableTableManager get groupMessages =>
      $$GroupMessagesTableTableManager(_db, _db.groupMessages);
  $$FavoriteChatsTableTableManager get favoriteChats =>
      $$FavoriteChatsTableTableManager(_db, _db.favoriteChats);
  $$MessageRemindersTableTableManager get messageReminders =>
      $$MessageRemindersTableTableManager(_db, _db.messageReminders);
}
