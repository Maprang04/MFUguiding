import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'admin_notification.dart';
import 'admin_page_chrome.dart';
import 'admin_setting.dart';
import 'map_favorite.dart';
import 'map_screen.dart';
import 'map_setting.dart';
import 'user_navigation_bar.dart';

class UserAppShell extends StatefulWidget {
  const UserAppShell({super.key});

  @override
  State<UserAppShell> createState() => _UserAppShellState();
}

class _UserAppShellState extends State<UserAppShell> {
  int _index = 0;
  String _language = 'EN';
  bool _navigationActive = false;
  String? _requestedDestinationId;
  int _destinationSelectionRevision = 0;

  void _setLanguage(String value) {
    if (_language != value) setState(() => _language = value);
  }

  void _selectFavoriteDestination(String destinationId) {
    setState(() {
      _requestedDestinationId = destinationId;
      _destinationSelectionRevision++;
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          MapScreen(
            embedded: true,
            currentLanguage: _language,
            onLanguageChanged: _setLanguage,
            onNavigationModeChanged: (active) {
              setState(() => _navigationActive = active);
            },
            requestedDestinationId: _requestedDestinationId,
            destinationSelectionRevision: _destinationSelectionRevision,
          ),
          MapFavoritePage(
            embedded: true,
            currentLanguage: _language,
            onLanguageChanged: _setLanguage,
            onDestinationSelected: _selectFavoriteDestination,
          ),
          MapSettingPage(
            embedded: true,
            currentLanguage: _language,
            onLanguageChanged: _setLanguage,
          ),
        ],
      ),
      bottomNavigationBar: _navigationActive ? null : UserNavigationBar(
        currentIndex: _index,
        language: _language,
        onMap: () => setState(() => _index = 0),
        onFavorite: () => setState(() => _index = 1),
        onSettings: () => setState(() => _index = 2),
      ),
    );
  }
}

class AdminAppShell extends StatefulWidget {
  const AdminAppShell({super.key});

  @override
  State<AdminAppShell> createState() => _AdminAppShellState();
}

class _AdminAppShellState extends State<AdminAppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          AdminDashboardPage(embedded: true),
          AdminNotificationPage(embedded: true),
          AdminSettingPage(embedded: true),
        ],
      ),
      bottomNavigationBar: AdminNavigationBar(
        currentIndex: _index,
        isEnglish: true,
        onTap: (index) => setState(() => _index = index),
      ),
    );
  }
}
