import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'admin_notification.dart';
import 'admin_page_chrome.dart';
import 'admin_setting.dart';

enum DetailLanguage { english, thai }

class AdminDetailPage extends StatefulWidget {
  const AdminDetailPage({super.key});

  @override
  State<AdminDetailPage> createState() => _AdminDetailPageState();
}

class _AdminDetailPageState extends State<AdminDetailPage> {
  DetailLanguage _language = DetailLanguage.english;

  bool get _isEnglish => _language == DetailLanguage.english;

  // แก้ไขภาษาไทยต่างดาวทั้งหมดให้ถูกต้อง
  String get _headerTitle => _isEnglish ? 'Notification' : 'การแจ้งเตือน';
  String get _bookingDetail =>
      _isEnglish ? 'Booking detail' : 'รายละเอียดการรายงาน';
  String get _descriptionTitle => _isEnglish ? 'Description' : 'คำอธิบาย';
  String get _barrierTypeLabel =>
      _isEnglish ? 'Barrier Type' : 'ประเภทสิ่งกีดขวาง';
  String get _bookingTimeLabel => _isEnglish ? 'Booking time' : 'เวลา';
  String get _bookingDateLabel => _isEnglish ? 'Booking date' : 'วันที่';
  String get _bookedByLabel => _isEnglish ? 'Booked by' : 'ผู้แจ้ง';
  String get _locationLabel => _isEnglish ? 'Location' : 'สถานที่';
  String get _descriptionText => _isEnglish
      ? 'Temporary barrier blocking the entrance.'
      : 'สิ่งกีดขวางชั่วคราวปิดทางเข้า';

  void _toggleLanguage() {
    setState(() {
      _language = _isEnglish ? DetailLanguage.thai : DetailLanguage.english;
    });
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

  void _navigateToSetting() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminSettingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          AdminPageHeader(
            title: _headerTitle,
            language: _isEnglish ? 'EN' : 'TH',
            onLanguageTap: _toggleLanguage,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailCard(
                    title: _bookingDetail,
                    items: [
                      _DetailRowData(
                        label: _barrierTypeLabel,
                        value: 'Broken Elevator',
                      ),
                      _DetailRowData(
                        label: _bookingTimeLabel,
                        value: '08:00 am',
                      ),
                      _DetailRowData(
                        label: _bookingDateLabel,
                        value: '12/12/2026',
                      ),
                      _DetailRowData(
                        label: _bookedByLabel,
                        value: 'Asia Thongkong',
                      ),
                      _DetailRowData(
                        label: _locationLabel,
                        value: 'Room 301, AS',
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _descriptionTitle,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _descriptionText,
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AdminNavigationBar(
        currentIndex: 1,
        isEnglish: _isEnglish,
        onTap: (index) {
          if (index == 0) {
            _navigateToDashboard();
          } else if (index == 1) {
            _navigateToNotification();
          } else if (index == 2) {
            _navigateToSetting();
          }
        },
      ),
    );
  }
}

// Legacy header retained for reference while the shared chrome is in use.
// ignore: unused_element
class _DetailHeader extends StatelessWidget {
  final String title;
  final String languageCode;
  final VoidCallback onLanguageTap;

  const _DetailHeader({
    required this.title,
    required this.languageCode,
    required this.onLanguageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF8B0000),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: onLanguageTap,
            child: Container(
              width: 38,
              height: 38,
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
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<_DetailRowData> items;

  const _DetailCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F9),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _DetailRow(data: item)),
        ],
      ),
    );
  }
}

class _DetailRowData {
  final String label;
  final String value;

  _DetailRowData({required this.label, required this.value});
}

class _DetailRow extends StatelessWidget {
  final _DetailRowData data;

  const _DetailRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            data.label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            data.value,
            style: const TextStyle(
              color: Color(0xFF1E3A8A),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
