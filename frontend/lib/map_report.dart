import 'package:flutter/material.dart';
import 'package:mfuguide/map_favorite.dart';
import 'package:mfuguide/map_screen.dart';
import 'package:mfuguide/map_setting.dart';
import 'package:mfuguide/mobile_content_api.dart';
import 'package:mfuguide/user_navigation_bar.dart';
import 'package:mfuguide/user_page_header.dart';

class MapReportPage extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;
  final String? navigationSessionId;
  final Map<String, dynamic>? estimatedPosition;
  final String? initialLocation;

  const MapReportPage({
    super.key,
    this.currentLanguage = 'EN',
    this.onLanguageChanged,
    this.navigationSessionId,
    this.estimatedPosition,
    this.initialLocation,
  });

  @override
  State<MapReportPage> createState() => _MapReportPageState();
}

class _MapReportPageState extends State<MapReportPage> {
  final Color _burgundy = const Color(0xFF8B0000);

  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late String _language;
  final MobileContentApi _contentApi = MobileContentApi();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _language = widget.currentLanguage;
    _locationController.text = widget.initialLocation ?? '';
  }

  void _toggleLanguage() {
    setState(() => _language = _language == 'EN' ? 'TH' : 'EN');
    widget.onLanguageChanged?.call(_language);
  }

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

  Future<void> _handleSubmit() async {
    if (_typeController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('Complete all fields.', 'กรอกข้อมูลให้ครบทุกช่อง')),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _contentApi.submitReport(
        type: _typeController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        navigationSessionId: widget.navigationSessionId,
        estimatedPosition: widget.estimatedPosition,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('Report Submitted Successfully', 'รายงานสำเร็จเรียบร้อย'),
        ),
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
    _contentApi.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
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
                      t(
                        'Fill in the details below.',
                        'กรุณากรอกข้อมูลด้านล่าง',
                      ),
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
                      horizontal: 18,
                      vertical: 22,
                    ),
                    child: Column(
                      children: [
                        _buildInputField(
                          label: t('Barrier Type', 'ประเภทสิ่งกีดขวาง'),
                          hint: t(
                            'Enter barrier type',
                            'ระบุประเภทสิ่งกีดขวาง',
                          ),
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
                                    vertical: 16,
                                  ),
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
                                onPressed: _submitting ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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
            builder: (_) => MapSettingPage(
              currentLanguage: _language,
              onLanguageChanged: widget.onLanguageChanged,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return UserPageHeader(
      title: t('Report Barrier', 'รายงานสิ่งกีดขวาง'),
      subtitle: t(
        'Help keep routes accessible',
        'ช่วยให้เส้นทางใช้งานได้สะดวก',
      ),
      language: _language,
      onBack: () => Navigator.pop(context),
      onLanguageTap: _toggleLanguage,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
}
