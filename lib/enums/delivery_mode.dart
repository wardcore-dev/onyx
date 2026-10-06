// lib/enums/delivery_mode.dart
enum DeliveryMode {
  internet,
  lan,
  bleMesh,
  onion,
}

extension DeliveryModeExtension on DeliveryMode {
  String get displayName {
    switch (this) {
      case DeliveryMode.internet:
        return 'Internet';
      case DeliveryMode.lan:
        return 'LAN';
      case DeliveryMode.bleMesh:
        return 'Mesh';
      case DeliveryMode.onion:
        return 'Tor';
    }
  }

  bool get isLAN => this == DeliveryMode.lan;
  bool get isInternet => this == DeliveryMode.internet;
  bool get isMesh => this == DeliveryMode.bleMesh;
  bool get isOnion => this == DeliveryMode.onion;
}
