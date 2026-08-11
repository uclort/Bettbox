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
        runAction: _runRuleAction,
      ),
    );
  }

  Future<Object?> _runRuleAction(String method, Object? arguments) async {
    if (!widget.embedded) {
      return ExternalControl.request(
        method,
        arguments,
        {
              'appendSubStoreRule',
              'readSubStoreRules',
              'replaceSubStoreRules',
            }.contains(method)
            ? const Duration(seconds: 20)
            : const Duration(seconds: 5),
      );
    }
    return switch (method) {
      'addOverrideRule' => _addMonitorOverrideRule(
        ref,
        normalizeMonitorMap(arguments),
      ),
      'subStoreRuleHistory' => _monitorSubStoreHistory(),
      'appendSubStoreRule' => _appendMonitorSubStoreRule(
        normalizeMonitorMap(arguments),
      ),
      'readSubStoreRules' => _readMonitorSubStoreRules(
        normalizeMonitorMap(arguments),
      ),
      'replaceSubStoreRules' => _replaceMonitorSubStoreRules(
        normalizeMonitorMap(arguments),
      ),
      _ => throw UnsupportedError('未知规则操作：$method'),
    };
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
  final Future<Object?> Function(String method, Object? arguments) runAction;

  const _MonitorRuleDialog({
    required this.item,
    required this.groups,
    required this.proxies,
    required this.runAction,
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
  bool _saving = false;

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

  List<({String value, String label})> get _policyEntries {
    final entries = <({String value, String label})>[];
    final added = <String>{};
    void add(String value, String prefix) {
      value = monitorCompactWhitespace(value);
      if (value.isEmpty || !added.add(value)) return;
      entries.add((value: value, label: '$prefix · $value'));
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

  void _selectPolicy(String value) {
    value = monitorCompactWhitespace(value);
    _policyController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
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

  Future<void> _showError(Object error) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('操作失败'),
        content: SelectableText(
          error.toString().replaceFirst('Bad state: ', ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _addOverride() async {
    var type = OverrideRuleType.added;
    final selected = await showDialog<OverrideRuleType>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加覆写'),
          content: SegmentedButton<OverrideRuleType>(
            segments: const [
              ButtonSegment(
                value: OverrideRuleType.added,
                label: Text('附加原始规则'),
              ),
              ButtonSegment(
                value: OverrideRuleType.override,
                label: Text('覆盖原始规则'),
              ),
            ],
            selected: {type},
            onSelectionChanged: (value) =>
                setDialogState(() => type = value.first),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, type),
              child: const Text('确认添加'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _saving = true);
    try {
      var result = normalizeMonitorMap(
        await widget.runAction('addOverrideRule', {
              'rule': _rule,
              'type': selected.name,
              'force': false,
            }) ??
            const {},
      );
      if (result['duplicate'] == true && result['added'] != true && mounted) {
        final continueAdd = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('规则已存在'),
            content: const Text('当前覆写中已经存在相同规则，是否仍要继续添加？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('继续添加'),
              ),
            ],
          ),
        );
        if (continueAdd != true) return;
        result = normalizeMonitorMap(
          await widget.runAction('addOverrideRule', {
                'rule': _rule,
                'type': selected.name,
                'force': true,
              }) ??
              const {},
        );
      }
      if (mounted && result['added'] == true) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.pop(context);
        messenger?.showSnackBar(const SnackBar(content: Text('已添加到当前配置覆写')));
      }
    } catch (error) {
      await _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _appendSubStore() async {
    try {
      final history = normalizeMonitorMap(
        await widget.runAction('subStoreRuleHistory', null) ?? const {},
      );
      if (!mounted) return;
      final input =
          await showDialog<({String url, String apiKey, bool manage})>(
            context: context,
            builder: (_) => _MonitorSubStoreDialog(
              urls: (history['urls'] as List? ?? const [])
                  .map((item) => item.toString())
                  .toList(),
              apiKeys: (history['keys'] as List? ?? const [])
                  .map((item) => item.toString())
                  .toList(),
            ),
          );
      if (input == null || !mounted) return;
      setState(() => _saving = true);
      var message = '已补充到 Sub-Store 固定规则顶部';
      if (input.manage) {
        final result = normalizeMonitorMap(
          await widget.runAction('readSubStoreRules', {
                'url': input.url,
                'apiKey': input.apiKey,
              }) ??
              const {},
        );
        if (!mounted) return;
        final rules = await showDialog<List<String>>(
          context: context,
          builder: (_) => _MonitorSubStoreRulesDialog(
            rules: (result['rules'] as List? ?? const [])
                .map((item) => item.toString())
                .toList(),
          ),
        );
        if (rules == null || !mounted) return;
        await widget.runAction('replaceSubStoreRules', {
          'url': input.url,
          'apiKey': input.apiKey,
          'rules': rules,
        });
        message = '已更新 Sub-Store 自定义规则';
      } else {
        await widget.runAction('appendSubStoreRule', {
          'url': input.url,
          'apiKey': input.apiKey,
          'rule': _rule,
        });
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.pop(context);
        messenger?.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      await _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                MenuAnchor(
                  menuChildren: [
                    for (final entry in _policyEntries)
                      MenuItemButton(
                        onPressed: () => _selectPolicy(entry.value),
                        child: _compactMonitorText(entry.label),
                      ),
                  ],
                  builder: (context, controller, child) => TextField(
                    controller: _policyController,
                    style: const TextStyle(letterSpacing: 0, wordSpacing: 0),
                    decoration: InputDecoration(
                      labelText: '策略',
                      hintText: '选择策略组、策略，或手动填写',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: '选择策略',
                        onPressed: () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                        icon: const Icon(Icons.arrow_drop_down),
                      ),
                    ),
                  ),
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
                  child: SelectableText.rich(
                    _monitorCompactTextSpan(
                      _rule.isEmpty ? '请填写匹配内容和策略' : _rule,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _rule.isEmpty || _saving ? null : _addOverride,
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text('添加覆写'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _rule.isEmpty || _saving
                          ? null
                          : _appendSubStore,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: const Text('补充至 Sub-Store'),
                    ),
                    FilledButton.icon(
                      onPressed: _rule.isEmpty || _saving
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

class _MonitorSubStoreDialog extends StatefulWidget {
  final List<String> urls;
  final List<String> apiKeys;

  const _MonitorSubStoreDialog({required this.urls, required this.apiKeys});

  @override
  State<_MonitorSubStoreDialog> createState() => _MonitorSubStoreDialogState();
}

class _MonitorSubStoreDialogState extends State<_MonitorSubStoreDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.urls.isEmpty ? '' : widget.urls.first,
    );
    _keyController = TextEditingController(
      text: widget.apiKeys.isEmpty ? '' : widget.apiKeys.first,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Widget _historyField({
    required String label,
    required TextEditingController textController,
    required List<String> values,
    TextInputType? keyboardType,
  }) {
    return MenuAnchor(
      menuChildren: [
        for (final value in values)
          MenuItemButton(
            onPressed: () {
              textController.value = TextEditingValue(
                text: value,
                selection: TextSelection.collapsed(offset: value.length),
              );
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(value, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
      builder: (context, controller, child) => TextField(
        controller: textController,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: '选择历史记录',
            onPressed: values.isEmpty
                ? null
                : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
            icon: const Icon(Icons.arrow_drop_down),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sub-Store 自定义规则'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _historyField(
              label: 'Sub-Store 文件地址（/api/file/文件名）',
              textController: _urlController,
              values: widget.urls,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            _historyField(
              label: 'Sub-Store API Key / 路径前缀',
              textController: _keyController,
              values: widget.apiKeys,
            ),
            const SizedBox(height: 14),
            Text(
              '注意：Sub-Store 覆写脚本必须包含 const '
              '$monitorSubStoreRulesVariable = [...]，否则无法读取、修改或补充，规则也不会生效。',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            const Text('成功使用后，文件地址和 API Key 会仅保存在本机历史记录中。'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        OutlinedButton(
          onPressed: () {
            final url = _urlController.text.trim();
            final apiKey = _keyController.text.trim();
            if (url.isEmpty || apiKey.isEmpty) return;
            Navigator.pop(context, (url: url, apiKey: apiKey, manage: true));
          },
          child: const Text('读取并管理'),
        ),
        FilledButton(
          onPressed: () {
            final url = _urlController.text.trim();
            final apiKey = _keyController.text.trim();
            if (url.isEmpty || apiKey.isEmpty) return;
            Navigator.pop(context, (url: url, apiKey: apiKey, manage: false));
          },
          child: const Text('确认补充'),
        ),
      ],
    );
  }
}

class _MonitorSubStoreRulesDialog extends StatefulWidget {
  final List<String> rules;

  const _MonitorSubStoreRulesDialog({required this.rules});

  @override
  State<_MonitorSubStoreRulesDialog> createState() =>
      _MonitorSubStoreRulesDialogState();
}

class _MonitorSubStoreRulesDialogState
    extends State<_MonitorSubStoreRulesDialog> {
  late final List<TextEditingController> _controllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = widget.rules
        .map((rule) => TextEditingController(text: rule))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final rules = _controllers
        .map((controller) => controller.text.trim())
        .toList();
    if (rules.any((rule) => rule.isEmpty)) {
      setState(() => _error = '规则不能为空，不需要的规则请点击删除');
      return;
    }
    if (rules.toSet().length != rules.length) {
      setState(() => _error = '存在重复规则');
      return;
    }
    Navigator.pop(context, rules);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('管理 Sub-Store 自定义规则'),
      content: SizedBox(
        width: 760,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('拖动可调整匹配顺序，保存后将按当前顺序写回脚本。'),
            const SizedBox(height: 12),
            Expanded(
              child: _controllers.isEmpty
                  ? const Center(child: Text('暂无固定自定义规则'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: _controllers.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = _controllers.removeAt(oldIndex);
                          _controllers.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final controller = _controllers[index];
                        return Padding(
                          key: ObjectKey(controller),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_indicator),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  minLines: 1,
                                  maxLines: 3,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                  decoration: InputDecoration(
                                    labelText: '规则 ${index + 1}',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '删除规则',
                                onPressed: () {
                                  setState(() {
                                    _controllers.removeAt(index);
                                    controller.dispose();
                                    _error = null;
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('保存修改'),
        ),
      ],
    );
  }
}
