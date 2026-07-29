import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'map_favorite.dart';
import 'map_save.dart';
import 'map_setting.dart';
import 'map_start.dart';
import 'user_navigation_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _searchController = TextEditingController();
  final List<Map<String, String>> _locations = const [
    {'room': 'Room 301', 'building': 'AS Building', 'distance': '400 m'},
    {'room': 'Room 302', 'building': 'AS Building', 'distance': '350 m'},
  ];

  Map<String, String>? _searchResult;
  bool _searched = false;
  String _selectedLanguage = 'EN';

  String t(String en, String th) => _selectedLanguage == 'EN' ? en : th;

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
    });
  }

  void _openSavePage() {
    final result = _searchResult;
    if (result == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapSavePage(
          currentLanguage: _selectedLanguage,
          currentLocation: '${result['room']}, ${result['building']}',
          onLanguageChanged: (language) {
            setState(() => _selectedLanguage = language);
          },
        ),
      ),
    );
  }

  void _openStartPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapStartPage(
          currentLanguage: _selectedLanguage,
          onLanguageChanged: (language) {
            setState(() => _selectedLanguage = language);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _searchResult;
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
            },
            onSearch: _performSearch,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Stack(
                children: [
                  const Positioned.fill(child: _MapCard()),
                  if (result != null)
                    const Positioned(
                      top: 122,
                      right: 94,
                      child: _DestinationMarker(),
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
  final VoidCallback onSearch;

  const _Header({
    required this.language,
    required this.controller,
    required this.hint,
    required this.onLanguageTap,
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

class _MapCard extends StatelessWidget {
  const _MapCard();

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
          Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.maps_home_work_outlined,
                  size: 46,
                  color: Color(0xFFCBC5C6),
                ),
                SizedBox(height: 10),
                Text(
                  'FLOOR MAP',
                  style: TextStyle(
                    color: Color(0xFFB6B0B1),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
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

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF0ECEC)
      ..strokeWidth = 1;
    for (double x = 22; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 22; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.burgundy,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
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
