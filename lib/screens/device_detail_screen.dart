import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/unified_device.dart';
import '../services/device_manager_provider.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  int _selectedTimerHours = 1;
  bool _showAdvancedSettings = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceManagerProvider>();
    final device = provider.devices.firstWhere(
      (d) => d.id == widget.deviceId,
      orElse: () => const UnifiedDevice(
        id: '',
        rawId: '',
        name: 'Dispositivo',
        vendor: DeviceVendor.other,
        type: DeviceType.other,
      ),
    );

    if (device.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dispositivo não encontrado')),
        body: const Center(child: Text('Dispositivo não encontrado ou removido.')),
      );
    }

    final caps = device.capabilities;
    final isPowerOn = device.isPowerOn;

    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          IconButton(
            tooltip: 'Sincronizar status',
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.refreshAllDevices(),
          ),
          IconButton(
            tooltip: 'Excluir dispositivo',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _confirmDeleteDevice(context, device, provider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // CARD PRINCIPAL: STATUS + POWER BUTTON
          _buildPowerHeaderCard(context, device, provider),
          const SizedBox(height: 20),

          // CONTROLES ESPECÍFICOS CONFORME O TIPO DE DISPOSITIVO
          if (device.type == DeviceType.airConditioner)
            ..._buildAirConditionerControls(context, device, provider)
          else if (device.type == DeviceType.tv || device.type == DeviceType.audio)
            ..._buildAudioVideoControls(context, device, provider)
          else if (device.type == DeviceType.light)
            ..._buildLightControls(context, device, provider)
          else if (device.type == DeviceType.washingMachine)
            ..._buildWasherControls(context, device, provider),
        ],
      ),
    );
  }

  Widget _buildPowerHeaderCard(
    BuildContext context,
    UnifiedDevice device,
    DeviceManagerProvider provider,
  ) {
    final isPowerOn = device.isPowerOn;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForType(device.type),
                  color: isPowerOn ? Theme.of(context).colorScheme.primary : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isPowerOn ? 'Ligado e Ativo' : 'Desligado',
                      style: TextStyle(
                        color: isPowerOn ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: isPowerOn ? Colors.redAccent : Colors.grey[700],
                padding: const EdgeInsets.all(14),
              ),
              icon: const Icon(Icons.power_settings_new, color: Colors.white, size: 28),
              onPressed: () => provider.toggleDevicePower(device),
            ),
          ],
        ),
      ),
    );
  }

  // --- CONTROLES DE TV & SOUNDBAR (SAMSUNG) ---
  List<Widget> _buildAudioVideoControls(
    BuildContext context,
    UnifiedDevice device,
    DeviceManagerProvider provider,
  ) {
    final caps = device.capabilities;
    final isPowerOn = device.isPowerOn;
    final currentVol = (caps.volume ?? 15).toDouble();

    return [
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Controle de Volume',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(
                      caps.isMuted ? Icons.volume_off : Icons.volume_up,
                      color: caps.isMuted ? Colors.red : Colors.blueAccent,
                    ),
                    onPressed: isPowerOn ? () => provider.toggleDeviceMute(device) : null,
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.volume_down),
                    onPressed: isPowerOn && currentVol > 0
                        ? () => provider.setDeviceVolume(
                            device, (currentVol - 1).clamp(0, 100).round())
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: currentVol,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: '${currentVol.round()}%',
                      onChanged: isPowerOn
                          ? (val) => provider.setDeviceVolume(device, val.round())
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    icon: const Icon(Icons.volume_up),
                    onPressed: isPowerOn && currentVol < 100
                        ? () => provider.setDeviceVolume(
                            device, (currentVol + 1).clamp(0, 100).round())
                        : null,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${currentVol.round()}%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (caps.tvChannel != null) ...[
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Icon(Icons.tv, color: Colors.indigoAccent),
            title: const Text('Canal Atual'),
            subtitle: Text(
              caps.tvChannelName != null && caps.tvChannelName!.isNotEmpty
                  ? '${caps.tvChannel} - ${caps.tvChannelName}'
                  : 'Canal ${caps.tvChannel}',
            ),
          ),
        ),
      ],
    ];
  }

  // --- CONTROLES DE ILUMINAÇÃO (YEELIGHT) ---
  List<Widget> _buildLightControls(
    BuildContext context,
    UnifiedDevice device,
    DeviceManagerProvider provider,
  ) {
    final caps = device.capabilities;
    final isPowerOn = device.isPowerOn;
    final brightness = (caps.brightness ?? 50).toDouble();

    return [
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Intensidade do Brilho',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text('${brightness.round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.brightness_low, color: Colors.amber),
                  Expanded(
                    child: Slider(
                      value: brightness,
                      min: 1,
                      max: 100,
                      divisions: 100,
                      activeColor: Colors.amber,
                      onChanged: isPowerOn
                          ? (val) => provider.setDeviceBrightness(device, val.round())
                          : null,
                    ),
                  ),
                  const Icon(Icons.brightness_high, color: Colors.amber),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // --- CONTROLES DE MÁQUINA DE LAVAR (SAMSUNG) ---
  List<Widget> _buildWasherControls(
    BuildContext context,
    UnifiedDevice device,
    DeviceManagerProvider provider,
  ) {
    final caps = device.capabilities;

    return [
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status da Lavadora',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ciclo Operacional:'),
                  Text(
                    caps.machineState?.toUpperCase() ?? 'PARADA',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ],
              ),
              if (caps.washerJobState != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Etapa Atual:'),
                    Text(
                      caps.washerJobState!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  // --- CONTROLES DE AR CONDICIONADO (LG) ---
  List<Widget> _buildAirConditionerControls(
    BuildContext context,
    UnifiedDevice device,
    DeviceManagerProvider provider,
  ) {
    final caps = device.capabilities;
    final isPowerOn = device.isPowerOn;
    final targetTemp = caps.targetTemperature ?? 24.0;
    final currentTemp = caps.currentTemperature;

    return [
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    targetTemp.toStringAsFixed(1).replaceAll('.0', ''),
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w300,
                      color: isPowerOn ? Theme.of(context).colorScheme.primary : Colors.grey,
                    ),
                  ),
                  Text(
                    '°${caps.temperatureUnit}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: isPowerOn ? Colors.blueGrey : Colors.grey,
                    ),
                  ),
                ],
              ),
              if (currentTemp != null)
                Text(
                  'Temperatura ambiente: ${currentTemp.toStringAsFixed(1)}°${caps.temperatureUnit}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    iconSize: 32,
                    icon: const Icon(Icons.remove),
                    onPressed: isPowerOn && targetTemp > caps.minTemperature
                        ? () => provider.setDeviceTemperature(
                            device, targetTemp - caps.temperatureStep)
                        : null,
                  ),
                  const SizedBox(width: 40),
                  IconButton.outlined(
                    iconSize: 32,
                    icon: const Icon(Icons.add),
                    onPressed: isPowerOn && targetTemp < caps.maxTemperature
                        ? () => provider.setDeviceTemperature(
                            device, targetTemp + caps.temperatureStep)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      // SWING E LUZ DO PAINEL
      Row(
        children: [
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: caps.rotateUpDown
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isPowerOn ? () => provider.toggleDeviceSwing(device) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swap_vert,
                        color: caps.rotateUpDown
                            ? Theme.of(context).colorScheme.primary
                            : (isPowerOn ? Colors.grey[700] : Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        caps.rotateUpDown ? 'Swing Ativo' : 'Swing Parado',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: caps.displayLightOn
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isPowerOn ? () => provider.toggleDeviceDisplayLight(device) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        caps.displayLightOn ? Icons.lightbulb : Icons.lightbulb_outline,
                        color: caps.displayLightOn
                            ? Colors.amber
                            : (isPowerOn ? Colors.grey[700] : Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        caps.displayLightOn ? 'Luz Acesa' : 'Luz Apagada',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildOffTimerSection(context, device, provider),
      const SizedBox(height: 20),
      // MODOS DE OPERAÇÃO
      const Text('Modo de Operação',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: caps.availableModes.map((mode) {
          final isSelected = caps.currentMode == mode;
          return ChoiceChip(
            label: Text(_translateMode(mode)),
            avatar: Icon(_getModeIcon(mode), size: 18),
            selected: isSelected,
            onSelected: isPowerOn
                ? (selected) {
                    if (selected) provider.setDeviceMode(device, mode);
                  }
                : null,
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      // VENTILAÇÃO NÍVEIS 1 A 5
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Velocidade da Ventilação',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Nível ${caps.fanLevel}',
              style: const TextStyle(
                  color: Colors.blueAccent, fontWeight: FontWeight.bold)),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: List.generate(5, (index) {
          final level = index + 1;
          final isSelected = caps.fanLevel == level;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index < 4 ? 8 : 0),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      isSelected ? Theme.of(context).colorScheme.primary : null,
                  foregroundColor: isSelected ? Colors.white : null,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed:
                    isPowerOn ? () => provider.setDeviceFanLevel(device, level) : null,
                child: Text('$level',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 24),
      // CONFIGURAÇÕES AVANÇADAS
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ExpansionTile(
          initiallyExpanded: _showAdvancedSettings,
          onExpansionChanged: (val) => setState(() => _showAdvancedSettings = val),
          leading: const Icon(Icons.tune, color: Colors.indigoAccent),
          title: const Text('Diagnóstico e Filtro de Ar',
              style: TextStyle(fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (caps.filterHealthPercentage != null) ...[
                    Text(
                        'Vida útil do filtro: ${caps.filterHealthPercentage}% restante (${caps.filterUsedHours ?? 0}h / ${caps.filterLifetimeHours ?? 0}h)',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (caps.filterHealthPercentage! / 100).clamp(0.0, 1.0),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Estado Operacional: ${caps.runState}'),
                  Text('ID do Aparelho: ${device.rawId}'),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildOffTimerSection(
    BuildContext context,
    UnifiedDevice device,
    DeviceManagerProvider provider,
  ) {
    final caps = device.capabilities;
    final isTimerActive = caps.isStopTimerSet;
    final remainingHours = caps.stopTimerRemainingHours;
    final remainingMins = caps.stopTimerRemainingMinutes;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.orangeAccent),
                const SizedBox(width: 10),
                const Text('Programar Desligamento',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (isTimerActive)
                  Text('Desliga em ${remainingHours ?? 0}h ${remainingMins ?? 0}m',
                      style: const TextStyle(
                          color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (isTimerActive)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                icon: const Icon(Icons.timer_off_outlined),
                label: const Text('Cancelar Timer'),
                onPressed: () => provider.cancelDeviceOffTimer(device),
              )
            else ...[
              Wrap(
                spacing: 8,
                children: [1, 2, 3, 4, 6, 8].map((hours) {
                  return ChoiceChip(
                    label: Text('${hours}h'),
                    selected: _selectedTimerHours == hours,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTimerHours = hours);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.schedule),
                label: Text('Ativar em ${_selectedTimerHours}h'),
                onPressed: device.isPowerOn
                    ? () => provider.setDeviceOffTimer(device, _selectedTimerHours)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(DeviceType type) {
    switch (type) {
      case DeviceType.airConditioner:
        return Icons.ac_unit;
      case DeviceType.tv:
        return Icons.tv;
      case DeviceType.audio:
        return Icons.speaker;
      case DeviceType.washingMachine:
        return Icons.local_laundry_service;
      case DeviceType.light:
        return Icons.lightbulb_outline;
      default:
        return Icons.devices;
    }
  }

  String _translateMode(String mode) {
    switch (mode) {
      case 'COOL':
        return 'Refrigerar';
      case 'HEAT':
        return 'Aquecer';
      case 'FAN':
        return 'Ventilar';
      case 'AIR_DRY':
        return 'Desumidificar';
      case 'AUTO':
        return 'Automático';
      default:
        return mode;
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'COOL':
        return Icons.ac_unit;
      case 'HEAT':
        return Icons.wb_sunny_outlined;
      case 'FAN':
        return Icons.air;
      case 'AIR_DRY':
        return Icons.water_drop_outlined;
      default:
        return Icons.tune;
    }
  }

  void _confirmDeleteDevice(
    BuildContext context,
    UnifiedDevice device,
    DeviceManagerProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Excluir Aparelho'),
          ],
        ),
        content: Text(
          'Deseja realmente remover "${device.name}" da sua conta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.deleteDevice(device);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Dispositivo "${device.name}" removido com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Não foi possível excluir o dispositivo pela API.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
