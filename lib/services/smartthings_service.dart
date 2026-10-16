import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/unified_device.dart';

class SmartThingsConfig {
  final String patToken;

  const SmartThingsConfig({required this.patToken});

  Map<String, dynamic> toJson() => {'patToken': patToken};

  factory SmartThingsConfig.fromJson(Map<String, dynamic> json) =>
      SmartThingsConfig(patToken: json['patToken'] ?? '');
}

class SmartThingsService {
  SmartThingsConfig? _config;
  final String _baseUrl = 'https://api.smartthings.com/v1';

  SmartThingsConfig? get config => _config;
  bool get isConfigured =>
      _config != null && _config!.patToken.trim().isNotEmpty;

  void updateConfig(SmartThingsConfig config) {
    _config = config;
  }

  void clearConfig() {
    _config = null;
  }

  Map<String, String> _buildHeaders() {
    if (_config == null) throw Exception('SmartThings não está configurado.');
    final token = _config!.patToken.trim();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  /// Valida o token consultando a lista de dispositivos
  Future<bool> testConnection(SmartThingsConfig testConfig) async {
    final oldConfig = _config;
    _config = testConfig;
    try {
      final uri = Uri.parse('$_baseUrl/devices');
      final response = await http.get(uri, headers: _buildHeaders()).timeout(
            const Duration(seconds: 12),
          );
      return response.statusCode == 200;
    } finally {
      if (!isConfigured) _config = oldConfig;
    }
  }

  /// Lista dispositivos do SmartThings
  Future<List<UnifiedDevice>> fetchDevices() async {
    if (!isConfigured) return [];

    final uri = Uri.parse('$_baseUrl/devices');
    final response = await http.get(uri, headers: _buildHeaders()).timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode != 200) {
      throw Exception(
          'Erro ao listar SmartThings (HTTP ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> items = data['items'] ?? [];

    final List<UnifiedDevice> devices = [];

    for (final item in items) {
      final deviceId = item['deviceId']?.toString() ?? '';
      final label = item['label']?.toString() ??
          item['name']?.toString() ??
          'Dispositivo Samsung';

      final type = _detectDeviceType(label, item);

      // Ignora o Hub em si da lista de controles comuns se desejar
      if (type == DeviceType.hub) continue;

      devices.add(UnifiedDevice(
        id: 'st_$deviceId',
        rawId: deviceId,
        name: label,
        vendor: DeviceVendor.samsung,
        type: type,
        rawState: item is Map<String, dynamic> ? item : null,
      ));
    }

    return devices;
  }

  DeviceType _detectDeviceType(String label, Map<String, dynamic> item) {
    final lower = label.toLowerCase();
    if (lower.contains('hub')) return DeviceType.hub;
    if (lower.contains('soundbar') || lower.contains('audio') || lower.contains('speaker')) {
      return DeviceType.audio;
    }
    if (lower.contains('tv') || lower.contains('qn85') || lower.contains('samsung qn')) {
      return DeviceType.tv;
    }
    if (lower.contains('lavar') || lower.contains('washer') || lower.contains('dryer')) {
      return DeviceType.washingMachine;
    }
    if (lower.contains('bulb') || lower.contains('lamp') || lower.contains('led') || lower.contains('light')) {
      return DeviceType.light;
    }
    if (lower.contains('ar') || lower.contains('ac')) {
      return DeviceType.airConditioner;
    }
    return DeviceType.other;
  }

  /// Consulta status em tempo real de um aparelho SmartThings
  Future<UnifiedDevice> refreshDeviceState(UnifiedDevice device) async {
    if (!isConfigured) return device;

    try {
      final uri = Uri.parse('$_baseUrl/devices/${device.rawId}/status');
      final response = await http.get(uri, headers: _buildHeaders()).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) return device;

      final data = jsonDecode(response.body);
      final components = data['components'] as Map<String, dynamic>? ?? {};
      final mainComp = components['main'] as Map<String, dynamic>? ?? {};

      return _parseStateIntoUnified(device, mainComp, data);
    } catch (_) {
      return device;
    }
  }

  UnifiedDevice _parseStateIntoUnified(
    UnifiedDevice device,
    Map<String, dynamic> mainComp,
    Map<String, dynamic> fullData,
  ) {
    bool isPowerOn = false;
    int? volume;
    bool isMuted = false;
    String? tvChannel;
    String? tvChannelName;
    int? brightness;
    int? colorTemp;
    String? machineState;
    String? washerJobState;
    String? completionTime;

    // 1. Switch (Power)
    final switchObj = mainComp['switch'];
    if (switchObj != null) {
      final val = switchObj['switch']?['value']?.toString();
      isPowerOn = val == 'on';
    }

    // 2. Audio Volume & Mute
    final volObj = mainComp['audioVolume'];
    if (volObj != null) {
      if (volObj['volume']?['value'] != null) {
        volume = (volObj['volume']['value'] as num).toInt();
      }
    }
    final muteObj = mainComp['audioMute'];
    if (muteObj != null) {
      isMuted = muteObj['mute']?['value'] == 'muted';
    }

    // 3. TV Channel
    final chanObj = mainComp['tvChannel'];
    if (chanObj != null) {
      tvChannel = chanObj['tvChannel']?['value']?.toString();
      tvChannelName = chanObj['tvChannelName']?['value']?.toString();
    }

    // 4. Light / SwitchLevel (Brightness)
    final levelObj = mainComp['switchLevel'];
    if (levelObj != null && levelObj['level']?['value'] != null) {
      brightness = (levelObj['level']['value'] as num).toInt();
    }
    final colorObj = mainComp['colorTemperature'];
    if (colorObj != null && colorObj['colorTemperature']?['value'] != null) {
      colorTemp = (colorObj['colorTemperature']['value'] as num).toInt();
    }

    // 5. Washer Operating State
    final washerObj = mainComp['washerOperatingState'];
    if (washerObj != null) {
      machineState = washerObj['machineState']?['value']?.toString();
      washerJobState = washerObj['washerJobState']?['value']?.toString();
      completionTime = washerObj['completionTime']?['value']?.toString();
    }

    final newCaps = device.capabilities.copyWith(
      volume: volume ?? device.capabilities.volume,
      isMuted: isMuted,
      tvChannel: tvChannel,
      tvChannelName: tvChannelName,
      brightness: brightness ?? device.capabilities.brightness,
      colorTemperature: colorTemp ?? device.capabilities.colorTemperature,
      machineState: machineState,
      washerJobState: washerJobState,
      completionTime: completionTime,
    );

    return device.copyWith(
      isPowerOn: isPowerOn,
      capabilities: newCaps,
      rawState: fullData,
    );
  }

  /// Envia comandos padronizados para o endpoint /commands do SmartThings
  Future<bool> executeCommand(
    String deviceId, {
    String capability = 'switch',
    String command = 'on',
    List<dynamic> arguments = const [],
    String component = 'main',
  }) async {
    if (!isConfigured) return false;

    final uri = Uri.parse('$_baseUrl/devices/$deviceId/commands');
    final payload = {
      'commands': [
        {
          'component': component,
          'capability': capability,
          'command': command,
          'arguments': arguments,
        }
      ]
    };

    final response = await http.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    return response.statusCode == 200 || response.statusCode == 202;
  }

  /// Ligar / Desligar via switch
  Future<bool> setPower(String deviceId, bool turnOn) async {
    return executeCommand(
      deviceId,
      capability: 'switch',
      command: turnOn ? 'on' : 'off',
    );
  }

  /// Controle de Volume
  Future<bool> setVolume(String deviceId, int volume) async {
    return executeCommand(
      deviceId,
      capability: 'audioVolume',
      command: 'setVolume',
      arguments: [volume.clamp(0, 100)],
    );
  }

  /// Mudo / Desmudo
  Future<bool> setMute(String deviceId, bool mute) async {
    return executeCommand(
      deviceId,
      capability: 'audioMute',
      command: mute ? 'mute' : 'unmute',
    );
  }

  /// Controle de Brilho da Lâmpada (0 a 100%)
  Future<bool> setBrightness(String deviceId, int level) async {
    return executeCommand(
      deviceId,
      capability: 'switchLevel',
      command: 'setLevel',
      arguments: [level.clamp(0, 100)],
    );
  }

  /// Exclui um dispositivo da conta SmartThings
  Future<bool> deleteDevice(String deviceId) async {
    if (!isConfigured) return false;

    final uri = Uri.parse('$_baseUrl/devices/$deviceId');
    final response = await http.delete(uri, headers: _buildHeaders()).timeout(
          const Duration(seconds: 15),
        );

    return response.statusCode == 200 || response.statusCode == 204;
  }
}
