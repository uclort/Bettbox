import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';

import 'network_monitor.dart';

class NetworkMonitorNavigationView extends StatelessWidget {
  const NetworkMonitorNavigationView({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '网络面板',
      body: Center(
        child: FilledButton.icon(
          onPressed: openNetworkMonitorWindow,
          icon: const Icon(Icons.open_in_new),
          label: const Text('打开网络面板'),
        ),
      ),
    );
  }
}

class NetworkMonitorEmbeddedNavigationView extends StatelessWidget {
  const NetworkMonitorEmbeddedNavigationView({super.key});

  @override
  Widget build(BuildContext context) => CommonScaffold(
    title: '网络面板',
    body: const NetworkMonitorView(embedded: true, mobile: true),
  );
}
