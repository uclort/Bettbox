import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/views/views.dart';
import 'package:bett_box/views/network_monitor_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Navigation {
  static Navigation? _instance;

  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
  }) {
    return [
      NavigationItem(
        keep: false,
        icon: Icon(Icons.space_dashboard),
        label: PageLabel.dashboard,
        builder: (_) =>
            DashboardView(key: const GlobalObjectKey(PageLabel.dashboard)),
      ),
      NavigationItem(
        icon: const Icon(Icons.article),
        label: PageLabel.proxies,
        builder: (_) => ProviderScope(
          overrides: [queryProvider.overrideWith(() => Query())],
          child: ProxiesView(key: const GlobalObjectKey(PageLabel.proxies)),
        ),
        modes: hasProxies
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        icon: Icon(Icons.folder),
        label: PageLabel.profiles,
        builder: (_) =>
            ProfilesView(key: const GlobalObjectKey(PageLabel.profiles)),
      ),
      NavigationItem(
        icon: Icon(Icons.monitor_heart_outlined),
        label: PageLabel.networkMonitor,
        builder: (_) => NetworkMonitorNavigationView(
          key: const GlobalObjectKey(PageLabel.networkMonitor),
        ),
        modes: [NavigationItemMode.desktop],
      ),
      ...[
        (PageLabel.requests, MonitorPage.requests, Icons.receipt_long_outlined),
        (PageLabel.connections, MonitorPage.connections, Icons.link),
        (PageLabel.dns, MonitorPage.dns, Icons.dns_outlined),
        (PageLabel.devices, MonitorPage.devices, Icons.devices_outlined),
        (PageLabel.traffic, MonitorPage.traffic, Icons.monitor_heart_outlined),
        (PageLabel.logs, MonitorPage.logs, Icons.article_outlined),
        (PageLabel.subStore, MonitorPage.subStore, Icons.cloud_outlined),
      ].map(
        (entry) => NavigationItem(
          icon: Icon(entry.$3),
          label: entry.$1,
          builder: (_) => NetworkMonitorPageNavigationView(
            page: entry.$2,
            title: entry.$1.localizedName,
          ),
          modes: const [NavigationItemMode.more],
        ),
      ),
      NavigationItem(
        icon: Icon(Icons.storage),
        label: PageLabel.resources,
        description: 'resourcesDesc',
        builder: (_) =>
            ResourcesView(key: const GlobalObjectKey(PageLabel.resources)),
        modes: [NavigationItemMode.more],
      ),
      NavigationItem(
        icon: Icon(Icons.functions),
        label: PageLabel.script,
        description: 'scriptDesc',
        builder: (_) =>
            ScriptsView(key: const GlobalObjectKey(PageLabel.script)),
        modes: [NavigationItemMode.more],
      ),
      NavigationItem(
        icon: Icon(Icons.construction),
        label: PageLabel.tools,
        builder: (_) => ToolsView(key: const GlobalObjectKey(PageLabel.tools)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
    ];
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();
