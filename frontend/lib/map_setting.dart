import 'package:flutter/material.dart';
import 'package:mfuguide/app_theme.dart';
import 'package:mfuguide/map_favorite.dart';
import 'package:mfuguide/map_screen.dart';
import 'package:mfuguide/user_navigation_bar.dart';

class MapSettingPage extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;

  const MapSettingPage({
    super.key,
    this.currentLanguage = 'EN',
    this.onLanguageChanged,
  });

  @override
  State<MapSettingPage> createState() => _MapSettingPageState();
}

class _MapSettingPageState extends State<MapSettingPage> {
  String _language = 'EN';
  final Color _burgundy = AppColors.burgundy;

  @override
  void initState() {
    super.initState();
    _language = widget.currentLanguage;
  }

  void _toggleLanguage() {
    setState(() {
      _language = _language == 'EN' ? 'TH' : 'EN';
    });
    if (widget.onLanguageChanged != null) {
      widget.onLanguageChanged!(_language);
    }
  }

  String t(String en, String th) => _language == 'EN' ? en : th;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _burgundy,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 14,
              20,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('Profile', 'โปรไฟล์'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _toggleLanguage,
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.language_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _language,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _burgundy,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.school,
                            size: 36,
                            color: Color(0xFF8B0000),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Mae Fah Luang\nUniversity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  topRight: Radius.circular(0),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildOptionItem(
                    icon: Icons.settings,
                    label: t('Setting', 'ตั้งค่า'),
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _buildOptionItem(
                    icon: Icons.headset_mic,
                    label: t('Support', 'ความช่วยเหลือ'),
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _buildOptionItem(
                    icon: Icons.description,
                    label: t('Privacy & Policy', 'นโยบายความเป็นส่วนตัว'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9D9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFFBF6A28)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF1F2E43),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return UserNavigationBar(
      currentIndex: 2,
      language: _language,
      onMap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MapScreen()),
      ),
      onFavorite: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MapFavoritePage()),
      ),
      onSettings: () {},
    );
  }
}
