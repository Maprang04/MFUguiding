import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'map_setting.dart';
import 'mobile_content_api.dart';
import 'user_navigation_bar.dart';

class MapFavoritePage extends StatefulWidget {
  const MapFavoritePage({super.key});

  @override
  State<MapFavoritePage> createState() => _MapFavoritePageState();
}

class _MapFavoritePageState extends State<MapFavoritePage> {
  String _language = 'EN';
  final MobileContentApi _contentApi = MobileContentApi();
  List<Map<String, dynamic>> _favorites = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _contentApi.favorites();
      if (mounted) setState(() => _favorites = items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(String destinationId) async {
    try {
      await _contentApi.removeFavorite(destinationId);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  void dispose() {
    _contentApi.close();
    super.dispose();
  }

  String t(String en, String th) => _language == 'EN' ? en : th;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  )
                : _favorites.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _favorites.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) =>
                          _buildFavoriteCard(_favorites[index]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: UserNavigationBar(
        currentIndex: 1,
        language: _language,
        onMap: () => Navigator.pop(context),
        onFavorite: () {},
        onSettings: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MapSettingPage(currentLanguage: _language),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 14,
        20,
        22,
      ),
      decoration: const BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Favorite places', 'สถานที่โปรด'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t('Your saved destinations', 'จุดหมายที่คุณบันทึกไว้'),
                  style: const TextStyle(
                    color: Color(0xFFE4C3C6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              setState(() => _language = _language == 'EN' ? 'TH' : 'EN');
            },
            borderRadius: BorderRadius.circular(99),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: AppColors.redSoft,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.star_outline_rounded,
                size: 50,
                color: AppColors.burgundy,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t('No saved places yet', 'ยังไม่มีสถานที่ที่บันทึกไว้'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'Save a room from the map to find it faster next time.',
                'บันทึกห้องจากหน้าแผนที่เพื่อค้นหาได้เร็วขึ้น',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.redSoft,
              borderRadius: BorderRadius.circular(16),
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
                  item['label']?.toString() ?? '',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['floor_id'] ?? ''} • ${item['tag'] ?? ''}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t('Remove favorite', 'ลบออกจากรายการโปรด'),
            onPressed: () => _remove(item['destination_id'].toString()),
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.burgundy,
          ),
        ],
      ),
    );
  }
}
