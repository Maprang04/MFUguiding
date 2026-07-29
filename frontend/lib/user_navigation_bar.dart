import 'package:flutter/material.dart';

import 'app_theme.dart';

class UserNavigationBar extends StatelessWidget {
  final int currentIndex;
  final String language;
  final VoidCallback onMap;
  final VoidCallback onFavorite;
  final VoidCallback onSettings;

  const UserNavigationBar({
    super.key,
    required this.currentIndex,
    required this.language,
    required this.onMap,
    required this.onFavorite,
    required this.onSettings,
  });

  String _text(String en, String th) => language == 'EN' ? en : th;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 72 + bottomInset,
      padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          _NavigationItem(
            icon: Icons.map_rounded,
            label: _text('Map', 'แผนที่'),
            active: currentIndex == 0,
            onTap: onMap,
          ),
          _NavigationItem(
            icon: Icons.star_rounded,
            label: _text('Favorite', 'รายการโปรด'),
            active: currentIndex == 1,
            onTap: onFavorite,
          ),
          _NavigationItem(
            icon: Icons.settings_outlined,
            label: _text('Settings', 'ตั้งค่า'),
            active: currentIndex == 2,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : const Color(0xFFD7AEB1);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
