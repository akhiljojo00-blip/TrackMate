import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = context.watch<ConnectivityProvider?>();
    final isOffline = connectivityProvider?.isOffline ?? false;

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 250),
      crossFadeState: isOffline ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Container(
        width: double.infinity,
        height: 28,
        color: const Color(0xFFE65100), // High-visibility Amber 900
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Offline — Reconnecting to live sync...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      secondChild: const SizedBox(width: double.infinity, height: 0),
    );
  }
}
