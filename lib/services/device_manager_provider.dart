import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/unified_device.dart';
import 'lg_thinq_service.dart';
import 'smartthings_service.dart';

class DeviceManagerProvider extends ChangeNotifier {
  final LgThinqService lgService = LgThinqService();
  final SmartThingsService stService = SmartThingsService();

  List<UnifiedDevice> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Map<String, Timer> _debounceTimers = {};

  List<UnifiedDevice> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isLgConnected => lgService.isConfigured;
  bool get isStConnected => stService.isConfigured;

  DeviceManagerProvider() {
    _loadStoredConfigs();
  }

  Future<void> _loadStoredConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Carregar LG ThinQ
      final lgJson = prefs.getString('lg_thinq_config');
      if (lgJson != null) {
        final map = jsonDecode(lgJson);
        lgService.updateConfig(LgThinqConfig.fromJson(map));
      }

      // Carregar Samsung SmartThings
      final stJson = prefs.getString('smartthings_config');
      if (stJson != null) {
        final map = jsonDecode(stJson);
        stService.updateConfig(SmartThingsConfig.fromJson(map));
      }

      if (isLgConnected || isStConnected) {
        refreshAllDevices();
      }
    } catch (e) {
      debugPrint('Erro ao carregar configurações salvas: $e');
    }
  }

  /// Conecta LG ThinQ
  Future<bool> connectLgThinq(LgThinqConfig config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await lgService.testConnection(config);
      if (success) {
        lgService.updateConfig(config);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lg_thinq_config', jsonEncode(config.toJson()));

        await refreshAllDevices();
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> disconnectLgThinq() async {
    lgService.clearConfig();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lg_thinq_config');
    _devices.removeWhere((d) => d.vendor == DeviceVendor.lg);
    notifyListeners();
  }

  /// Conecta Samsung SmartThings
  Future<bool> connectSmartThings(SmartThingsConfig config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await stService.testConnection(config);
      if (success) {
        stService.updateConfig(config);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('smartthings_config', jsonEncode(config.toJson()));

        await refreshAllDevices();
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Falha SmartThings: ${e.toString().replaceAll('Exception: ', '')}';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> disconnectSmartThings() async {
    stService.clearConfig();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('smartthings_config');
    _devices.removeWhere((d) => d.vendor == DeviceVendor.samsung);
    notifyListeners();
  }

  /// Atualiza todos os dispositivos registrados e seus status em tempo real
  Future<void> refreshAllDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<UnifiedDevice> all = [];

      // 1. Dispositivos LG ThinQ
      if (lgService.isConfigured) {
        try {
          final lgDevs = await lgService.fetchDevices();
          for (final dev in lgDevs) {
            final updated = await lgService.refreshDeviceState(dev);
            all.add(updated);
          }
        } catch (e) {
          debugPrint('Erro ao buscar dispositivos LG: $e');
        }
      }

      // 2. Dispositivos Samsung SmartThings
      if (stService.isConfigured) {
        try {
          final stDevs = await stService.fetchDevices();
          for (final dev in stDevs) {
            final updated = await stService.refreshDeviceState(dev);
            all.add(updated);
          }
        } catch (e) {
          debugPrint('Erro ao buscar dispositivos SmartThings: $e');
        }
      }

      _devices = all;
    } catch (e) {
      _errorMessage = 'Erro ao sincronizar dispositivos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Controle unificado de Ligar / Desligar (LG e Samsung)
  Future<void> toggleDevicePower(UnifiedDevice device) async {
    final nextState = !device.isPowerOn;
    _updateDeviceLocally(device.copyWith(isPowerOn: nextState));

    bool success = false;
    if (device.vendor == DeviceVendor.lg) {
      success = await lgService.setPower(device.rawId, nextState);
    } else if (device.vendor == DeviceVendor.samsung) {
      success = await stService.setPower(device.rawId, nextState);
    }

    if (!success) {
      _updateDeviceLocally(device.copyWith(isPowerOn: !nextState));
    } else {
      _refreshSingleDevice(device);
    }
  }

  // --- CONTROLES DE AR CONDICIONADO (LG) ---
  Future<void> setDeviceTemperature(UnifiedDevice device, double temp) async {
    // Atualização otimista imediata
    final newCaps = device.capabilities.copyWith(targetTemperature: temp);
    _updateDeviceLocally(device.copyWith(capabilities: newCaps));

    // Debounce: cancela o timer anterior e aguarda o usuário parar de clicar
    final key = '${device.id}_temperature';
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(const Duration(milliseconds: 500), () async {
      // Lê o valor mais recente da lista (captura cliques acumulados)
      final current = _devices.firstWhere(
        (d) => d.id == device.id,
        orElse: () => device,
      );
      final latestTemp = current.capabilities.targetTemperature ?? temp;

      bool success = false;
      if (device.vendor == DeviceVendor.lg) {
        success = await lgService.setTargetTemperature(device.rawId, latestTemp);
      }
      if (success) _refreshSingleDevice(device);
      _debounceTimers.remove(key);
    });
  }

  Future<void> setDeviceMode(UnifiedDevice device, String mode) async {
    final newCaps = device.capabilities.copyWith(currentMode: mode);
    _updateDeviceLocally(device.copyWith(capabilities: newCaps));

    bool success = false;
    if (device.vendor == DeviceVendor.lg) {
      success = await lgService.setJobMode(device.rawId, mode);
    }
    if (success) _refreshSingleDevice(device);
  }

  Future<void> setDeviceFanLevel(UnifiedDevice device, int level) async {
    final newCaps = device.capabilities.copyWith(fanLevel: level);
    _updateDeviceLocally(device.copyWith(capabilities: newCaps));

    bool success = false;
    if (device.vendor == DeviceVendor.lg) {
      success = await lgService.setFanLevel(device.rawId, level);
    }
    if (success) _refreshSingleDevice(device);
  }

  Future<void> toggleDeviceSwing(UnifiedDevice device) async {
    final nextState = !device.capabilities.rotateUpDown;
    final newCaps = device.capabilities.copyWith(rotateUpDown: nextState);
    _updateDeviceLocally(device.copyWith(capabilities: newCaps));

    bool success = false;
    if (device.vendor == DeviceVendor.lg) {
      success = await lgService.setSwingUpDown(device.rawId, nextState);
    }
    if (!success) {
      _updateDeviceLocally(device.copyWith(
        capabilities: device.capabilities.copyWith(rotateUpDown: !nextState),
      ));
    } else {
      _refreshSingleDevice(device);
    }
  }

  Future<void> toggleDeviceDisplayLight(UnifiedDevice device) async {
    final nextState = !device.capabilities.displayLightOn;
    final newCaps = device.capabilities.copyWith(displayLightOn: nextState);
    _updateDeviceLocally(device.copyWith(capabilities: newCaps));

    bool success = false;
    if (device.vendor == DeviceVendor.lg) {
      success = await lgService.setDisplayLight(device.rawId, nextState);
    }
    if (!success) {
      _updateDeviceLocally(device.copyWith(
        capabilities: device.capabilities.copyWith(displayLightOn: !nextState),
      ));
    } else {
      _refreshSingleDevice(device);
    }
  }

  Future<bool> setDeviceOffTimer(UnifiedDevice device, int hours) async {
    bool success = false;
    if (device.vendor == DeviceVendor.lg) {
      success = await lgService.setOffTimer(device.rawId, hours: hours);
    }
    if (success) _refreshSingleDevice(device);
    return success;
  }

  Future<bool> cancelDeviceOffTimer(UnifiedDevice device) async {
    bool success = false;
    if (device.vendor == DeviceVendor.lg) {
      success = await lgService.cancelOffTimer(device.rawId);
    }
    if (success) _refreshSingleDevice(device);
    return success;
  }

  // --- CONTROLES DE ÁUDIO & TV (SAMSUNG SMARTTHINGS) ---
  Future<void> setDeviceVolume(UnifiedDevice device, int volume) async {
    // Atualização otimista imediata
    final newCaps = device.capabilities.copyWith(volume: volume);
    _updateDeviceLocally(device.copyWith(capabilities: newCaps));

    // Debounce: cancela o timer anterior e aguarda o usuário parar de clicar
    final key = '${device.id}_volume';
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(const Duration(milliseconds: 500), () async {
      // Lê o valor mais recente da lista (captura cliques acumulados)
      final current = _devices.firstWhere(
        (d) => d.id == device.id,
        orElse: () => device,
      );
      final latestVolume = current.capabilities.volume ?? volume;

      bool success = false;
      if (device.vendor == DeviceVendor.samsung) {
        success = await stService.setVolume(device.rawId, latestVolume);
      }
      if (success) _refreshSingleDevice(device);
      _debounceTimers.remove(key);
    });
  }

  Future<void> toggleDeviceMute(UnifiedDevice device) async {
    final nextState = !device.capabilities.isMuted;
    final newCaps = device.capabilities.copyWith(isMuted: nextState);
    _updateDeviceLocally(device.copyWith(capabilities: newCaps));

    bool success = false;
    if (device.vendor == DeviceVendor.samsung) {
      success = await stService.setMute(device.rawId, nextState);
    }
    if (!success) {
      _updateDeviceLocally(device.copyWith(
        capabilities: device.capabilities.copyWith(isMuted: !nextState),
      ));
    } else {
      _refreshSingleDevice(device);
    }
  }

  // --- CONTROLES DE ILUMINAÇÃO (SMARTTHINGS / YEELIGHT) ---
  Future<void> setDeviceBrightness(UnifiedDevice device, int brightness) async {
    final newCaps = device.capabilities.copyWith(brightness: brightness);
    _updateDeviceLocally(device.copyWith(capabilities: newCaps));

    bool success = false;
    if (device.vendor == DeviceVendor.samsung) {
      success = await stService.setBrightness(device.rawId, brightness);
    }
    if (success) _refreshSingleDevice(device);
  }

  /// Exclui um dispositivo do fornecedor e da lista do app
  Future<bool> deleteDevice(UnifiedDevice device) async {
    bool success = false;
    if (device.vendor == DeviceVendor.samsung) {
      success = await stService.deleteDevice(device.rawId);
    }

    if (success) {
      _devices.removeWhere((d) => d.id == device.id);
      notifyListeners();
    }
    return success;
  }

  void _updateDeviceLocally(UnifiedDevice updated) {
    final index = _devices.indexWhere((d) => d.id == updated.id);
    if (index != -1) {
      _devices[index] = updated;
      notifyListeners();
    }
  }

  Future<void> _refreshSingleDevice(UnifiedDevice device) async {
    if (device.vendor == DeviceVendor.lg) {
      final refreshed = await lgService.refreshDeviceState(device);
      _updateDeviceLocally(refreshed);
    } else if (device.vendor == DeviceVendor.samsung) {
      final refreshed = await stService.refreshDeviceState(device);
      _updateDeviceLocally(refreshed);
    }
  }

  @override
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    super.dispose();
  }
}
