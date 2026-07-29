import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'admin_notification.dart';

enum SettingLanguage { english, thai }

class AdminSettingPage extends StatefulWidget {
  const AdminSettingPage({super.key});

  @override
  State<AdminSettingPage> createState() => _AdminSettingPageState();
}

class _AdminSettingPageState extends State<AdminSettingPage> {
  SettingLanguage _language = SettingLanguage.english;

  bool get _isEnglish => _language == SettingLanguage.english;

  // แก้ไขปัญหา Encoding ภาษาไทยให้ถูกต้อง
  String get _profileTitle => _isEnglish ? 'Profile' : 'โปรไฟล์';
  String get _personalInfoLabel => _isEnglish ? 'Personal Info' : 'ข้อมูลส่วนตัว';
  String get _settingLabel => _isEnglish ? 'Setting' : 'ตั้งค่า';
  String get _supportLabel => _isEnglish ? 'Support' : 'สนับสนุน';
  String get _privacyPolicyLabel => _isEnglish ? 'Privacy & Policy' : 'นโยบายความเป็นส่วนตัว';
  String get _signOutLabel => _isEnglish ? 'Sign out' : 'ออกจากระบบ';
  String get _dashboardLabel => _isEnglish ? 'Dashboard' : 'แดชบอร์ด';
  String get _notificationLabel => _isEnglish ? 'Notification' : 'แจ้งเตือน';
  String get _settingNavLabel => _isEnglish ? 'Setting' : 'การตั้งค่า';
  String get _logoutDialogTitle => _isEnglish ? 'Sign out' : 'ออกจากระบบ';
  String get _logoutDialogMessage => _isEnglish ? 'Do you want to sign out?' : 'คุณต้องการออกจากระบบหรือไม่?';
  String get _cancelLabel => _isEnglish ? 'Cancel' : 'ยกเลิก';
  String get _confirmLabel => _isEnglish ? 'Confirm' : 'ตกลง';

  void _toggleLanguage() {
    setState(() {
      _language = _isEnglish ? SettingLanguage.thai : SettingLanguage.english;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_logoutDialogTitle),
        content: Text(_logoutDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_cancelLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showSnackBar(_signOutLabel);
            },
            child: Text(_confirmLabel),
          ),
        ],
      ),
    );
  }

  void _navigateToDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
    );
  }

  void _navigateToNotification() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminNotificationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _ProfileHeader(
            title: _profileTitle,
            languageCode: _isEnglish ? 'EN' : 'TH',
            onLanguageTap: _toggleLanguage,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              children: [
                _SettingMenuItem(
                  icon: Icons.person_outline,
                  iconBackground: const Color(0xFFFFF0E6),
                  iconColor: const Color(0xFFD97706),
                  title: _personalInfoLabel,
                  onTap: () => _showSnackBar(_personalInfoLabel),
                ),
                const SizedBox(height: 12),
                _SettingMenuItem(
                  icon: Icons.settings_outlined,
                  iconBackground: const Color(0xFFFFF0E6),
                  iconColor: const Color(0xFFD97706),
                  title: _settingLabel,
                  onTap: () => _showSnackBar(_settingLabel),
                ),
                const SizedBox(height: 12),
                _SettingMenuItem(
                  icon: Icons.headset_mic_outlined,
                  iconBackground: const Color(0xFFFFF0E6),
                  iconColor: const Color(0xFFD97706),
                  title: _supportLabel,
                  onTap: () => _showSnackBar(_supportLabel),
                ),
                const SizedBox(height: 12),
                _SettingMenuItem(
                  icon: Icons.article_outlined,
                  iconBackground: const Color(0xFFFFF0E6),
                  iconColor: const Color(0xFFD97706),
                  title: _privacyPolicyLabel,
                  onTap: () => _showSnackBar(_privacyPolicyLabel),
                ),
                const SizedBox(height: 12),
                _SettingMenuItem(
                  icon: Icons.logout,
                  iconBackground: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  title: _signOutLabel,
                  onTap: _showLogoutDialog,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        backgroundColor: const Color(0xFF8B0000),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) {
            _navigateToDashboard();
          } else if (index == 1) {
            _navigateToNotification();
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            label: _dashboardLabel,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.mail_outline),
            label: _notificationLabel,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            label: _settingNavLabel,
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String title;
  final String languageCode;
  final VoidCallback onLanguageTap;

  const _ProfileHeader({
    required this.title,
    required this.languageCode,
    required this.onLanguageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF8B0000),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onLanguageTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    languageCode,
                    style: const TextStyle(
                      color: Color(0xFF8B0000),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'PICTURE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8B0000),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      // อัปเดตรหัสนักศึกษา
                      Text(
                        '6631501127',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 6),
                      // อัปเดตชื่อผู้ใช้
                      Text(
                        'Asia Thongkong',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _SettingMenuItem({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}