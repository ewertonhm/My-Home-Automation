import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../models/unified_device.dart';

class LgThinqConfig {
  final String patToken;
  final String baseUrl;
  final String countryCode;
  final String clientId;
  final String apiKey;

  const LgThinqConfig({
    required this.patToken,
    this.baseUrl = 'https://api-aic.lgthinq.com',
    this.countryCode = 'BR',
    required this.clientId,
    this.apiKey = 'v6GFvkweNo7DK7yD3ylIZ9w52aKBU0eJ7wLXkSR3',
  });

  Map<String, dynamic> toJson() => {
        'patToken': patToken,
        'baseUrl': baseUrl,
        'countryCode': countryCode,
        'clientId': clientId,
        'apiKey': apiKey,
      };

  factory LgThinqConfig.fromJson(Map<String, dynamic> json) => LgThinqConfig(
        patToken: json['patToken'] ?? '',
        baseUrl: json['baseUrl'] ?? 'https://api-aic.lgthinq.com',
        countryCode: json['countryCode'] ?? 'BR',
        clientId: json['clientId'] ?? const Uuid().v4(),
        apiKey: json['apiKey'] ?? 'v6GFvkweNo7DK7yD3ylIZ9w52aKBU0eJ7wLXkSR3',
      );
}

class LgThinqService {
  LgThinqConfig? _config;
  final _uuid = const Uuid();

  LgThinqConfig? get config => _config;
  bool get isConfigured => _config != null && _config!.patToken.trim().isNotEmpty;

  void updateConfig(LgThinqConfig config) {
    _config = config;
  }

  void clearConfig() {
    _config = null;
  }

  String _generateMessageId() {
    final rawUuid = _uuid.v4obj();
    return base64UrlEncode(rawUuid.toBytes()).replaceAll('=', '');
  }

  Map<String, String> _buildHeaders() {
    if (_config == null) {
      throw Exception('LG ThinQ não está configurada.');
    }

    final token = _config!.patToken.trim();
    final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';

    return {
      'Authorization': authHeader,
      'x-api-key': _config!.apiKey,
      'x-country': _config!.countryCode,
      'x-client-id': _config!.clientId,
      'x-message-id': _generateMessageId(),
      'Content-Type': 'application/json',
    };
  }

