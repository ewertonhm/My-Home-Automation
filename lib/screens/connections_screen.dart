import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../services/device_manager_provider.dart';
import '../services/lg_thinq_service.dart';
import '../services/smartthings_service.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final _patController = TextEditingController();
  final _stTokenController = TextEditingController();
  String _selectedBaseUrl = 'https://api-aic.lgthinq.com';
  String _countryCode = 'BR';
  bool _isSavingLg = false;
  bool _isSavingSt = false;

  final Map<String, String> _regions = {
    'América do Sul e Norte (Brasil, US, etc)': 'https://api-aic.lgthinq.com',
    'Ásia-Pacífico / KIC': 'https://api-kic.lgthinq.com',
    'Europa, Oriente Médio, África': 'https://api-eic.lgthinq.com',
  };

  @override
  void initState() {
    super.initState();
    final provider = context.read<DeviceManagerProvider>();
    if (provider.lgService.isConfigured) {
      _patController.text = provider.lgService.config!.patToken;
      _selectedBaseUrl = provider.lgService.config!.baseUrl;
      _countryCode = provider.lgService.config!.countryCode;
    }
    if (provider.stService.isConfigured) {
      _stTokenController.text = provider.stService.config!.patToken;
    }
  }

  @override
  void dispose() {
    _patController.dispose();
    _stTokenController.dispose();
    super.dispose();
  }

  Future<void> _openPatPortal() async {
    final uri = Uri.parse('https://connect-pat.lgthinq.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openSmartThingsPortal() async {
    final uri = Uri.parse('https://account.smartthings.com/tokens');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _saveLgConfig() async {
    final token = _patController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe seu token PAT da LG ThinQ.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSavingLg = true);
    final provider = context.read<DeviceManagerProvider>();

    final config = LgThinqConfig(
      patToken: token,
      baseUrl: _selectedBaseUrl,
      countryCode: _countryCode.toUpperCase().trim(),
      clientId: provider.lgService.config?.clientId ?? const Uuid().v4(),
    );

    final success = await provider.connectLgThinq(config);
    setState(() => _isSavingLg = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Conectado com sucesso à LG ThinQ!'
              : (provider.errorMessage ?? 'Falha ao conectar LG.')),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _saveSmartThingsConfig() async {
    final token = _stTokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe seu token PAT do Samsung SmartThings.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSavingSt = true);
    final provider = context.read<DeviceManagerProvider>();

    final config = SmartThingsConfig(patToken: token);
    final success = await provider.connectSmartThings(config);
    setState(() => _isSavingSt = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Conectado com sucesso ao Samsung SmartThings!'
              : (provider.errorMessage ?? 'Falha ao conectar SmartThings.')),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrações & Contas'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // LG THINQ CARD
          _buildLgCard(provider),
          const SizedBox(height: 20),
          // SAMSUNG SMARTTHINGS CARD (ATIVO)
          _buildSamsungCard(provider),
          const SizedBox(height: 20),
          // TUYA / OUTROS (FUTURO)
          _buildComingSoonCard(
            title: 'Tuya / Smart Life',
            subtitle: 'Suporte para tomadas e interruptores adicionais.',
            icon: Icons.lightbulb_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildLgCard(DeviceManagerProvider provider) {
    final isConnected = provider.isLgConnected;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.ac_unit, color: Colors.redAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LG ThinQ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isConnected ? 'Conectado e Ativo' : 'Não conectado',
                        style: TextStyle(
                          color: isConnected ? Colors.green : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  IconButton(
                    tooltip: 'Desconectar conta',
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    onPressed: () {
                      provider.disconnectLgThinq();
                      _patController.clear();
                    },
                  ),
              ],
            ),
            const Divider(height: 24),
            // GUIA PASSO A PASSO
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      const Text('Obter Token PAT:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: _openPatPortal,
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Portal LG'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Gere o token em https://connect-pat.lgthinq.com e cole abaixo.'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _patController,
              decoration: const InputDecoration(
                labelText: 'LG Personal Access Token (PAT)',
                hintText: 'Cole o token da LG aqui',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedBaseUrl,
                    decoration: const InputDecoration(
                      labelText: 'Região do Servidor',
                      border: OutlineInputBorder(),
                    ),
                    items: _regions.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.value,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBaseUrl = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'País',
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(text: _countryCode),
                    onChanged: (val) => _countryCode = val,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSavingLg ? null : _saveLgConfig,
                icon: _isSavingLg
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSavingLg ? 'Validando...' : 'Salvar Conexão LG',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSamsungCard(DeviceManagerProvider provider) {
    final isConnected = provider.isStConnected;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.devices_other, color: Colors.blueAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Samsung SmartThings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isConnected ? 'Conectado e Ativo' : 'Não conectado',
                        style: TextStyle(
                          color: isConnected ? Colors.green : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  IconButton(
                    tooltip: 'Desconectar conta',
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    onPressed: () {
                      provider.disconnectSmartThings();
                      _stTokenController.clear();
                    },
                  ),
              ],
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      const Text('Obter Token SmartThings:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: _openSmartThingsPortal,
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Portal Samsung'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Gere um Personal Access Token com escopos de Devices.'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _stTokenController,
              decoration: const InputDecoration(
                labelText: 'SmartThings Personal Access Token',
                hintText: 'Cole o token da Samsung aqui',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSavingSt ? null : _saveSmartThingsConfig,
                icon: _isSavingSt
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSavingSt ? 'Validando...' : 'Salvar Conexão Samsung',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      elevation: 1,
      color: Theme.of(context).cardColor.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.purpleAccent, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Futuro',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
