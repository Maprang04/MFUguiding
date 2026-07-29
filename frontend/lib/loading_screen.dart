import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_theme.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    await Future.delayed(const Duration(seconds: 2));
    var connected = false;
    try {
      if (kIsWeb) {
        final response = await http
            .get(Uri.parse('https://cloudflare.com/cdn-cgi/trace'))
            .timeout(const Duration(seconds: 4));
        connected = response.statusCode == 200;
      } else {
        final result = await InternetAddress.lookup(
          'example.com',
        ).timeout(const Duration(seconds: 4));
        connected = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      }
    } catch (_) {
      connected = false;
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, connected ? '/map' : '/fail');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9C5C5),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.16,
            child: Image.asset(
              'assets/welcome-background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          const ColoredBox(color: Color(0x77F3DADA)),
          SafeArea(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _LocationPin(),
                    const SizedBox(height: 24),
                    const Text(
                      'MFU',
                      style: TextStyle(
                        color: AppColors.burgundy,
                        fontSize: 33,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 11),
                    const Text(
                      'SmartGuide',
                      style: TextStyle(
                        color: AppColors.burgundy,
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 27),
                    Text(
                      'Getting Current Location...',
                      style: TextStyle(
                        color: Colors.grey.shade900,
                        fontSize: 16,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPin extends StatelessWidget {
  const _LocationPin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 118,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: 60,
              height: 13,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Icon(
            Icons.location_on_rounded,
            color: Color(0xFFFF3D32),
            size: 112,
            shadows: [
              Shadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 5),
              ),
            ],
          ),
          const Positioned(
            top: 24,
            child: CircleAvatar(radius: 14, backgroundColor: Color(0xFFD92222)),
          ),
        ],
      ),
    );
  }
}
