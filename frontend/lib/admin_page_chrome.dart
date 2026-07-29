import 'package:flutter/material.dart';

import 'app_theme.dart';

class AdminPageHeader extends StatelessWidget {
  final String title;
  final String language;
  final VoidCallback onLanguageTap;
  final VoidCallback? onBack;

  const AdminPageHeader({
    super.key,
    required this.title,
    required this.language,
    required this.onLanguageTap,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        18,
      ),
      decoration: const BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          _HeaderButton(
            tooltip: onBack == null ? 'Administrator' : 'Back',
            onTap: onBack,
            child: Icon(
              onBack == null
                  ? Icons.admin_panel_settings_rounded
                  : Icons.arrow_back_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'MFU SmartGuide • Administrator',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFFE4C3C6), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _HeaderButton(
            tooltip: 'Change language',
            onTap: onLanguageTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.language_rounded,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 5),
                Text(
                  language,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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

class _HeaderButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  const _HeaderButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AdminNavigationBar extends StatelessWidget {
  final int currentIndex;
  final bool isEnglish;
  final ValueChanged<int> onTap;

  const AdminNavigationBar({
    super.key,
    required this.currentIndex,
    required this.isEnglish,
    required this.onTap,
  });

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
            icon: Icons.dashboard_rounded,
            label: isEnglish ? 'Dashboard' : 'แดชบอร์ด',
            active: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavigationItem(
            icon: Icons.notifications_rounded,
            label: isEnglish ? 'Notification' : 'แจ้งเตือน',
            active: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavigationItem(
            icon: Icons.settings_outlined,
            label: isEnglish ? 'Settings' : 'ตั้งค่า',
            active: currentIndex == 2,
            onTap: () => onTap(2),
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
