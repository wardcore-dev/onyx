import 'package:flutter/foundation.dart';

class UnreadManager with ChangeNotifier {
  
  final Map<String, int> _unreadCounts = {};

  int getUnreadCount(String chatId) => _unreadCounts[chatId] ?? 0;

  void markAsRead(String chatId) {
    if (_unreadCounts.containsKey(chatId) && _unreadCounts[chatId]! > 0) {
      _unreadCounts[chatId] = 0;
      notifyListeners();
    }
  }

  void incrementUnread(String chatId) {
    _unreadCounts[chatId] = (_unreadCounts[chatId] ?? 0) + 1;
    notifyListeners();
  }

  void setUnreadCount(String chatId, int count) {
    if (_unreadCounts[chatId] != count) {
      _unreadCounts[chatId] = count;
      notifyListeners();
    }
  }

  void reset() {
    _unreadCounts.clear();
    notifyListeners();
  }

  int getTotalUnread() {
    return _unreadCounts.values.fold(0, (sum, count) => sum + count);
  }
}

final unreadManager = UnreadManager();