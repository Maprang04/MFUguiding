import 'package:flutter/material.dart';
import 'package:mfuguide/app_theme.dart';
import 'package:mfuguide/map_favorite.dart';
import 'package:mfuguide/map_screen.dart';
import 'package:mfuguide/map_setting.dart';
import 'package:mfuguide/user_navigation_bar.dart';
import 'package:mfuguide/user_page_header.dart';

class MapSavePage extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;
  final String currentLocation;

  const MapSavePage({
    super.key,
    this.currentLanguage = 'EN',
    this.onLanguageChanged,
    this.currentLocation = 'Room 301 , AS',
  });

  @override
  State<MapSavePage> createState() => _MapSavePageState();
}

class _MapSavePageState extends State<MapSavePage> {
  final Color _burgundy = AppColors.burgundy;
  String _selectedCategory = 'Home';
  late String _language;

  @override
  void initState() {
    super.initState();
    _language = widget.currentLanguage;
  }

  String t(String en, String th) {
    return _language == 'EN' ? en : th;
  }

  void _toggleLanguage() {
    setState(() {
      _language = _language == 'EN' ? 'TH' : 'EN';
    });
    if (widget.onLanguageChanged != null) {
      widget.onLanguageChanged!(_language);
    }
  }

  void _saveAddress() {
    final parts = widget.currentLocation.split(',');
    final room = parts.isNotEmpty ? parts[0].trim() : widget.currentLocation;
    final building = parts.length > 1 ? parts[1].trim() : '';

    final newFavorite = {
      'room': room,
      'tag': _selectedCategory,
      'building': building,
    };

    MapFavoritePage.favoriteList.add(newFavorite);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('Saved Successfully', 'บันทึกสำเร็จ')),
        backgroundColor: _burgundy,
      ),
    );

    Navigator.pop(context, newFavorite);
  }

  Widget _buildCategoryChip(String label, IconData icon) {
    final bool selected = _selectedCategory == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? Colors.white : Colors.white54),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? _burgundy : Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _burgundy : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          UserPageHeader(
            title: t('Save Location', 'บันทึกตำแหน่ง'),
            subtitle: widget.currentLocation,
            language: _language,
            onBack: () => Navigator.pop(context),
            onLanguageTap: _toggleLanguage,
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Text(
                              'MAP PLAN',
                              style: TextStyle(
                                color: Colors.black26,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 80,
                          right: 80,
                          child: Icon(
                            Icons.location_on,
                            size: 52,
                            color: Color(0xFFD71920),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _burgundy,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Select Location', 'เลือกตำแหน่ง'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  t('Your Location', 'ตำแหน่งของคุณ'),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white24, width: 1),
                    ),
                  ),
                  child: Text(
                    widget.currentLocation,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  t('Save As', 'บันทึกเป็น'),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildCategoryChip('Home', Icons.home)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCategoryChip('Study', Icons.school)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryChip('Others', Icons.location_on),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Container()),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      t('Save Address', 'บันทึกที่อยู่'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: UserNavigationBar(
        currentIndex: 0,
        language: _language,
        onMap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        ),
        onFavorite: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapFavoritePage()),
        ),
        onSettings: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MapSettingPage(currentLanguage: _language),
          ),
        ),
      ),
    );
  }
}
