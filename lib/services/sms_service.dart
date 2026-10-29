import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';
import 'ble_service.dart';

/// Service to send direct SIM SMS messages from the device without external servers or n8n.
class SmsService {
  static const MethodChannel _channel = MethodChannel('com.example.vt/sms');

  /// Requests SMS permission from the Android system.
  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Sends a raw SMS to a single phone number via the device's native SIM.
  Future<bool> sendSingleSms({
    required String phone,
    required String message,
  }) async {
    try {
      final bool hasPermission = await Permission.sms.isGranted ||
          await Permission.sms.request().isGranted;

      if (!hasPermission) {
        debugPrint('[SmsService] SMS permission denied by user.');
        return false;
      }

      final result = await _channel.invokeMethod<bool>('sendSms', {
        'phone': phone,
        'message': message,
      });
      debugPrint('[SmsService] SMS to $phone dispatched: $result');
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint('[SmsService] Platform error sending SMS to $phone: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[SmsService] Error sending SMS to $phone: $e');
      return false;
    }
  }

  /// Sends emergency accident alert SMS to all registered emergency contacts.
  Future<bool> sendAccidentAlert(AccidentEvent event) async {
    try {
      // 1. Fetch contacts
      final response = await ApiService.getContacts();
      List<dynamic> contacts = [];
      if (response.success && response.data != null) {
        contacts = response.data!['contacts'] ?? [];
      }

      if (contacts.isEmpty) {
        debugPrint('[SmsService] No emergency contacts found to alert.');
        return false;
      }

      // 2. Prepare message
      final mapUrl = 'https://maps.google.com/?q=${event.lat},${event.lon}';
      final message =
          'EMERGENCY ALERT: Accident detected!\n'
          'Device: ${event.deviceId}\n'
          'Location: ${event.lat.toStringAsFixed(6)}, ${event.lon.toStringAsFixed(6)}\n'
          'Map: $mapUrl';

      // 3. Dispatch SMS to each contact
      int successCount = 0;
      for (final contact in contacts) {
        final phone = contact['phone']?.toString().trim();
        if (phone != null && phone.isNotEmpty) {
          final ok = await sendSingleSms(phone: phone, message: message);
          if (ok) successCount++;
        }
      }

      debugPrint('[SmsService] Dispatched SMS to $successCount/${contacts.length} contacts.');
      return successCount > 0;
    } catch (e) {
      debugPrint('[SmsService] Exception in sendAccidentAlert: $e');
      return false;
    }
  }
}
