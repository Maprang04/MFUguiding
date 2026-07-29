import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'admin_map_api.dart';
import 'admin_notification.dart';
import 'admin_page_chrome.dart';
import 'admin_setting.dart';
import 'app_theme.dart';
import 'navigation_api.dart';
import 'session_manager.dart';

class AdminMapDataPage extends StatefulWidget {
  const AdminMapDataPage({super.key});

  @override
  State<AdminMapDataPage> createState() => _AdminMapDataPageState();
}

class _AdminMapDataPageState extends State<AdminMapDataPage> {
  static const _resources = {
    'destinations': 'Rooms',
    'access-points': 'Access Points',
    'zones': 'Zones',
    'floors': 'Floors',
  };

  final _api = AdminMapApi();
  String _resource = 'destinations';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.list(_resource);
      if (mounted) setState(() => _items = items);
    } on NavigationApiException catch (error) {
      if (await _redirectIfExpired(error)) return;
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _redirectIfExpired(NavigationApiException error) async {
    if (error.statusCode != 401) return false;
    await SessionManager.clear();
    if (!mounted) return true;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    return true;
  }

  String _id(Map<String, dynamic> item) => item['id'].toString();

  String _subtitle(Map<String, dynamic> item) {
    final position = item['position'] as Map?;
    final floor = item['floorId']?.toString();
    final zone = item['zoneId']?.toString();
    final parts = <String>[];
    if (floor != null) parts.add(floor);
    if (zone != null) parts.add(zone);
    if (position != null) parts.add('(${position['x']}, ${position['y']})');
    return parts.join(' • ');
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MapItemDialog(resource: _resource, existing: existing),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await _api.create(_resource, result);
      } else {
        await _api.update(_resource, _id(existing), result);
      }
      await _load();
    } on NavigationApiException catch (error) {
      if (await _redirectIfExpired(error)) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _deactivate(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable map item?'),
        content: Text('${_id(item)} will no longer appear in the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deactivate(_resource, _id(item));
      await _load();
    } on NavigationApiException catch (error) {
      if (await _redirectIfExpired(error)) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _navigate(int index) {
    final page = switch (index) {
      1 => const AdminNotificationPage(),
      2 => const AdminSettingPage(),
      _ => const AdminDashboardPage(),
    };
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F4),
      body: Column(
        children: [
          AdminPageHeader(
            title: 'Map Data',
            language: 'EN',
            onLanguageTap: () {},
            onBack: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: DropdownButtonFormField<String>(
              initialValue: _resource,
              decoration: const InputDecoration(
                labelText: 'Data type',
                prefixIcon: Icon(Icons.layers_outlined),
              ),
              items: _resources.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                _resource = value;
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final item = _items[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.redSoft,
                              foregroundColor: AppColors.burgundy,
                              child: Icon(
                                _resource == 'access-points'
                                    ? Icons.wifi_rounded
                                    : _resource == 'destinations'
                                    ? Icons.meeting_room_outlined
                                    : _resource == 'zones'
                                    ? Icons.grid_view_rounded
                                    : Icons.layers_rounded,
                              ),
                            ),
                            title: Text(
                              item['label']?.toString() ?? _id(item),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(_subtitle(item)),
                            onTap: () => _edit(item),
                            trailing: IconButton(
                              tooltip: 'Disable',
                              onPressed: () => _deactivate(item),
                              icon: const Icon(Icons.block_rounded),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: AppColors.burgundy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      bottomNavigationBar: AdminNavigationBar(
        currentIndex: 0,
        isEnglish: true,
        onTap: _navigate,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _MapItemDialog extends StatefulWidget {
  final String resource;
  final Map<String, dynamic>? existing;

  const _MapItemDialog({required this.resource, this.existing});

  @override
  State<_MapItemDialog> createState() => _MapItemDialogState();
}

class _MapItemDialogState extends State<_MapItemDialog> {
  late final TextEditingController id;
  late final TextEditingController label;
  late final TextEditingController floor;
  late final TextEditingController zone;
  late final TextEditingController x;
  late final TextEditingController y;

  @override
  void initState() {
    super.initState();
    final item = widget.existing ?? {};
    final position = item['position'] as Map?;
    id = TextEditingController(text: item['id']?.toString() ?? '');
    label = TextEditingController(
      text: item['label']?.toString() ?? item['id']?.toString() ?? '',
    );
    floor = TextEditingController(
      text: item['floorId']?.toString() ?? 'floor-1',
    );
    zone = TextEditingController(text: item['zoneId']?.toString() ?? '');
    x = TextEditingController(text: position?['x']?.toString() ?? '');
    y = TextEditingController(text: position?['y']?.toString() ?? '');
  }

  Map<String, dynamic>? _payload() {
    final px = double.tryParse(x.text);
    final py = double.tryParse(y.text);
    if (id.text.trim().isEmpty || label.text.trim().isEmpty) return null;
    switch (widget.resource) {
      case 'destinations':
        if (px == null || py == null) return null;
        return {
          'destinationId': id.text.trim(),
          'floorId': floor.text.trim(),
          'label': label.text.trim(),
          'nameEn': label.text.trim(),
          'position': {'x': px, 'y': py},
          'active': true,
        };
      case 'access-points':
        if (px == null || py == null || zone.text.trim().isEmpty) return null;
        final point = {'x': px, 'y': py};
        return {
          'apId': id.text.trim(),
          'floorId': floor.text.trim(),
          'zoneId': zone.text.trim(),
          'position': point,
          'anchors':
              widget.existing?['anchors'] ??
              {'near': point, 'medium': point, 'edge': point},
          'active': true,
        };
      case 'zones':
        return {
          'zoneId': id.text.trim(),
          'floorId': floor.text.trim(),
          'label': label.text.trim(),
          'active': true,
        };
      default:
        return {
          'floorId': id.text.trim(),
          'buildingId': 'mfu-building',
          'label': label.text.trim(),
          'imageAsset': 'floorplan_clean.png',
          'imageWidth': 2048,
          'imageHeight': 1095,
          'cellSizeMeters': 0.25,
          'xRange': [0, 23],
          'yRange': [0, 12],
          'transform': {
            'a': 81.75973015049297,
            'b': 83.54800207576601,
            'c': -91.0665258711722,
            'd': 1092.7911826821548,
          },
          'active': true,
        };
    }
  }

  @override
  void dispose() {
    id.dispose();
    label.dispose();
    floor.dispose();
    zone.dispose();
    x.dispose();
    y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsPosition = const [
      'destinations',
      'access-points',
    ].contains(widget.resource);
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add map item' : 'Edit map item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: id,
              enabled: widget.existing == null,
              decoration: const InputDecoration(labelText: 'ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            if (widget.resource != 'floors') ...[
              const SizedBox(height: 10),
              TextField(
                controller: floor,
                decoration: const InputDecoration(labelText: 'Floor ID'),
              ),
            ],
            if (widget.resource == 'access-points') ...[
              const SizedBox(height: 10),
              TextField(
                controller: zone,
                decoration: const InputDecoration(labelText: 'Zone ID'),
              ),
            ],
            if (needsPosition) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: x,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'X meters'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: y,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Y meters'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final payload = _payload();
            if (payload == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Complete all required fields.')),
              );
              return;
            }
            Navigator.pop(context, payload);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
