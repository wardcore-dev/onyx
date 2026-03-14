// lib/enums/delivery_mode.dart
enum DeliveryMode {
  
  internet,

  lan,
}

extension DeliveryModeExtension on DeliveryMode {
  String get displayName {
    switch (this) {
      case DeliveryMode.internet:
        return 'Internet';
      case DeliveryMode.lan:
        return 'LAN';
    }
  }

  bool get isLAN => this == DeliveryMode.lan;
  bool get isInternet => this == DeliveryMode.internet;
}