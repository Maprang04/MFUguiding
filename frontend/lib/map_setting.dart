import 'package:flutter/material.dart';
import 'package:mfuguide/app_theme.dart';
import 'package:mfuguide/app_session.dart';
import 'package:mfuguide/map_favorite.dart';
import 'package:mfuguide/map_report.dart';
import 'package:mfuguide/map_screen.dart';
import 'package:mfuguide/user_navigation_bar.dart';
import 'package:mfuguide/session_manager.dart';

class MapSettingPage extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;
  final bool embedded;

  const MapSettingPage({
    super.key,
    this.currentLanguage = 'EN',
    this.onLanguageChanged,
    this.embedded = false,
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

  @override
  void didUpdateWidget(covariant MapSettingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLanguage != widget.currentLanguage) {
      _language = widget.currentLanguage;
    }
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Sign out', 'ออกจากระบบ')),
        content: Text(
          t('Do you want to sign out?', 'คุณต้องการออกจากระบบหรือไม่?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Cancel', 'ยกเลิก')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Sign out', 'ออกจากระบบ')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SessionManager.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

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
                        child: Center(
                          child: Text(
                            (AppSession.email?.isNotEmpty ?? false)
                                ? AppSession.email![0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Color(0xFF8B0000),
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          AppSession.email ?? t('User', 'ผู้ใช้งาน'),
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
                    icon: Icons.report_problem_outlined,
                    label: t('Report a problem', 'รายงานปัญหา'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MapReportPage(currentLanguage: _language),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionItem(
                    icon: Icons.logout_rounded,
                    label: t('Sign out', 'ออกจากระบบ'),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.embedded ? null : _buildBottomBar(context),
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
