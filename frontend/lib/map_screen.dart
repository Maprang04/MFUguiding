import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'map_favorite.dart';
import 'floor_plan_coordinates.dart';
import 'map_save.dart';
import 'map_setting.dart';
import 'map_start.dart';
import 'navigation_api.dart';
import 'user_navigation_bar.dart';

class MapScreen extends StatefulWidget {
  final bool embedded;
  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;
  final ValueChanged<bool>? onNavigationModeChanged;
  final String? requestedDestinationId;
  final int destinationSelectionRevision;

  const MapScreen({
    super.key,
    this.embedded = false,
    this.currentLanguage = 'EN',
    this.onLanguageChanged,
    this.onNavigationModeChanged,
    this.requestedDestinationId,
    this.destinationSelectionRevision = 0,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _searchController = TextEditingController();
  final NavigationApi _navigationApi = NavigationApi();
  List<Map<String, String>> _locations = const [
    {
      'id': 'room_1',
      'room': 'Room 1 entrance',
      'building': 'Floor 1',
      'distance': '',
      'x': '15',
      'y': '5',
    },
    {
      'id': 'room_2',
      'room': 'Room 2 entrance',
      'building': 'Floor 1',
      'distance': '',
      'x': '15',
      'y': '9',
    },
    {
      'id': 'room_3',
      'room': 'Room 3 entrance',
      'building': 'Floor 1',
      'distance': '',
      'x': '11',
      'y': '5',
    },
  ];

  Map<String, String>? _searchResult;
  List<Map<String, String>> _suggestions = const [];
  bool _searched = false;
  bool _navigationMode = false;
  String _selectedLanguage = 'EN';

  String t(String en, String th) => _selectedLanguage == 'EN' ? en : th;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.currentLanguage;
    _loadDestinations();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLanguage != widget.currentLanguage) {
      _selectedLanguage = widget.currentLanguage;
    }
    if (oldWidget.destinationSelectionRevision !=
        widget.destinationSelectionRevision) {
      _selectDestinationById(widget.requestedDestinationId);
    }
  }

  void _selectDestinationById(String? destinationId) {
    if (destinationId == null) return;
    for (final location in _locations) {
      if (location['id'] == destinationId) {
        _searchController.text = location['room'] ?? '';
        setState(() {
          _searchResult = location;
          _searched = true;
          _suggestions = const [];
        });
        return;
      }
    }
  }

