import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/unified_device.dart';
import '../services/device_manager_provider.dart';
import 'connections_screen.dart';
import 'device_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'TODOS';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.home_outlined, size: 28),
            SizedBox(width: 8),
            Text(
              'Home Automation',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar aparelhos',
            icon: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : () => provider.refreshAllDevices(),
          ),
          IconButton(
            tooltip: 'Gerenciar Integrações (LG, Samsung)',
            icon: Badge(
              isLabelVisible: !provider.isLgConnected && !provider.isStConnected,
              label: const Text('!'),
              child: const Icon(Icons.hub_outlined),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectionsScreen()),
              );
            },
          ),
        ],
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, DeviceManagerProvider provider) {
    if (!provider.isLgConnected && !provider.isStConnected && provider.devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.blueAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                'Nenhuma conta conectada',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Conecte suas contas LG ThinQ ou Samsung SmartThings para controlar seus aparelhos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.hub_outlined),
                label: const Text('Configurar Conexões'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConnectionsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    if (provider.isLoading && provider.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.device_unknown, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nenhum dispositivo encontrado nas contas ativas.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => provider.refreshAllDevices(),
              child: const Text('Sincronizar novamente'),
            ),
          ],
        ),
      );
    }

    // Filtragem de dispositivos por categoria
    final filteredDevices = provider.devices.where((d) {
      if (_selectedCategory == 'TODOS') return true;
      if (_selectedCategory == 'CLIMA') return d.type == DeviceType.airConditioner;
      if (_selectedCategory == 'TV_AUDIO') return d.type == DeviceType.tv || d.type == DeviceType.audio;
      if (_selectedCategory == 'LUZES') return d.type == DeviceType.light;
      if (_selectedCategory == 'ELETRO') return d.type == DeviceType.washingMachine || d.type == DeviceType.refrigerator;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => provider.refreshAllDevices(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (provider.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // FILTRO POR CATEGORIAS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryFilter('TODOS', 'Todos (${provider.devices.length})'),
                const SizedBox(width: 8),
                _buildCategoryFilter('CLIMA', 'Climatização'),
                const SizedBox(width: 8),
                _buildCategoryFilter('TV_AUDIO', 'TV & Áudio'),
                const SizedBox(width: 8),
                _buildCategoryFilter('LUZES', 'Luzes'),
                const SizedBox(width: 8),
                _buildCategoryFilter('ELETRO', 'Eletro'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // TÍTULO DA SEÇÃO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dispositivos (${filteredDevices.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${filteredDevices.where((d) => d.isPowerOn).length} ligados',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // GRID DE DISPOSITIVOS RESPONSIVO (WINDOWS / ANDROID)
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 850 ? 3 : (constraints.maxWidth > 580 ? 2 : 1);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 175,
                ),
                itemCount: filteredDevices.length,
                itemBuilder: (context, index) {
                  final device = filteredDevices[index];
                  return _buildDeviceCard(context, device, provider);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(String key, String label) {
    final isSelected = _selectedCategory == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedCategory = key);
      },
    );
  }

  Widget _buildDeviceCard(
    BuildContext context,
    UnifiedDevice device,
    DeviceManagerProvider provider,
  ) {
    final isPowerOn = device.isPowerOn;
    final caps = device.capabilities;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeviceDetailScreen(deviceId: device.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // HEADER CARD: ICON + VENDOR BADGE + POWER BUTTON
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPowerOn
                              ? _getDeviceColor(device.type).withOpacity(0.15)
                              : Colors.grey.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getDeviceIcon(device.type),
                          color: isPowerOn ? _getDeviceColor(device.type) : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // BADGE DO FABRICANTE (LG / SAMSUNG)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: device.vendor == DeviceVendor.lg
                              ? Colors.red.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          device.vendor == DeviceVendor.lg ? 'LG' : 'Samsung',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: device.vendor == DeviceVendor.lg
                                ? Colors.redAccent
                                : Colors.blueAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // POWER TOGGLE
                  IconButton(
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.power_settings_new,
                      color: isPowerOn ? Colors.redAccent : Colors.grey[500],
                    ),
                    onPressed: () => provider.toggleDevicePower(device),
                  ),
                ],
              ),

              // NOME DO DISPOSITIVO
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isPowerOn ? 'Ligado' : 'Desligado',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPowerOn ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // INFORMAÇÕES CONTEXTUAIS CONFORME O TIPO
              _buildDeviceSummary(context, device),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSummary(BuildContext context, UnifiedDevice device) {
    final caps = device.capabilities;
    final isPowerOn = device.isPowerOn;

    if (device.type == DeviceType.airConditioner) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (caps.targetTemperature != null)
            Text(
              '${caps.targetTemperature!.toStringAsFixed(1).replaceAll('.0', '')}°${caps.temperatureUnit}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isPowerOn ? Colors.blueAccent : Colors.grey,
              ),
            )
          else
            const SizedBox.shrink(),
          Row(
            children: [
              if (caps.isStopTimerSet && isPowerOn) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 12, color: Colors.deepOrange),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimerBadge(caps),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (caps.currentMode != null && isPowerOn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    caps.currentMode!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    } else if (device.type == DeviceType.tv || device.type == DeviceType.audio) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                caps.isMuted ? Icons.volume_off : Icons.volume_up,
                size: 16,
                color: isPowerOn ? Colors.indigoAccent : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                caps.isMuted ? 'Mudo' : '${caps.volume ?? 0}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isPowerOn ? Colors.indigoAccent : Colors.grey,
                ),
              ),
            ],
          ),
          if (caps.tvChannel != null && caps.tvChannel!.isNotEmpty)
            Text(
              'Canal ${caps.tvChannel}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      );
    } else if (device.type == DeviceType.light) {
      return Row(
        children: [
          const Icon(Icons.brightness_6, size: 16, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            'Brilho: ${caps.brightness ?? 0}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isPowerOn ? Colors.amber.shade800 : Colors.grey,
            ),
          ),
        ],
      );
    } else if (device.type == DeviceType.washingMachine) {
      return Row(
        children: [
          const Icon(Icons.local_laundry_service, size: 16, color: Colors.teal),
          const SizedBox(width: 4),
          Text(
            caps.machineState?.toUpperCase() ?? 'DESLIGADA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isPowerOn ? Colors.teal : Colors.grey,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  IconData _getDeviceIcon(DeviceType type) {
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

  Color _getDeviceColor(DeviceType type) {
    switch (type) {
      case DeviceType.airConditioner:
        return Colors.blueAccent;
      case DeviceType.tv:
        return Colors.indigoAccent;
      case DeviceType.audio:
        return Colors.deepPurpleAccent;
      case DeviceType.washingMachine:
        return Colors.teal;
      case DeviceType.light:
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatTimerBadge(DeviceCapabilities caps) {
    final hours = caps.stopTimerRemainingHours ?? 0;
    final mins = caps.stopTimerRemainingMinutes ?? 0;

    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else if (mins > 0) {
      return '${mins}m';
    } else {
      return '<1m';
    }
  }
}
