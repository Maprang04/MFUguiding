import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'admin_notification.dart';
import 'admin_setting.dart';

// ฟังก์ชัน main ชั่วคราวสำหรับสั่ง flutter run เข้าหน้านี้โดยตรง
void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AdminMainScreen(),
    ),
  );
}

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  bool _isStarted = false;

  static final List<Widget> _adminPages = <Widget>[
    const AdminDashboardPage(),
    const AdminNotificationPage(),
    const AdminSettingPage(),
  ];

  void _startAdmin() {
    setState(() {
      _isStarted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // โทนสีเดียวกับฝั่ง User เป๊ะๆ
    const Color burgundy = Color(0xFF7B0D0D);

    if (!_isStarted) {
      return Scaffold(
        backgroundColor: burgundy,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo placeholder (ตรงตาม User)
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/mfu-logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.white24,
                          child: const Center(
                            child: Icon(
                              Icons.location_on,
                              size: 80,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Title: MFU (ตรงตาม User)
                  const Text(
                    'MFU',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),

                  // Title: SmartGuide (ตรงตาม User)
                  const Text(
                    'SmartGuide',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // START button (รูปแบบเดียวกับ User แต่กดแล้วเข้า Admin)
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: _startAdmin, // เข้าสู่ระบบ Admin
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'START',
                        style: TextStyle(
                          color: burgundy,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // เมื่อกด START จะเข้าสู่ Admin Dashboard
    return _adminPages[0];
  }
}