class MessageReminder {
  final String reminderId;
  final String messageId;
  final String chatId;
  final String chatType; // 'dm' | 'fav' | 'group' | 'extgroup' | 'mesh'
  final String chatTitle;
  final String messagePreview;
  final String? avatarPath;
  final String? externalServerId;
  final String? otherUsername;
  final int? accentColorArgb;
  final DateTime scheduledAt;
  final DateTime createdAt;
  final bool fired;
  final bool cancelled;

  const MessageReminder({
    required this.reminderId,
    required this.messageId,
    required this.chatId,
    required this.chatType,
    required this.chatTitle,
    required this.messagePreview,
    this.avatarPath,
    this.externalServerId,
    this.otherUsername,
    this.accentColorArgb,
    required this.scheduledAt,
    required this.createdAt,
    this.fired = false,
    this.cancelled = false,
  });
}
