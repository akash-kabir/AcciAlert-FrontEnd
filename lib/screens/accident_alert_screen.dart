import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ble_service.dart';
import '../services/sms_service.dart';
import '../services/webhook_service.dart';

/// Clean, spacious accident alert countdown screen.
class AccidentAlertScreen extends StatefulWidget {
  final AccidentEvent event;
  final SmsService? smsService;
  final WebhookService? webhookService;

  const AccidentAlertScreen({
    super.key,
    required this.event,
    this.smsService,
    this.webhookService,
  });

  @override
  State<AccidentAlertScreen> createState() => _AccidentAlertScreenState();
}

class _AccidentAlertScreenState extends State<AccidentAlertScreen> {
  static const int countdownSeconds = 10;

  int _remaining = countdownSeconds;
  Timer? _timer;
  bool _sending = false;
  bool _sent = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        timer.cancel();
        _sendAlert();
      }
    });
  }

  Future<void> _sendAlert() async {
    if (_cancelled) return;
    setState(() => _sending = true);

    final sms = widget.smsService ?? SmsService();
    final success = await sms.sendAccidentAlert(widget.event);

    if (widget.webhookService != null) {
      widget.webhookService!.sendAccidentAlert(widget.event);
    }

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = success;
    });

    final message = success
        ? 'Emergency alert sent to contacts'
        : 'Failed to send alert';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context).pop();
  }

  void _cancelAlert() {
    _timer?.cancel();
    setState(() => _cancelled = true);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 12),

              // Title
              Column(
                children: const [
                  Text(
                    'Accident Detected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sending emergency alert if no response',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),

              // Countdown display
              if (!_sent && !_cancelled && !_sending) ...[
                Column(
                  children: [
                    Text(
                      '$_remaining',
                      style: const TextStyle(
                        color: Color(0xFFEF5350),
                        fontSize: 96,
                        fontWeight: FontWeight.w300,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'seconds',
                      style: TextStyle(color: Colors.white38, fontSize: 16),
                    ),
                  ],
                ),
              ],

              if (_sending)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Colors.redAccent),
                    SizedBox(height: 16),
                    Text('Sending alerts...', style: TextStyle(color: Colors.white70)),
                  ],
                ),

              if (_sent)
                const Column(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 54),
                    SizedBox(height: 12),
                    Text('Alert Sent', style: TextStyle(color: Colors.white, fontSize: 20)),
                  ],
                ),

              // Actions
              if (!_sent && !_cancelled && !_sending)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _cancelAlert,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "I'M OK — CANCEL",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        _timer?.cancel();
                        _sendAlert();
                      },
                      child: const Text(
                        'Send Now',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