  Future<void> _loadDestinations() async {
    try {
      final destinations = await _navigationApi.destinations();
      if (!mounted || destinations.isEmpty) return;
      setState(() {
        _locations = destinations.map((destination) {
          return {
            'id': destination['id'].toString(),
            'room': destination['label'].toString(),
            'building': destination['floorId']?.toString() ?? 'Floor 1',
            'distance': '',
            'x': (destination['position'] as Map?)?['x']?.toString() ?? '',
            'y': (destination['position'] as Map?)?['y']?.toString() ?? '',
          };
        }).toList();
      });
      _selectDestinationById(widget.requestedDestinationId);
    } on NavigationApiException {
      // Keep the bundled destinations so the search UI remains usable while
      // the local backend is starting.
    }
  }

  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _searched = false;
        _searchResult = null;
      });
      return;
    }
    final normalized = query.replaceAll('room ', '');
    final matches = _locations.where((location) {
      final room = location['room']!.toLowerCase();
      final building = location['building']!.toLowerCase();
      return room.contains(query) ||
          room.replaceAll('room ', '') == normalized ||
          building.contains(query);
    });
    setState(() {
      _searched = true;
      _searchResult = matches.isEmpty ? null : matches.first;
      _suggestions = const [];
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onSearchChanged(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _suggestions = const [];
        _searched = false;
        _searchResult = null;
      });
      return;
    }

    final normalized = query.replaceAll(RegExp(r'^room\s*'), '');
    final matches = _locations
        .where((location) {
          final room = (location['room'] ?? '').toLowerCase();
          final building = (location['building'] ?? '').toLowerCase();
          final id = (location['id'] ?? '').toLowerCase().replaceAll('_', ' ');
          return room.contains(query) ||
              room.replaceAll(RegExp(r'^room\s*'), '').contains(normalized) ||
              building.contains(query) ||
              id.contains(query);
        })
        .take(5)
        .toList();

    setState(() {
      _suggestions = matches;
      _searched = false;
      _searchResult = null;
    });
  }

  void _selectSuggestion(Map<String, String> location) {
    _searchController.text = location['room'] ?? '';
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    setState(() {
      _searchResult = location;
      _searched = true;
      _suggestions = const [];
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _openSavePage() {
    final result = _searchResult;
    if (result == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapSavePage(
          currentLanguage: _selectedLanguage,
          destinationId: result['id'] ?? 'room_1',
          currentLocation: '${result['room']}, ${result['building']}',
          onLanguageChanged: (language) {
            setState(() => _selectedLanguage = language);
          },
        ),
      ),
    );
  }

  void _openStartPage() {
    if (_searchResult == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _navigationMode = true);
    widget.onNavigationModeChanged?.call(true);
  }

  void _closeNavigationMode() {
    if (!mounted) return;
    setState(() => _navigationMode = false);
    widget.onNavigationModeChanged?.call(false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _navigationApi.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _searchResult;
    if (_navigationMode && result != null) {
      return MapStartPage(
        currentLanguage: _selectedLanguage,
        destinationId: result['id'] ?? 'room_1',
        destinationLabel: result['room'] ?? 'Room 1 entrance',
        onClose: _closeNavigationMode,
        onLanguageChanged: (language) {
          setState(() => _selectedLanguage = language);
        },
      );
    }
    return Scaffold(
      body: Column(
        children: [
          _Header(
            language: _selectedLanguage,
            controller: _searchController,
            hint: t('Search room number or name', 'ค้นหาหมายเลขหรือชื่อห้อง'),
            onLanguageTap: () {
              setState(() {
                _selectedLanguage = _selectedLanguage == 'EN' ? 'TH' : 'EN';
              });
              widget.onLanguageChanged?.call(_selectedLanguage);
            },
            onChanged: _onSearchChanged,
            onSearch: _performSearch,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _suggestions.isEmpty
                ? const SizedBox.shrink()
                : _SearchSuggestions(
                    key: ValueKey(_searchController.text),
                    items: _suggestions,
                    onSelected: _selectSuggestion,
                    floorLabel: t('Floor', 'ชั้น'),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: result == null
                        ? _MapEmptyCard(
                            title: t(
                              'Choose a destination',
                              'เลือกจุดหมายปลายทาง',
                            ),
                            message: t(
                              'Search for a room to display the indoor map.',
                              'ค้นหาและเลือกห้องเพื่อแสดงแผนที่ภายในอาคาร',
                            ),
                          )
                        : _MapCard(destination: result),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: _MapStatus(
                      error: _searched && result == null,
                      text: _searched && result == null
                          ? t(
                              'Room not found. Try another name.',
                              'ไม่พบห้อง กรุณาลองค้นหาอีกครั้ง',
                            )
                          : result == null
                          ? t(
                              'Search for a room to begin',
                              'ค้นหาห้องเพื่อเริ่มนำทาง',
                            )
                          : t(
                              'Destination found on this floor',
                              'พบจุดหมายบนชั้นนี้แล้ว',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: result == null
                ? const SizedBox.shrink()
                : _LocationSheet(
                    key: ValueKey(result['room']),
                    result: result,
                    saveLabel: t('Save', 'บันทึก'),
                    startLabel: t('Start', 'เริ่มนำทาง'),
                    onSave: _openSavePage,
                    onStart: _openStartPage,
                  ),
          ),
          if (!widget.embedded)
          UserNavigationBar(
            currentIndex: 0,
            language: _selectedLanguage,
            onMap: () {},
            onFavorite: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapFavoritePage()),
            ),
            onSettings: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MapSettingPage(
                  currentLanguage: _selectedLanguage,
                  onLanguageChanged: (language) {
                    setState(() => _selectedLanguage = language);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String language;
  final TextEditingController controller;
  final String hint;
  final VoidCallback onLanguageTap;
  final ValueChanged<String> onChanged;
  final VoidCallback onSearch;

  const _Header({
    required this.language,
    required this.controller,
    required this.hint,
    required this.onLanguageTap,
    required this.onChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 14,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MFU SmartGuide',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Indoor navigation',
                      style: TextStyle(color: Color(0xFFE4C3C6), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Change language',
                child: InkWell(
                  onTap: onLanguageTap,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.language_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          language,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: onSearch,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  final List<Map<String, String>> items;
  final ValueChanged<Map<String, String>> onSelected;
  final String floorLabel;

  const _SearchSuggestions({
    super.key,
    required this.items,
    required this.onSelected,
    required this.floorLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9DFE0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            InkWell(
              onTap: () => onSelected(items[index]),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.redSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.meeting_room_outlined,
                        color: AppColors.burgundy,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[index]['room'] ?? '',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$floorLabel ${items[index]['building'] ?? ''}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.north_west_rounded,
                      color: AppColors.muted,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
            if (index < items.length - 1) const Divider(height: 1, indent: 68),
          ],
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  final Map<String, String>? destination;

  const _MapCard({this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/floorplan_clean.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  CustomPaint(
                    painter: _FloorPlanMarkerPainter(destination: destination),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton.filled(
              tooltip: 'Center map',
              onPressed: () {},
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.burgundy,
              ),
              icon: const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapEmptyCard extends StatelessWidget {
  final String title;
  final String message;

  const _MapEmptyCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 30, 30, 90),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.redSoft,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppColors.burgundy,
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloorPlanMarkerPainter extends CustomPainter {
  final Map<String, String>? destination;

  const _FloorPlanMarkerPainter({required this.destination});

  @override
  void paint(Canvas canvas, Size size) {
    final xMeters = double.tryParse(destination?['x'] ?? '');
    final yMeters = double.tryParse(destination?['y'] ?? '');
    if (xMeters == null || yMeters == null) return;

    final point = FloorPlanCoordinates.metersToCanvas(xMeters, yMeters, size);

    canvas.drawCircle(
      point.translate(0, 4),
      9,
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawCircle(point, 8, Paint()..color = AppColors.burgundy);
    canvas.drawCircle(point, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _FloorPlanMarkerPainter oldDelegate) {
    return oldDelegate.destination != destination;
  }
}

class _MapStatus extends StatelessWidget {
  final bool error;
  final String text;

  const _MapStatus({required this.error, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.burgundy : AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.search_off_rounded : Icons.info_outline_rounded,
            color: color,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationSheet extends StatelessWidget {
  final Map<String, String> result;
  final String saveLabel;
  final String startLabel;
  final VoidCallback onSave;
  final VoidCallback onStart;

  const _LocationSheet({
    super.key,
    required this.result,
    required this.saveLabel,
    required this.startLabel,
    required this.onSave,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.redSoft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.meeting_room_outlined,
                    color: AppColors.burgundy,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result['room']!,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${result['building']} • ${result['distance']}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSave,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      foregroundColor: AppColors.burgundy,
                      side: const BorderSide(color: Color(0xFFE1C7C9)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: const Icon(Icons.bookmark_border_rounded),
                    label: Text(saveLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.success,
                    ),
                    icon: const Icon(Icons.navigation_rounded),
                    label: Text(startLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
