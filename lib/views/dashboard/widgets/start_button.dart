import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RunTime extends ConsumerWidget {
  const RunTime({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runTime = ref.watch(runTimeProvider);
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(label: appLocalizations.runTime, iconData: Icons.timer),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          alignment: Alignment.bottomLeft,
          child: Text(
            utils.getTimeText(runTime),
            style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
          ),
        ),
      ),
    );
  }
}

class AndroidStartButton extends ConsumerStatefulWidget {
  const AndroidStartButton({super.key});

  @override
  ConsumerState<AndroidStartButton> createState() => _AndroidStartButtonState();
}

class _AndroidStartButtonState extends ConsumerState<AndroidStartButton> {
  bool _isDisabled = false;
  bool? _optimisticStart;

  Future<void> _handleStart() async {
    if (_isDisabled) return;
    final newState = ref.read(runTimeProvider) == null;
    setState(() {
      _isDisabled = true;
      _optimisticStart = newState;
    });
    try {
      await globalState.appController.updateStatus(newState);
    } catch (e) {
      commonPrint.log('updateStatus failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDisabled = false;
          _optimisticStart = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    if (!state.isInit || !state.hasProfile) return const SizedBox.shrink();

    final isRestarting = ref.watch(isRestartingCoreProvider);
    final isStart = _optimisticStart ?? ref.watch(runTimeProvider) != null;
    final isLoading = _isDisabled || isRestarting;
    return FloatingActionButton(
      heroTag: null,
      onPressed: isLoading ? null : _handleStart,
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isStart ? Icons.stop : Icons.play_arrow),
    );
  }
}
