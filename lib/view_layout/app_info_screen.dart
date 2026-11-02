import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../provider/main_provider.dart';
import '../res/custom_colors.dart';

class AppInfoScreen extends ConsumerStatefulWidget {
  const AppInfoScreen({super.key});

  @override
  ConsumerState<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends ConsumerState<AppInfoScreen> {
  static const MethodChannel _deviceInfoChannel = MethodChannel(
    'com.hnglife.bspoint/device_info',
  );

  late final Future<_AppInfoData> _appInfoFuture;

  @override
  void initState() {
    super.initState();
    _appInfoFuture = _loadAppInfo();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final arsItems = _buildArsItems(authState);

    return Scaffold(
      backgroundColor: CustomColors.background,
      appBar: AppBar(
        title: const Text('\uC571 \uC815\uBCF4'),
      ),
      body: FutureBuilder<_AppInfoData>(
        future: _appInfoFuture,
        builder: (context, snapshot) {
          final appInfo = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoSection(
                title: '\uC571 \uBC84\uC804',
                children: [
                  _InfoRow(label: '\uC571 \uC774\uB984', value: appInfo?.appName ?? '-'),
                  _InfoRow(label: '\uBC84\uC804', value: appInfo?.version ?? '-'),
                  _InfoRow(
                    label: '\uBE4C\uB4DC \uBC88\uD638',
                    value: appInfo?.buildNumber ?? '-',
                  ),
                  _InfoRow(
                    label: '\uD328\uD0A4\uC9C0\uBA85',
                    value: appInfo?.packageName ?? '-',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InfoSection(
                title: 'ARS \uC778\uC99D \uC815\uBCF4',
                children: arsItems.isEmpty
                    ? const [
                        _InfoRow(
                          label: '\uC0C1\uD0DC',
                          value:
                              '\uC800\uC7A5\uB41C \uC778\uC99D \uC815\uBCF4\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4.',
                        ),
                      ]
                    : arsItems,
              ),
              const SizedBox(height: 16),
              _InfoSection(
                title: '\uAE30\uAE30 \uC815\uBCF4',
                children: snapshot.connectionState == ConnectionState.waiting
                    ? const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                CustomColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ]
                    : snapshot.hasError
                        ? const [
                            _InfoRow(
                              label: '\uC624\uB958',
                              value:
                                  '\uAE30\uAE30 \uC815\uBCF4\uB97C \uBD88\uB7EC\uC624\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4.',
                            ),
                          ]
                        : (appInfo?.deviceRows.isNotEmpty ?? false)
                            ? appInfo!.deviceRows
                            : const [
                                _InfoRow(
                                  label: '\uAE30\uAE30',
                                  value:
                                      '\uC9C0\uC6D0\uB418\uC9C0 \uC54A\uB294 \uD50C\uB7AB\uD3FC\uC785\uB2C8\uB2E4.',
                                ),
                              ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildArsItems(AuthState authState) {
    final rows = <Widget>[];

    final userInfo = authState.userInfo;
    if (userInfo == null || userInfo.isEmpty) {
      return const [
        _InfoRow(
          label: '\uC0C1\uD0DC',
          value:
              '\uC800\uC7A5\uB41C \uC778\uC99D \uC815\uBCF4\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4.',
        ),
      ];
    }

    const visibleFields = <String, String>{
      'app_cid': '\uC778\uC99D \uC804\uD654\uBC88\uD638',
      'now': '\uC778\uC99D \uC2DC\uAC01',
      'session_id': '\uC778\uC99D \uBC88\uD638',
      'appuuid': '\uC571 UUID',
      'prnts_phone_no': '\uCD94\uCC9C\uC778 \uC804\uD654\uBC88\uD638',
    };

    for (final entry in visibleFields.entries) {
      final key = entry.key;
      final value = userInfo[key];
      if (value == null || value.toString().trim().isEmpty) {
        continue;
      }

      rows.add(
        _InfoRow(
          label: entry.value,
          value: value.toString(),
        ),
      );
    }

    if (rows.isEmpty) {
      return const [
        _InfoRow(
          label: '\uC0C1\uD0DC',
          value:
              '\uD45C\uC2DC\uD560 \uC778\uC99D \uC815\uBCF4\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4.',
        ),
      ];
    }

    return rows;
  }

  Future<_AppInfoData> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceRows = <Widget>[];

    if (Platform.isAndroid) {
      final info = await deviceInfoPlugin.androidInfo;
      final carrierName = await _getCarrierName();
      deviceRows.addAll([
        _InfoRow(label: '\uD50C\uB7AB\uD3FC', value: 'Android'),
        _InfoRow(label: 'Android \uBC84\uC804', value: info.version.release),
        _InfoRow(label: 'SDK', value: '${info.version.sdkInt}'),
        _InfoRow(label: '\uC81C\uC870\uC0AC', value: info.manufacturer),
        _InfoRow(label: '\uBAA8\uB378', value: info.model),
        _InfoRow(label: '\uD1B5\uC2E0\uC0AC', value: carrierName ?? '-'),
        const SizedBox(height: 12),
      ]);
    } else if (Platform.isIOS) {
      final info = await deviceInfoPlugin.iosInfo;
      deviceRows.addAll([
        _InfoRow(label: '\uD50C\uB7AB\uD3FC', value: 'iOS'),
        _InfoRow(label: 'iOS \uBC84\uC804', value: info.systemVersion),
        _InfoRow(label: '\uAE30\uAE30\uBA85', value: info.name),
        _InfoRow(label: '\uBAA8\uB378', value: info.model),
      ]);
    } else {
      deviceRows.add(
        _InfoRow(label: '\uD50C\uB7AB\uD3FC', value: Platform.operatingSystem),
      );
      deviceRows.add(
        _InfoRow(
          label: 'OS \uBC84\uC804',
          value: Platform.operatingSystemVersion,
        ),
      );
    }

    return _AppInfoData(
      appName: packageInfo.appName,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      packageName: packageInfo.packageName,
      deviceRows: deviceRows,
    );
  }

  Future<String?> _getCarrierName() async {
    try {
      final carrierName = await _deviceInfoChannel.invokeMethod<String>(
        'getCarrierName',
      );
      if (carrierName == null || carrierName.trim().isEmpty) {
        return null;
      }
      return carrierName;
    } on PlatformException {
      return null;
    }
  }
}

class _AppInfoData {
  const _AppInfoData({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.packageName,
    required this.deviceRows,
  });

  final String appName;
  final String version;
  final String buildNumber;
  final String packageName;
  final List<Widget> deviceRows;
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CustomColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: CustomColors.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: CustomColors.greyDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: CustomColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
