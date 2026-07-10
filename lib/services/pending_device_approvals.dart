// lib/services/pending_device_approvals.dart
//
// Global, account-scoped list of devices waiting for THIS device to approve
// them (only meaningful when this device is itself trusted). Populated from
// two sources: the 'device_approval_needed' WS event (root_screen.dart) and
// a GET /me/sessions refresh done on login and app-resume. Drives both the
// floating reminder bubble (pending_device_bubble.dart) and the approval
// dialog (pending_device_dialog.dart) — dismissing the dialog does NOT clear
// this list, only approving/denying (or the device no longer being pending
// server-side) does.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../globals.dart' show serverBase;
import '../managers/account_manager.dart';

class PendingDeviceApproval {
  final int id;
  final String deviceName;
  final String? deviceOs;
  final DateTime requestedAt;
  final int approvals;
  final int approvalsRequired;

  const PendingDeviceApproval({
    required this.id,
    required this.deviceName,
    this.deviceOs,
    required this.requestedAt,
    this.approvals = 0,
    this.approvalsRequired = 1,
  });
}

class PendingDeviceApprovals {
  PendingDeviceApprovals._();

  static final ValueNotifier<List<PendingDeviceApproval>> list =
      ValueNotifier<List<PendingDeviceApproval>>([]);

  static void addOrUpdate(PendingDeviceApproval item) {
    final current = List<PendingDeviceApproval>.from(list.value);
    current.removeWhere((e) => e.id == item.id);
    current.add(item);
    list.value = current;
  }

  static void remove(int id) {
    final current = List<PendingDeviceApproval>.from(list.value)
      ..removeWhere((e) => e.id == id);
    list.value = current;
  }

  static void setAll(List<PendingDeviceApproval> items) {
    list.value = items;
  }

  static void clear() {
    list.value = [];
  }

  /// Pulls the authoritative pending list from the server. Only trusted
  /// devices can call GET /me/sessions — a 403 (untrusted device) is treated
  /// as "nothing to show", not an error.
  static Future<void> refresh() async {
    try {
      final username = await AccountManager.getCurrentAccount();
      if (username == null) return;
      final token = await AccountManager.getToken(username);
      if (token == null) return;

      final res = await http
          .get(
            Uri.parse('$serverBase/me/sessions'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as List;
      final pending = data
          .cast<Map<String, dynamic>>()
          .where((s) => s['is_current'] != true && s['e2e_trusted'] != true)
          .map((s) => PendingDeviceApproval(
                id: s['id'] as int,
                deviceName: s['device_name'] as String? ?? 'Unknown device',
                deviceOs: s['device_os'] as String?,
                requestedAt: DateTime.tryParse(s['created_at'] as String? ?? '') ?? DateTime.now(),
                approvals: s['approvals'] as int? ?? 0,
                approvalsRequired: s['approvals_required'] as int? ?? 1,
              ))
          .toList();
      setAll(pending);
    } catch (_) {
      // Network hiccup — leave the existing list as-is rather than clearing it.
    }
  }

  static Future<bool> approve(int id) async {
    try {
      final username = await AccountManager.getCurrentAccount();
      if (username == null) return false;
      final token = await AccountManager.getToken(username);
      if (token == null) return false;
      final res = await http
          .post(
            Uri.parse('$serverBase/me/sessions/$id/approve'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body);
      if (data['pending'] == true) {
        // Strict mode: quorum not reached yet — update the count, keep it listed.
        final current = List<PendingDeviceApproval>.from(list.value);
        final idx = current.indexWhere((e) => e.id == id);
        if (idx != -1) {
          final old = current[idx];
          current[idx] = PendingDeviceApproval(
            id: old.id,
            deviceName: old.deviceName,
            deviceOs: old.deviceOs,
            requestedAt: old.requestedAt,
            approvals: data['approvals'] as int? ?? old.approvals,
            approvalsRequired: data['required'] as int? ?? old.approvalsRequired,
          );
          list.value = current;
        }
        return false; // not fully approved yet
      }
      remove(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deny(int id) async {
    try {
      final username = await AccountManager.getCurrentAccount();
      if (username == null) return false;
      final token = await AccountManager.getToken(username);
      if (token == null) return false;
      final res = await http
          .delete(
            Uri.parse('$serverBase/me/sessions/$id'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        remove(id);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
