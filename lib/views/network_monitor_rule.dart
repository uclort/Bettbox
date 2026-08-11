part of 'network_monitor.dart';

extension _NetworkMonitorRuleGenerator on _NetworkMonitorViewState {
  Widget _buildSubStorePage(BuildContext context) {
    return _MonitorSubStorePanel(runAction: _runRuleAction);
  }

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
                label: Text('附加到原始规则'),
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
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 820,
          child: _MonitorSubStorePanel(
            runAction: widget.runAction,
            appendRule: _rule,
            fitDialogContent: true,
            onClose: () => Navigator.pop(dialogContext, false),
            onAppended: () => Navigator.pop(dialogContext, true),
          ),
        ),
      ),
    );
    if (added == true && mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('已补充到 Sub-Store 固定规则顶部')),
      );
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

class _MonitorSubStorePanel extends StatefulWidget {
  final Future<Object?> Function(String method, Object? arguments) runAction;
  final String? appendRule;
  final bool fitDialogContent;
  final VoidCallback? onClose;
  final VoidCallback? onAppended;

  const _MonitorSubStorePanel({
    required this.runAction,
    this.appendRule,
    this.fitDialogContent = false,
    this.onClose,
    this.onAppended,
  });

  @override
  State<_MonitorSubStorePanel> createState() => _MonitorSubStorePanelState();
}

class _MonitorSubStorePanelState extends State<_MonitorSubStorePanel> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  var _urls = <String>[];
  var _apiKeys = <String>[];
  List<({TextEditingController rule, TextEditingController note})>?
  _ruleControllers;
  String? _busyMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _disposeRules();
    super.dispose();
  }

  void _disposeRules() {
    for (final item in _ruleControllers ?? const []) {
      item.rule.dispose();
      item.note.dispose();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = normalizeMonitorMap(
        await widget.runAction('subStoreRuleHistory', null) ?? const {},
      );
      if (!mounted) return;
      setState(() {
        _urls = (history['urls'] as List? ?? const [])
            .map((item) => item.toString())
            .toList();
        _apiKeys = (history['keys'] as List? ?? const [])
            .map((item) => item.toString())
            .toList();
        if (_urlController.text.isEmpty && _urls.isNotEmpty) {
          _urlController.text = _urls.first;
        }
        if (_keyController.text.isEmpty && _apiKeys.isNotEmpty) {
          _keyController.text = _apiKeys.first;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  ({String url, String apiKey})? _credentials() {
    final url = _urlController.text.trim();
    final apiKey = _keyController.text.trim();
    if (url.isEmpty || apiKey.isEmpty) {
      setState(() => _error = '请填写 Sub-Store 文件地址和 API Key');
      return null;
    }
    return (url: url, apiKey: apiKey);
  }

  Future<void> _readRules() async {
    final credentials = _credentials();
    if (credentials == null) return;
    setState(() {
      _busyMessage = '正在读取 Sub-Store 自定义规则…';
      _error = null;
    });
    try {
      final result = normalizeMonitorMap(
        await widget.runAction('readSubStoreRules', {
              'url': credentials.url,
              'apiKey': credentials.apiKey,
            }) ??
            const {},
      );
      if (!mounted) return;
      _disposeRules();
      setState(() {
        _ruleControllers = (result['rules'] as List? ?? const []).map((item) {
          final value = normalizeMonitorMap(item);
          return (
            rule: TextEditingController(text: value['rule']?.toString() ?? ''),
            note: TextEditingController(text: value['note']?.toString() ?? ''),
          );
        }).toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  Future<void> _appendRule() async {
    final credentials = _credentials();
    if (credentials == null || widget.appendRule == null) return;
    setState(() {
      _busyMessage = '正在补充 Sub-Store 自定义规则…';
      _error = null;
    });
    try {
      await widget.runAction('appendSubStoreRule', {
        'url': credentials.url,
        'apiKey': credentials.apiKey,
        'rule': widget.appendRule,
      });
      if (mounted) widget.onAppended?.call();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  void _backToCredentials() {
    _disposeRules();
    setState(() {
      _ruleControllers = null;
      _error = null;
    });
  }

  Future<void> _saveRules() async {
    final credentials = _credentials();
    if (credentials == null) return;
    final rules = _ruleControllers!
        .map(
          (item) => {
            'rule': item.rule.text.trim(),
            'note': item.note.text.trim(),
          },
        )
        .toList();
    if (rules.any((item) => item['rule']!.isEmpty)) {
      setState(() => _error = '规则不能为空，不需要的规则请点击删除');
      return;
    }
    if (rules.map((item) => item['rule']).toSet().length != rules.length) {
      setState(() => _error = '存在重复规则');
      return;
    }
    setState(() {
      _busyMessage = '正在保存 Sub-Store 自定义规则…';
      _error = null;
    });
    try {
      await widget.runAction('replaceSubStoreRules', {
        'url': credentials.url,
        'apiKey': credentials.apiKey,
        'rules': rules,
      });
      if (!mounted) return;
      _backToCredentials();
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('已更新 Sub-Store 自定义规则')));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
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

  Widget _buildCredentials(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sub-Store 自定义规则',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              _historyField(
                label: 'Sub-Store 文件地址（/api/file/文件名）',
                textController: _urlController,
                values: _urls,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 14),
              _historyField(
                label: 'Sub-Store API Key',
                textController: _keyController,
                values: _apiKeys,
              ),
              const SizedBox(height: 16),
              Text(
                '注意：Sub-Store 覆写脚本必须包含 const '
                '$monitorSubStoreRulesVariable = [...]，否则无法读取、修改或补充，规则也不会生效。',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              const Text('成功使用后，文件地址和 API Key 会仅保存在本机历史记录中。'),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (widget.onClose != null)
                    TextButton(
                      onPressed: widget.onClose,
                      child: const Text('取消'),
                    ),
                  OutlinedButton(
                    onPressed: _readRules,
                    child: const Text('读取并管理'),
                  ),
                  if (widget.appendRule != null)
                    FilledButton(
                      onPressed: _appendRule,
                      child: const Text('确认补充'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRules(BuildContext context) {
    final controllers = _ruleControllers!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '管理 Sub-Store 自定义规则',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          const Text('拖动可调整匹配顺序，保存后将按当前顺序写回脚本。'),
          const SizedBox(height: 20),
          Expanded(
            child: controllers.isEmpty
                ? const Center(child: Text('暂无固定自定义规则'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(top: 8, right: 4),
                    buildDefaultDragHandles: false,
                    itemCount: controllers.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final item = controllers.removeAt(oldIndex);
                        controllers.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = controllers[index];
                      return Card(
                        key: ObjectKey(item.rule),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
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
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: item.rule,
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
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: item.note,
                                      minLines: 1,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: '说明（可选）',
                                        hintText: '例如：1Password 直连，避免同步异常',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '删除规则',
                                onPressed: () {
                                  setState(() {
                                    controllers.removeAt(index);
                                    item.rule.dispose();
                                    item.note.dispose();
                                    _error = null;
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _backToCredentials,
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saveRules,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('保存修改'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: _busyMessage != null,
          child: _ruleControllers == null
              ? _buildCredentials(context)
              : _buildRules(context),
        ),
        if (_busyMessage != null)
          Positioned.fill(
            child: Material(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .92),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_busyMessage!),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    if (!widget.fitDialogContent) return content;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: SizedBox(
        height: _ruleControllers == null ? (_error == null ? 430 : 480) : 620,
        child: content,
      ),
    );
  }
}
