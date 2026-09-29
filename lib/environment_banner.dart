import 'package:flutter/material.dart';

import 'cloud/supabase_config.dart';

class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (SupabaseConfig.environment != AppEnvironment.uat) return child;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFFB45309),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: const SafeArea(
            bottom: false,
            child: Text(
              'UAT · TEST DATA · NOT PRODUCTION',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