  /// Testa a conexão com o endpoint
  Future<bool> testConnection(LgThinqConfig testConfig) async {
    final oldConfig = _config;
    _config = testConfig;
    try {
      final uri = Uri.parse('${testConfig.baseUrl}/devices');
      final response = await http.get(uri, headers: _buildHeaders()).timeout(
            const Duration(seconds: 12),
          );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
            'Falha na validação (HTTP ${response.statusCode}): ${response.body}');
      }
    } finally {
      if (!isConfigured) {
        _config = oldConfig;
      }
    }
  }

  /// Lista todos os aparelhos
  Future<List<UnifiedDevice>> fetchDevices() async {
    if (!isConfigured) return [];

    final uri = Uri.parse('${_config!.baseUrl}/devices');
    final response = await http.get(uri, headers: _buildHeaders()).timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar dispositivos LG (HTTP ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    final dynamic respPayload = data['response'] ?? data['devices'] ?? data;
    final List<dynamic> deviceList = respPayload is List ? respPayload : [];

    final List<UnifiedDevice> devices = [];

    for (final item in deviceList) {
      final deviceId = item['deviceId']?.toString() ?? '';
      final info = item['deviceInfo'] ?? item;
      final deviceType = info['deviceType']?.toString() ?? '';
      final alias = info['alias']?.toString() ?? info['nickname']?.toString() ?? 'LG Device';
      final modelName = info['modelName']?.toString();

      DeviceType type = DeviceType.other;
      if (deviceType.contains('AIR_CONDITIONER') ||
          deviceType.contains('AC') ||
          (modelName != null && modelName.contains('RAC'))) {
        type = DeviceType.airConditioner;
      } else if (deviceType.contains('REFRIGERATOR')) {
        type = DeviceType.refrigerator;
      } else if (deviceType.contains('WASHER') || deviceType.contains('DRYER')) {
        type = DeviceType.washingMachine;
      }

      final unified = UnifiedDevice(
        id: 'lg_$deviceId',
        rawId: deviceId,
        name: alias.trim(),
        vendor: DeviceVendor.lg,
        type: type,
        rawState: item is Map<String, dynamic> ? item : null,
      );

      devices.add(unified);
    }

    return devices;
  }

  /// Busca o estado em tempo real
  Future<UnifiedDevice> refreshDeviceState(UnifiedDevice device) async {
    if (!isConfigured) return device;

    try {
      final uri = Uri.parse('${_config!.baseUrl}/devices/${device.rawId}/state');
      final response = await http.get(uri, headers: _buildHeaders()).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) {
        return device;
      }

      final data = jsonDecode(response.body);
      final stateData = data['response'] ?? data['state'] ?? data;

      return _parseStateIntoUnified(device, stateData is Map<String, dynamic> ? stateData : {});
    } catch (_) {
      return device;
    }
  }

  UnifiedDevice _parseStateIntoUnified(
      UnifiedDevice device, Map<String, dynamic> state) {
    bool isPowerOn = false;
    double? currentTemp;
    double? targetTemp;
    String? currentJobMode;
    String? fanSpeed;
    int fanLevel = 3;
    bool isStopTimerSet = false;
    int? stopRemainingHours;
    int? stopRemainingMinutes;
    bool rotateUpDown = false;
    bool displayLightOn = true;
    int? filterLifetime;
    int? filterUsed;
    bool powerSaveEnabled = false;
    String runState = 'NORMAL';

    // Run State
    final runObj = state['runState'];
    if (runObj != null) {
      runState = runObj['currentState']?.toString() ?? 'NORMAL';
    }

    // Operation mode (airConOperationMode: POWER_ON / POWER_OFF)
    final operation = state['operation'];
    if (operation != null) {
      final acOp = operation['airConOperationMode'] ?? operation['currentState'];
      if (acOp == 'POWER_ON' || acOp == 'START') {
        isPowerOn = true;
      } else if (acOp == 'POWER_OFF' || acOp == 'STOP') {
        isPowerOn = false;
      }
    }

    // Temperature (currentTemperature, targetTemperature, unit)
    final tempObj = state['temperature'];
    if (tempObj != null) {
      if (tempObj['currentTemperature'] != null) {
        currentTemp = (tempObj['currentTemperature'] as num).toDouble();
      }
      if (tempObj['targetTemperature'] != null) {
        targetTemp = (tempObj['targetTemperature'] as num).toDouble();
      }
    }

    // AirCon Job Mode (COOL, HEAT, FAN, AIR_DRY, etc.)
    final jobModeObj = state['airConJobMode'];
    if (jobModeObj != null) {
      currentJobMode = jobModeObj['currentJobMode']?.toString();
    }

    // Air flow / Fan speed & level
    final airFlow = state['airFlow'];
    if (airFlow != null) {
      fanSpeed = airFlow['windStrength']?.toString();
      if (airFlow['windStep'] != null) {
        fanLevel = (airFlow['windStep'] as num).toInt();
      } else if (fanSpeed != null) {
        fanLevel = _mapWindStrengthToLevel(fanSpeed);
      }
    }

    // Wind Direction (Oscilação das aletas)
    final windDir = state['windDirection'];
    if (windDir != null) {
      rotateUpDown = windDir['rotateUpDown'] == true;
    }

    // Display Light
    final disp = state['display'];
    if (disp != null) {
      displayLightOn = disp['light'] != 'OFF';
    }

    // Filter Info
    final filter = state['filterInfo'];
    if (filter != null) {
      filterLifetime = filter['filterLifetime'] as int?;
      filterUsed = filter['usedTime'] as int?;
    }

    // Power Save
    final pSave = state['powerSave'];
    if (pSave != null) {
      powerSaveEnabled = pSave['powerSaveEnabled'] == true;
    }

    // Timers (relativeStopTimer / sleepTimer)
    final timer = state['timer'];
    if (timer != null) {
      if (timer['relativeStopTimer'] == 'SET') {
        isStopTimerSet = true;
        stopRemainingHours = timer['relativeHourToStop'] as int?;
        stopRemainingMinutes = timer['relativeMinuteToStop'] as int?;
      }
    }
    final sleepTimer = state['sleepTimer'];
    if (sleepTimer != null && sleepTimer['relativeStopTimer'] == 'SET') {
      isStopTimerSet = true;
      stopRemainingHours ??= sleepTimer['relativeHourToStop'] as int?;
      stopRemainingMinutes ??= sleepTimer['relativeMinuteToStop'] as int?;
    }

    final newCaps = device.capabilities.copyWith(
      targetTemperature: targetTemp ?? device.capabilities.targetTemperature,
      currentTemperature: currentTemp ?? device.capabilities.currentTemperature,
      currentMode: currentJobMode ?? device.capabilities.currentMode,
      fanSpeed: fanSpeed ?? device.capabilities.fanSpeed,
      fanLevel: fanLevel,
      rotateUpDown: rotateUpDown,
      displayLightOn: displayLightOn,
      filterLifetimeHours: filterLifetime,
      filterUsedHours: filterUsed,
      powerSaveEnabled: powerSaveEnabled,
      runState: runState,
      isStopTimerSet: isStopTimerSet,
      stopTimerRemainingHours: stopRemainingHours,
      stopTimerRemainingMinutes: stopRemainingMinutes,
    );

    return device.copyWith(
      isPowerOn: isPowerOn,
      capabilities: newCaps,
      rawState: state,
    );
  }

  int _mapWindStrengthToLevel(String strength) {
    switch (strength.toUpperCase()) {
      case 'LOW':
        return 1;
      case 'MID_LOW':
        return 2;
      case 'MID':
        return 3;
      case 'MID_HIGH':
        return 4;
      case 'HIGH':
      case 'POWER':
        return 5;
      default:
        return 3;
    }
  }

  String _mapLevelToWindStrength(int level) {
    switch (level) {
      case 1:
        return 'LOW';
      case 2:
        return 'LOW';
      case 3:
        return 'MID';
      case 4:
        return 'HIGH';
      case 5:
        return 'HIGH';
      default:
        return 'MID';
    }
  }

  /// Envia comando de controle para o dispositivo
  Future<bool> sendControlCommand(String deviceRawId, Map<String, dynamic> command) async {
    if (!isConfigured) return false;

    final uri = Uri.parse('${_config!.baseUrl}/devices/$deviceRawId/control');
    final response = await http.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(command),
    ).timeout(const Duration(seconds: 15));

    return response.statusCode == 200 || response.statusCode == 202;
  }

  /// Ligar / Desligar
  Future<bool> setPower(String deviceRawId, bool turnOn) async {
    return sendControlCommand(deviceRawId, {
      'operation': {
        'airConOperationMode': turnOn ? 'POWER_ON' : 'POWER_OFF',
      }
    });
  }

  /// Alterar temperatura alvo (passo de 0.5°C)
  Future<bool> setTargetTemperature(String deviceRawId, double targetTemp) async {
    return sendControlCommand(deviceRawId, {
      'temperature': {
        'targetTemperature': targetTemp,
      }
    });
  }

  /// Alterar modo de trabalho (COOL, HEAT, FAN, AIR_DRY)
  Future<bool> setJobMode(String deviceRawId, String mode) async {
    return sendControlCommand(deviceRawId, {
      'airConJobMode': {
        'currentJobMode': mode,
      }
    });
  }

  /// Alterar velocidade do vento por Nível (1 a 5)
  Future<bool> setFanLevel(String deviceRawId, int level) async {
    final clampedLevel = level.clamp(1, 5);
    return sendControlCommand(deviceRawId, {
      'airFlow': {
        'windStep': clampedLevel,
        'windStrength': _mapLevelToWindStrength(clampedLevel),
      }
    });
  }

  /// Ligar / Desligar Oscilação Vertical (Swing das Aletas)
  Future<bool> setSwingUpDown(String deviceRawId, bool rotate) async {
    return sendControlCommand(deviceRawId, {
      'windDirection': {
        'rotateUpDown': rotate,
      }
    });
  }

  /// Ligar / Desligar Luz do Display do Ar Condicionado
  Future<bool> setDisplayLight(String deviceRawId, bool turnOn) async {
    return sendControlCommand(deviceRawId, {
      'display': {
        'light': turnOn ? 'ON' : 'OFF',
      }
    });
  }

  /// Programar para desligar daqui a X horas (e minutos opcionais)
  Future<bool> setOffTimer(String deviceRawId, {required int hours, int minutes = 0}) async {
    return sendControlCommand(deviceRawId, {
      'timer': {
        'relativeHourToStop': hours,
        'relativeMinuteToStop': minutes,
      }
    });
  }

  /// Cancelar o timer de desligamento programado
  Future<bool> cancelOffTimer(String deviceRawId) async {
    return sendControlCommand(deviceRawId, {
      'timer': {
        'relativeStopTimer': 'UNSET',
      }
    });
  }
}
