import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_service.dart';
import '../services/ble_service.dart';
import '../services/sms_service.dart';
import '../services/webhook_service.dart';
import 'accident_alert_screen.dart';
import 'contacts_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleService _bleService = BleService();
  final WebhookService _webhookService = WebhookService();
  final SmsService _smsService = SmsService();

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  bool _alertShowing = false;
  String _deviceName = '--';
  String _batteryText = '--';
  double? _lastLat;
  double? _lastLon;

  late StreamSubscription<String> _statusSub;
  late StreamSubscription<BleConnectionState> _connectionSub;
  late StreamSubscription<AccidentEvent> _accidentSub;
  late StreamSubscription<LocationEvent> _locationSub;
  late StreamSubscription<int> _batterySub;

  @override
  void initState() {
    super.initState();

    _smsService.requestSmsPermission();

    _statusSub = _bleService.statusStream.listen((_) {});

    _connectionSub = _bleService.connectionStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _connectionState = state;
        if (state == BleConnectionState.connected) {
          _deviceName = _bleService.connectedDeviceName.isNotEmpty
              ? _bleService.connectedDeviceName
              : 'AcciAlert Device';
        } else {
          _deviceName = '--';
          _batteryText = '--';
        }
      });
    });

    _accidentSub = _bleService.accidentStream.listen((event) {
      if (!mounted) return;
      _onAccidentDetected(event);
    });

    _locationSub = _bleService.locationStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _lastLat = event.lat;
        _lastLon = event.lon;
        if (event.battery != null) {
          _batteryText = '${event.battery}%';
        }
      });
    });

    _batterySub = _bleService.batteryStream.listen((battery) {
      if (!mounted) return;
      setState(() {
        _batteryText = '$battery%';
      });
    });
  }

  Future<bool> _requestBluetoothPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
        Permission.sms,
      ].request();

      final allGranted = statuses.values.every((s) => s.isGranted);
      if (!allGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissions required for Bluetooth and SMS'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _handleScan() async {
    final hasPermissions = await _requestBluetoothPermissions();
    if (!hasPermissions) return;

    if (!await FlutterBluePlus.isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth not supported on this device'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please turn on Bluetooth'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    _bleService.startScan();
  }

  void _handleDisconnect() {
    _bleService.disconnect();
  }

  void _onAccidentDetected(AccidentEvent event) {
    if (_alertShowing) return;
    _alertShowing = true;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => AccidentAlertScreen(
              event: event,
              smsService: _smsService,
              webhookService: _webhookService,
            ),
          ),
        )
        .then((_) => _alertShowing = false);
  }

  void _openContacts() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ContactsScreen()));
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _statusSub.cancel();
    _connectionSub.cancel();
    _accidentSub.cancel();
    _locationSub.cancel();
    _batterySub.cancel();
    _bleService.dispose();
    super.dispose();
  }

  Color _statusColor() {
    switch (_connectionState) {
      case BleConnectionState.disconnected:
        return const Color(0xFFE53935);
      case BleConnectionState.scanning:
      case BleConnectionState.connecting:
        return const Color(0xFFFFA000);
      case BleConnectionState.connected:
        return const Color(0xFF43A047);
    }
  }

  String _statusLabel() {
    switch (_connectionState) {
      case BleConnectionState.disconnected:
        return 'Disconnected';
      case BleConnectionState.scanning:
        return 'Scanning...';
      case BleConnectionState.connecting:
        return 'Connecting...';
      case BleConnectionState.connected:
        return 'Connected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionState == BleConnectionState.connected;

    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AcciAlert',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            tooltip: 'Test Alert',
            onPressed: () {
              _onAccidentDetected(
                AccidentEvent(
                  deviceId: _deviceName != '--' ? _deviceName : 'DEMO_DEVICE',
                  lat: _lastLat ?? 20.363743,
                  lon: _lastLon ?? 85.815004,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Central Connection Target
              if (!isConnected)
                _buildDisconnectedState()
              else
                _buildConnectedState(),

              const Spacer(flex: 2),

              // Simple Emergency Contacts Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _openContacts,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF2C323B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.people_outline, size: 20),
                  label: const Text(
                    'Emergency Contacts',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedState() {
    final isScanning =
        _connectionState == BleConnectionState.scanning ||
        _connectionState == BleConnectionState.connecting;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isScanning ? null : _handleScan,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1F26),
              border: Border.all(
                color: _statusColor().withValues(alpha: 0.5),
                width: 3,
              ),
            ),
            child: Icon(
              isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
              size: 80,
              color: _statusColor(),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          _statusLabel(),
          style: TextStyle(
            color: _statusColor(),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isScanning
              ? 'Looking for nearby device'
              : 'Tap to scan and connect',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildConnectedState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C323B)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF43A047),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'CONNECTED',
                style: TextStyle(
                  color: Color(0xFF43A047),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _deviceName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Battery', style: TextStyle(color: Colors.white54)),
              Text(_batteryText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
          const Divider(height: 24, color: Color(0xFF2C323B)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Location', style: TextStyle(color: Colors.white54)),
              Text(
                _lastLat != null
                    ? '${_lastLat!.toStringAsFixed(4)}, ${_lastLon!.toStringAsFixed(4)}'
                    : 'Awaiting fix',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _handleDisconnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C1E20),
                foregroundColor: const Color(0xFFE53935),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Disconnect'),
            ),
          ),
        ],
      ),
    );
  }
}
