import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionBanner extends StatelessWidget {
  const VersionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final info = snapshot.data!;
        return Center(
          child: Text(
            'v${info.version}+${info.buildNumber}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        );
      },
    );
  }
}
