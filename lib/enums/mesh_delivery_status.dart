// lib/enums/mesh_delivery_status.dart
enum MeshDeliveryStatus {
  /// Пакет создан, ожидает прямой доставки или relay-узла.
  sending,

  /// Принят промежуточным узлом и путешествует по mesh-сети.
  relayed,

  /// Получатель прислал ACK — сообщение доставлено.
  delivered,

  /// Истёк TTL или таймаут — доставка не подтверждена.
  failed,
}
