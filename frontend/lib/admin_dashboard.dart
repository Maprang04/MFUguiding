import 'package:flutter/material.dart';

import 'admin_map_api.dart';
import 'admin_map_data.dart';
import 'admin_notification.dart';
import 'admin_page_chrome.dart';
import 'admin_setting.dart';
import 'app_theme.dart';
import 'mobile_content_api.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _mapApi = AdminMapApi();
  final _contentApi = MobileContentApi();
  bool _isEnglish = true;
  bool _loading = true;
  String? _error;
  int _rooms = 0, _accessPoints = 0, _zones = 0, _openReportCount = 0;

  String t(String en, String th) => _isEnglish ? en : th;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _mapApi.list('destinations'),
        _mapApi.list('access-points'),
        _mapApi.list('zones'),
        _contentApi.adminReports(),
      ]);
      final reports = results[3];
      if (!mounted) return;
      setState(() {
        _rooms = results[0].length;
        _accessPoints = results[1].length;
        _zones = results[2].length;
        _openReportCount = reports.where((item) {
          final status = item['status']?.toString().toLowerCase();
          return status != 'resolved' && status != 'rejected';
        }).length;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openMapData() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminMapDataPage()),
  );

  void _openReports() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminNotificationPage()),
  );

  @override
  void dispose() {
    _mapApi.close();
    _contentApi.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          AdminPageHeader(
            title: t('Dashboard', 'แดชบอร์ด'),
            language: _isEnglish ? 'EN' : 'TH',
            onLanguageTap: () => setState(() => _isEnglish = !_isEnglish),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadSummary,
              color: AppColors.burgundy,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                children: [
                  const SizedBox(height: 10),
                  if (_loading)
                    const LinearProgressIndicator(
                      color: AppColors.burgundy,
                      backgroundColor: AppColors.redSoft,
                    ),
                  if (_error != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.redSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.burgundy,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t(
                                'Some data could not be loaded.',
                                'ไม่สามารถโหลดข้อมูลบางส่วนได้',
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _loadSummary,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.18,
                    children: [
                      _SummaryCard(
                        label: t('Rooms', 'ห้อง'),
                        value: _rooms,
                        icon: Icons.meeting_room_outlined,
                        color: AppColors.burgundy,
                      ),
                      _SummaryCard(
                        label: t('Access points', 'จุดกระจายสัญญาณ'),
                        value: _accessPoints,
                        icon: Icons.wifi_rounded,
                        color: const Color(0xFF2563EB),
                      ),
                      _SummaryCard(
                        label: t('Navigation zones', 'โซนนำทาง'),
                        value: _zones,
                        icon: Icons.grid_view_rounded,
                        color: const Color(0xFF7C3AED),
                      ),
                      _SummaryCard(
                        label: t('Open reports', 'รายงานที่รอดำเนินการ'),
                        value: _openReportCount,
                        icon: Icons.report_problem_outlined,
                        color: const Color(0xFFD97706),
                        onTap: _openReports,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    t('Quick actions', 'เมนูด่วน'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _ActionTile(
                    icon: Icons.map_outlined,
                    title: t('Manage map data', 'จัดการข้อมูลแผนที่'),
                    subtitle: t(
                      'Rooms, access points, zones and floors',
                      'ห้อง จุดกระจายสัญญาณ โซน และชั้น',
                    ),
                    onTap: _openMapData,
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.notifications_active_outlined,
                    title: t('Review user reports', 'ตรวจสอบรายงานจากผู้ใช้'),
                    subtitle: t(
                      'Review issues and update their status',
                      'ตรวจสอบปัญหาและอัปเดตสถานะ',
                    ),
                    onTap: _openReports,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AdminNavigationBar(
        currentIndex: 0,
        isEnglish: _isEnglish,
        onTap: (index) {
          if (index == 1) _openReports();
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminSettingPage()),
            );
          }
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.redSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.burgundy),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}
