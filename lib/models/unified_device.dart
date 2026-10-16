enum DeviceVendor {
  lg,
  samsung,
  other,
}

enum DeviceType {
  airConditioner,
  refrigerator,
  tv,
  audio,
  washingMachine,
  light,
  hub,
  other,
}

/// Generic unified capability representation for smart devices
class DeviceCapabilities {
  // Climatização (AC)
  final double? targetTemperature;
  final double? currentTemperature;
  final double minTemperature;
  final double maxTemperature;
  final double temperatureStep;
  final String temperatureUnit;
  final List<String> availableModes;
  final String? currentMode;

  // Fan speed / levels (AC)
  final int fanLevel; // 1 a 5
  final int minFanLevel;
  final int maxFanLevel;
  final String? fanSpeed; // AUTO, LOW, etc.

  // Oscilação das Aletas (Swing / Rotate Up Down)
  final bool rotateUpDown;

  // Luz do Display do Painel (ON / OFF)
  final bool displayLightOn;

  // Informações de Filtro de Ar
  final int? filterLifetimeHours;
  final int? filterUsedHours;

  // Economia de Energia
  final bool powerSaveEnabled;

  // Status de Erro / Normal
  final String runState;

  // Timers (Off Timer / Sleep Timer)
  final bool isStopTimerSet;
  final int? stopTimerRemainingHours;
  final int? stopTimerRemainingMinutes;

  // Áudio / Vídeo (TV & Soundbar)
  final int? volume; // 0 a 100
  final bool isMuted;
  final String? tvChannel;
  final String? tvChannelName;
  final String? mediaInputSource;
  final String? playbackStatus; // play, pause, stop

  // Iluminação (Lâmpada Inteligente / Yeelight)
  final int? brightness; // 0 a 100
  final int? colorTemperature; // Kelvin

  // Eletrodomésticos (Máquina de Lavar)
  final String? machineState; // run, stop, pause
  final String? washerJobState;
  final String? completionTime;

  const DeviceCapabilities({
    this.targetTemperature,
    this.currentTemperature,
    this.minTemperature = 18.0,
    this.maxTemperature = 30.0,
    this.temperatureStep = 0.5,
    this.temperatureUnit = 'C',
    this.availableModes = const ['COOL', 'AUTO', 'FAN', 'AIR_DRY', 'HEAT'],
    this.currentMode,
    this.fanLevel = 3,
    this.minFanLevel = 1,
    this.maxFanLevel = 5,
    this.fanSpeed,
    this.rotateUpDown = false,
    this.displayLightOn = true,
    this.filterLifetimeHours,
    this.filterUsedHours,
    this.powerSaveEnabled = false,
    this.runState = 'NORMAL',
    this.isStopTimerSet = false,
    this.stopTimerRemainingHours,
    this.stopTimerRemainingMinutes,
    this.volume,
    this.isMuted = false,
    this.tvChannel,
    this.tvChannelName,
    this.mediaInputSource,
    this.playbackStatus,
    this.brightness,
    this.colorTemperature,
    this.machineState,
    this.washerJobState,
    this.completionTime,
  });

  /// Percentual de vida útil restante do filtro (0 a 100%)
  int? get filterHealthPercentage {
    if (filterLifetimeHours == null || filterLifetimeHours! <= 0) return null;
    final used = filterUsedHours ?? 0;
    final remaining = (filterLifetimeHours! - used).clamp(0, filterLifetimeHours!);
    return ((remaining / filterLifetimeHours!) * 100).round();
  }

  DeviceCapabilities copyWith({
    double? targetTemperature,
    double? currentTemperature,
    double? minTemperature,
    double? maxTemperature,
    double? temperatureStep,
    String? temperatureUnit,
    List<String>? availableModes,
    String? currentMode,
    int? fanLevel,
    int? minFanLevel,
    int? maxFanLevel,
    String? fanSpeed,
    bool? rotateUpDown,
    bool? displayLightOn,
    int? filterLifetimeHours,
    int? filterUsedHours,
    bool? powerSaveEnabled,
    String? runState,
    bool? isStopTimerSet,
    int? stopTimerRemainingHours,
    int? stopTimerRemainingMinutes,
    int? volume,
    bool? isMuted,
    String? tvChannel,
    String? tvChannelName,
    String? mediaInputSource,
    String? playbackStatus,
    int? brightness,
    int? colorTemperature,
    String? machineState,
    String? washerJobState,
    String? completionTime,
  }) {
    return DeviceCapabilities(
      targetTemperature: targetTemperature ?? this.targetTemperature,
      currentTemperature: currentTemperature ?? this.currentTemperature,
      minTemperature: minTemperature ?? this.minTemperature,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      temperatureStep: temperatureStep ?? this.temperatureStep,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      availableModes: availableModes ?? this.availableModes,
      currentMode: currentMode ?? this.currentMode,
      fanLevel: fanLevel ?? this.fanLevel,
      minFanLevel: minFanLevel ?? this.minFanLevel,
      maxFanLevel: maxFanLevel ?? this.maxFanLevel,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      rotateUpDown: rotateUpDown ?? this.rotateUpDown,
      displayLightOn: displayLightOn ?? this.displayLightOn,
      filterLifetimeHours: filterLifetimeHours ?? this.filterLifetimeHours,
      filterUsedHours: filterUsedHours ?? this.filterUsedHours,
      powerSaveEnabled: powerSaveEnabled ?? this.powerSaveEnabled,
      runState: runState ?? this.runState,
      isStopTimerSet: isStopTimerSet ?? this.isStopTimerSet,
      stopTimerRemainingHours:
          stopTimerRemainingHours ?? this.stopTimerRemainingHours,
      stopTimerRemainingMinutes:
          stopTimerRemainingMinutes ?? this.stopTimerRemainingMinutes,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      tvChannel: tvChannel ?? this.tvChannel,
      tvChannelName: tvChannelName ?? this.tvChannelName,
      mediaInputSource: mediaInputSource ?? this.mediaInputSource,
      playbackStatus: playbackStatus ?? this.playbackStatus,
      brightness: brightness ?? this.brightness,
      colorTemperature: colorTemperature ?? this.colorTemperature,
      machineState: machineState ?? this.machineState,
      washerJobState: washerJobState ?? this.washerJobState,
      completionTime: completionTime ?? this.completionTime,
    );
  }
}

/// Generic unified smart device model across any vendor
class UnifiedDevice {
  final String id;
  final String rawId;
  final String name;
  final String? room;
  final DeviceVendor vendor;
  final DeviceType type;
  final bool isOnline;
  final bool isPowerOn;
  final DeviceCapabilities capabilities;
  final Map<String, dynamic>? rawState;

  const UnifiedDevice({
    required this.id,
    required this.rawId,
    required this.name,
    this.room,
    required this.vendor,
    required this.type,
    this.isOnline = true,
    this.isPowerOn = false,
    this.capabilities = const DeviceCapabilities(),
    this.rawState,
  });

  UnifiedDevice copyWith({
    String? name,
    String? room,
    bool? isOnline,
    bool? isPowerOn,
    DeviceCapabilities? capabilities,
    Map<String, dynamic>? rawState,
  }) {
    return UnifiedDevice(
      id: id,
      rawId: rawId,
      name: name ?? this.name,
      room: room ?? this.room,
      vendor: vendor,
      type: type,
      isOnline: isOnline ?? this.isOnline,
      isPowerOn: isPowerOn ?? this.isPowerOn,
      capabilities: capabilities ?? this.capabilities,
      rawState: rawState ?? this.rawState,
    );
  }
}
