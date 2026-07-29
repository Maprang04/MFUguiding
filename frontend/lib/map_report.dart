import 'package:flutter/material.dart';
import 'package:mfuguide/map_favorite.dart';
import 'package:mfuguide/map_screen.dart';
import 'package:mfuguide/map_setting.dart';

class MapReportPage extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;

  const MapReportPage({
    super.key,
    this.currentLanguage = 'EN',
    this.onLanguageChanged,
  });

  @override
  State<MapReportPage> createState() => _MapReportPageState();
}

class _MapReportPageState extends State<MapReportPage> {
  final Color _burgundy = const Color(0xFF8B0000);

  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String get _language => widget.currentLanguage;

  String t(String en, String th) {
    return _language == 'EN' ? en : th;
  }

  void _handleCancel() {
    if (_typeController.text.isNotEmpty ||
        _locationController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty) {
      _typeController.clear();
      _locationController.clear();
      _descriptionController.clear();
      return;
    }
    Navigator.pop(context);
  }

  void _handleSubmit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('Report Submitted Successfully', 'รายงานสำเร็จเรียบร้อย')),
        backgroundColor: _burgundy,
        duration: const Duration(milliseconds: 1200),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _typeController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t('Fill in the details below.', 'กรุณากรอกข้อมูลด้านล่าง'),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E3E6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 22),
                      child: Column(
                        children: [
                          _buildInputField(
                            label: t('Barrier Type', 'ประเภทสิ่งกีดขวาง'),
                            hint: t('Enter barrier type', 'ระบุประเภทสิ่งกีดขวาง'),
                            controller: _typeController,
                          ),
                          const SizedBox(height: 14),
                          _buildInputField(
                            label: t('Location', 'ตำแหน่ง'),
                            hint: t('Enter location', 'ระบุตำแหน่ง'),
                            controller: _locationController,
                          ),
                          const SizedBox(height: 14),
                          _buildInputField(
                            label: t('Description', 'รายละเอียด'),
                            hint: t('Enter description', 'ระบุรายละเอียด'),
                            controller: _descriptionController,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _handleCancel,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _burgundy,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: Text(
                                    t('Cancel', 'ยกเลิก'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _handleSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: Text(
                                    t('Submit', 'ส่ง'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
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
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _burgundy,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xFF8B0000),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              t('Report Barrier', 'รายงานสิ่งกีดขวาง'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _burgundy),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: _burgundy,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBottomNavItem(
            icon: Icons.map,
            label: t('Map', 'แผนที่'),
            active: false,
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            ),
          ),
          _buildBottomNavItem(
            icon: Icons.star,
            label: t('Favorite', 'โปรด'),
            active: false,
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MapFavoritePage()),
            ),
          ),
          _buildBottomNavItem(
            icon: Icons.settings,
            label: t('Setting', 'ตั้งค่า'),
            active: false,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MapSettingPage(
                  currentLanguage: widget.currentLanguage,
                  onLanguageChanged: (lang) {
                    if (widget.onLanguageChanged != null) {
                      widget.onLanguageChanged!(lang);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? Colors.white : Colors.white70;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}