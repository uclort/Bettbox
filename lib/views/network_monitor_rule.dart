part of 'network_monitor.dart';

extension _NetworkMonitorRuleGenerator on _NetworkMonitorViewState {
  Future<void> _showTrackerContextMenu(
    BuildContext context,
    TrackerInfo item,
    TapDownDetails details,
  ) async {
    _selectTracker(item);
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()!
            as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 1, 1),
      Offset.zero & overlay.size,
    );
    final action = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(
          value: 'generateRule',
          child: Row(
            children: [
              Icon(Icons.rule_outlined, size: 18),
              SizedBox(width: 8),
              Text('生成规则…'),
            ],
          ),
        ),
      ],
    );
    if (action != 'generateRule' || !context.mounted) return;
    final policies = await _readRulePolicies();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _MonitorRuleDialog(
        item: item,
        groups: policies['groups'] ?? const [],
        proxies: policies['proxies'] ?? const [],
      ),
    );
  }

  Future<Map<String, List<String>>> _readRulePolicies() async {
    final raw = widget.embedded
        ? monitorRulePolicies(ref.read(groupsProvider))
        : normalizeMonitorMap(
            await ExternalControl.request('rulePolicies') ?? const {},
          );
    return {
      'groups': (raw['groups'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      'proxies': (raw['proxies'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    };
  }
}

class _MonitorRuleDialog extends StatefulWidget {
  final TrackerInfo item;
  final List<String> groups;
  final List<String> proxies;

  const _MonitorRuleDialog({
    required this.item,
    required this.groups,
    required this.proxies,
  });

  @override
  State<_MonitorRuleDialog> createState() => _MonitorRuleDialogState();
}

class _MonitorRuleDialogState extends State<_MonitorRuleDialog> {
  late MonitorRuleSource _source;
  late MonitorRuleType _type;
  late final TextEditingController _valueController;
  late final TextEditingController _processController;
  late final TextEditingController _processPathController;
  late final TextEditingController _policyController;
  bool _noResolve = false;

  @override
  void initState() {
    super.initState();
    _source = widget.item.metadata.host.trim().isNotEmpty
        ? MonitorRuleSource.domain
        : widget.item.metadata.process.trim().isNotEmpty
        ? MonitorRuleSource.process
        : MonitorRuleSource.ip;
    _type = monitorRuleTypes(_source).first;
    _valueController = TextEditingController(
      text: monitorRuleDefaultValue(widget.item, _type),
    );
    _processController = TextEditingController(
      text: widget.item.metadata.process.trim(),
    );
    _processPathController = TextEditingController(
      text: widget.item.metadata.processPath.trim(),
    );
    _policyController = TextEditingController(
      text: monitorPolicyName(widget.item),
    );
    for (final controller in [
      _valueController,
      _processController,
      _processPathController,
      _policyController,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _valueController.dispose();
    _processController.dispose();
    _processPathController.dispose();
    _policyController.dispose();
    super.dispose();
  }

  String get _ruleValue => switch (_type) {
    MonitorRuleType.processName ||
    MonitorRuleType.processNameRegex => _processController.text,
    MonitorRuleType.processPath => _processPathController.text,
    _ => _valueController.text,
  };

  String get _rule => monitorGeneratedRule(
    _type,
    _ruleValue,
    _policyController.text,
    noResolve: _noResolve,
  );

  List<DropdownMenuEntry<String>> get _policyEntries {
    final entries = <DropdownMenuEntry<String>>[];
    final added = <String>{};
    void add(String value, String prefix) {
      value = value.trim();
      if (value.isEmpty || !added.add(value)) return;
      entries.add(DropdownMenuEntry(value: value, label: '$prefix · $value'));
    }

    for (final value in const ['DIRECT', 'REJECT', 'REJECT-DROP', 'PASS']) {
      add(value, '内置');
    }
    for (final value in widget.groups) {
      add(value, '策略组');
    }
    for (final value in widget.proxies) {
      add(value, '策略');
    }
    add(_policyController.text, '当前');
    return entries;
  }

  void _selectSource(MonitorRuleSource source) {
    final type = monitorRuleTypes(source).first;
    setState(() {
      _source = source;
      _type = type;
      _noResolve = false;
      if (source != MonitorRuleSource.process) {
        _valueController.text = monitorRuleDefaultValue(widget.item, type);
      }
    });
  }

  void _selectType(MonitorRuleType? type) {
    if (type == null) return;
    setState(() {
      _type = type;
      _noResolve = false;
      if (_source != MonitorRuleSource.process) {
        _valueController.text = monitorRuleDefaultValue(widget.item, type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final address = monitorAddress(widget.item);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('生成规则', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('${monitorClientName(widget.item)} · $address'),
                const SizedBox(height: 18),
                SegmentedButton<MonitorRuleSource>(
                  segments: [
                    for (final source in MonitorRuleSource.values)
                      ButtonSegment(value: source, label: Text(source.label)),
                  ],
                  selected: {_source},
                  onSelectionChanged: (value) => _selectSource(value.first),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MonitorRuleType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: '规则类型',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final type in monitorRuleTypes(_source))
                      DropdownMenuItem(
                        value: type,
                        child: Text(type.clashName),
                      ),
                  ],
                  onChanged: _selectType,
                ),
                const SizedBox(height: 12),
                if (_source == MonitorRuleSource.process) ...[
                  TextField(
                    controller: _processController,
                    decoration: InputDecoration(
                      labelText: _type == MonitorRuleType.processNameRegex
                          ? '进程名称 / 正则'
                          : '进程名称',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _processPathController,
                    decoration: const InputDecoration(
                      labelText: '进程路径',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else
                  TextField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      labelText: '匹配内容',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (_type.supportsNoResolve)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _noResolve,
                    title: const Text('no-resolve'),
                    subtitle: const Text('匹配时不额外解析域名'),
                    onChanged: (value) =>
                        setState(() => _noResolve = value ?? false),
                  ),
                const SizedBox(height: 12),
                DropdownMenu<String>(
                  controller: _policyController,
                  expandedInsets: EdgeInsets.zero,
                  enableFilter: true,
                  enableSearch: true,
                  requestFocusOnTap: true,
                  label: const Text('策略'),
                  hintText: '选择策略组、策略，或手动填写',
                  dropdownMenuEntries: _policyEntries,
                  onSelected: (value) {
                    if (value != null) _policyController.text = value;
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  '已根据当前连接自动填充，所有输入内容均可手动修改',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text('最终规则', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(minHeight: 96),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _rule.isEmpty ? '请填写匹配内容和策略' : _rule,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _rule.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: _rule),
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('复制规则'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
