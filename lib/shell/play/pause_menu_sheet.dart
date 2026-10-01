import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/emulation/game_speed.dart';
import '../theme/play_tokens.dart';
import 'game_speed_slider.dart';
import 'pause_menu_action.dart';
import 'pause_menu_format.dart';
import 'pause_menu_widgets.dart';

export 'pause_menu_action.dart';

/// Full-height pause bottom sheet (menu / save slots / quick save list).
///
/// Tap SFX is fire-and-forget here. [GameScreen] awaits
/// [AppSfx.waitTapSettle] after dismiss before resuming mGBA AAudio.
Future<PauseMenuAction?> showPauseMenuSheet({
  required BuildContext context,
  required int manualSlotCount,
  required int quickSlotCount,
  required List<DateTime?> quickTimestamps,
  required List<DateTime?> manualTimestamps,
  required int? lastQuickSlot,
  required double speed,
  required ValueChanged<double> onSpeedChanged,
  required VoidCallback onSfxTap,
}) {
  return showModalBottomSheet<PauseMenuAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    enableDrag: true,
    isDismissible: true,
    backgroundColor: PlayModal.surface,
    barrierColor: Colors.black.withValues(alpha: PlayModal.barrierOpacity),
    constraints: const BoxConstraints(maxWidth: PlayModal.sheetMaxWidth),
    // Explicit Material-default exit; residual SFX hold-off via waitTapSettle.
    sheetAnimationStyle: const AnimationStyle(
      duration: PlayModal.sheetEnterDuration,
      reverseDuration: PlayModal.sheetExitDuration,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PlayModal.sheetTopRadius),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) => _PauseMenuBody(
      manualSlotCount: manualSlotCount,
      quickSlotCount: quickSlotCount,
      quickTimestamps: quickTimestamps,
      manualTimestamps: manualTimestamps,
      lastQuickSlot: lastQuickSlot,
      speed: speed,
      onSpeedChanged: onSpeedChanged,
      onSfxTap: onSfxTap,
    ),
  );
}

class _PauseMenuBody extends StatefulWidget {
  const _PauseMenuBody({
    required this.manualSlotCount,
    required this.quickSlotCount,
    required this.quickTimestamps,
    required this.manualTimestamps,
    required this.lastQuickSlot,
    required this.speed,
    required this.onSpeedChanged,
    required this.onSfxTap,
  });

  final int manualSlotCount;
  final int quickSlotCount;
  final List<DateTime?> quickTimestamps;
  final List<DateTime?> manualTimestamps;
  final int? lastQuickSlot;
  final double speed;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onSfxTap;

  @override
  State<_PauseMenuBody> createState() => _PauseMenuBodyState();
}

class _PauseMenuBodyState extends State<_PauseMenuBody> {
  /// 0 = main, 1 = save/load, 2 = quick save, 3 = game speed, 4 = tips.
  int _viewIndex = 0;
  /// +1 push deeper, −1 pop back.
  int _pageDelta = 1;
  late double _speed = GameSpeed.snap(widget.speed);

  void _goTo(int next) {
    setState(() {
      _pageDelta = next > _viewIndex ? 1 : -1;
      _viewIndex = next;
    });
  }

  void _popAction(PauseMenuAction action) => Navigator.pop(context, action);

  Widget _sheetPage({
    required Key key,
    required Widget header,
    required List<Widget> items,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: PlaySpacing.sm),
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: items,
          ),
        ),
      ],
    );
  }

  int _pageIndexForKey(Key? key) {
    if (key == const ValueKey('states')) return 1;
    if (key == const ValueKey('quick')) return 2;
    if (key == const ValueKey('speed')) return 3;
    if (key == const ValueKey('tips')) return 4;
    return 0;
  }

  void _setSpeed(double next) {
    final snapped = GameSpeed.snap(next);
    if (snapped == _speed) return;
    setState(() => _speed = snapped);
    widget.onSpeedChanged(snapped);
  }

  Widget _sheetPageTransition({
    required Widget child,
    required Animation<double> animation,
    required int pageDelta,
    required int childIndex,
    required int currentIndex,
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: PlayModal.pageCurve,
      reverseCurve: PlayModal.pageReverseCurve,
    );
    final isIncoming = childIndex == currentIndex;
    final beginDx = isIncoming
        ? pageDelta * PlayModal.pageSlide
        : -pageDelta * PlayModal.pageSlide;

    return ClipRect(
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(beginDx, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }

  Future<bool> _confirmNewGame() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor:
          Colors.black.withValues(alpha: PlayModal.nestedBarrierOpacity),
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: PlayModal.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PlayModal.confirmRadius),
            side: const BorderSide(color: PlayModal.border),
          ),
          insetPadding: PlayModal.confirmInsetPadding,
          constraints: const BoxConstraints(
            maxWidth: PlayModal.confirmMaxWidth,
          ),
          titlePadding: PlayModal.confirmTitlePadding,
          contentPadding: PlayModal.confirmContentPadding,
          actionsPadding: PlayModal.confirmActionsPadding,
          title: const Text(
            'New Game?',
            style: TextStyle(
              color: PlayModal.confirmTitle,
              fontSize: PlayModal.confirmTitleSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'This erases in-game progress (cartridge save) so you start like the first time. Quick Save and manual slots are kept.',
            style: TextStyle(
              color: PlayModal.body,
              fontSize: PlayModal.confirmBodySize,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                widget.onSfxTap();
                Navigator.pop(ctx, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: PlayModal.confirmCancel,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                widget.onSfxTap();
                Navigator.pop(ctx, true);
              },
              style: TextButton.styleFrom(
                foregroundColor: PlayModal.danger,
              ),
              child: const Text(
                'New Game',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PlayModal.danger,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Widget _buildPage() {
    if (_viewIndex == 0) {
      return _sheetPage(
        key: const ValueKey('menu'),
        header: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PauseMenuWidgets.titleStyle('GAME MENU'),
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: PlayModal.iconMuted,
                size: PlayModal.headerIcon,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                widget.onSfxTap();
                Navigator.pop(context);
              },
            ),
          ],
        ),
        items: [
          PauseMenuWidgets.menuTile(
            context: context,
            icon: HugeIcons.strokeRoundedFloppyDisk,
            title: 'Save / Load States',
            onSfxTap: widget.onSfxTap,
            onTap: () => _goTo(1),
          ),
          PauseMenuWidgets.menuTile(
            context: context,
            icon: HugeIcons.strokeRoundedDashboardSpeed01,
            title: 'Game Speed',
            onSfxTap: widget.onSfxTap,
            onTap: () => _goTo(3),
          ),
          PauseMenuWidgets.menuTile(
            context: context,
            icon: HugeIcons.strokeRoundedBulb,
            title: 'Tips',
            onSfxTap: widget.onSfxTap,
            onTap: () => _goTo(4),
          ),
          PauseMenuWidgets.menuTile(
            context: context,
            icon: HugeIcons.strokeRoundedRefresh,
            title: 'New Game',
            enableSplash: false,
            onSfxTap: widget.onSfxTap,
            onTap: () async {
              final confirmed = await _confirmNewGame();
              if (!mounted) return;
              if (confirmed) _popAction(const PauseNewGame());
            },
          ),
          PauseMenuWidgets.menuTile(
            context: context,
            icon: HugeIcons.strokeRoundedLogout01,
            title: 'Save & Exit',
            textColor: PlayModal.danger,
            iconColor: PlayModal.danger,
            onSfxTap: widget.onSfxTap,
            onTap: () => _popAction(const PauseExit()),
          ),
        ],
      );
    }

    if (_viewIndex == 4) {
      return _sheetPage(
        key: const ValueKey('tips'),
        header: PauseMenuWidgets.pageHeaderBack(
          title: 'TIPS',
          onSfxTap: widget.onSfxTap,
          onBack: () => _goTo(0),
        ),
        items: [
          PauseMenuWidgets.tipRow(
            icon: HugeIcons.strokeRoundedFloppyDisk,
            title: 'Quick Save',
            body:
                'Long-press the save button (bottom-left) while playing to write a quick save without opening the menu.',
          ),
          PauseMenuWidgets.tipRow(
            icon: HugeIcons.strokeRoundedPause,
            title: 'Pause & Resume',
            body:
                'Double-tap the game screen to pause. Double-tap again to resume.',
          ),
          PauseMenuWidgets.tipRow(
            icon: HugeIcons.strokeRoundedDashboardSpeed01,
            title: 'Cycle Speed',
            body:
                'Long-press the speed button (bottom-right) while playing to step through game speeds.',
          ),
        ],
      );
    }

    if (_viewIndex == 3) {
      return _sheetPage(
        key: const ValueKey('speed'),
        header: PauseMenuWidgets.pageHeaderBack(
          title: 'GAME SPEED',
          onSfxTap: widget.onSfxTap,
          onBack: () => _goTo(0),
        ),
        items: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PlayModal.tilePadH,
              vertical: PlaySpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GameSpeedSlider(
                  value: _speed,
                  onChanged: (v) {
                    widget.onSfxTap();
                    _setSpeed(v);
                  },
                ),
                const SizedBox(height: PlaySpacing.lg),
                Text(
                  'Hold the speed button (bottom-right) while playing to cycle speed.',
                  style: TextStyle(
                    color: PlayModal.slotMeta,
                    fontSize: PlayModal.slotMetaSize,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_viewIndex == 1) {
      return _sheetPage(
        key: const ValueKey('states'),
        header: PauseMenuWidgets.pageHeaderBack(
          title: 'SAVE / LOAD STATES',
          onSfxTap: widget.onSfxTap,
          onBack: () => _goTo(0),
        ),
        items: [
          PauseMenuWidgets.slotAlignedNavTile(
            icon: HugeIcons.strokeRoundedClock01,
            title: 'Quick Save',
            onSfxTap: widget.onSfxTap,
            onTap: () => _goTo(2),
          ),
          for (var slot = 1; slot <= widget.manualSlotCount; slot++)
            PauseMenuWidgets.stateSlotRow(
              title: 'Save Slot $slot',
              savedAt: widget.manualTimestamps[slot - 1],
              onSfxTap: widget.onSfxTap,
              onSave: () => _popAction(PauseSaveManual(slot)),
              onLoad: () => _popAction(PauseLoadManual(slot)),
            ),
        ],
      );
    }

    return _sheetPage(
      key: const ValueKey('quick'),
      header: PauseMenuWidgets.pageHeaderBack(
        title: 'QUICK SAVE',
        onSfxTap: widget.onSfxTap,
        onBack: () => _goTo(1),
      ),
      items: [
        for (var slot = 1; slot <= widget.quickSlotCount; slot++)
          () {
            final savedAt = widget.quickTimestamps[slot - 1];
            final isLatest =
                widget.lastQuickSlot != null && widget.lastQuickSlot == slot;
            final isEmpty = savedAt == null;
            final title =
                isEmpty ? 'Slot $slot' : PauseMenuFormat.slotSavedAt(savedAt);
            final subtitle = isEmpty
                ? null
                : isLatest
                    ? '${PauseMenuFormat.relativeAgo(savedAt)} · Latest'
                    : PauseMenuFormat.relativeAgo(savedAt);
            return PauseMenuWidgets.stateSlotRow(
              title: title,
              savedAt: savedAt,
              subtitle: subtitle,
              highlight: isLatest,
              onSfxTap: widget.onSfxTap,
              onLoad: () => _popAction(PauseLoadQuick(slot)),
            );
          }(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetH = MediaQuery.sizeOf(context).height;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: sheetH,
      child: Padding(
        padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: PlaySpacing.sm,
                bottom: PlaySpacing.sm,
              ),
              child: Center(
                child: Container(
                  width: PlayModal.sheetHandleWidth,
                  height: PlayModal.sheetHandleHeight,
                  decoration: BoxDecoration(
                    color: PlayModal.handle,
                    borderRadius: BorderRadius.circular(
                      PlayModal.sheetHandleRadius,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: PlayModal.padding.copyWith(top: 0),
                child: AnimatedSwitcher(
                  duration: PlayModal.pageDuration,
                  switchInCurve: PlayModal.pageCurve,
                  switchOutCurve: PlayModal.pageReverseCurve,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: <Widget>[
                        for (final child in previousChildren)
                          Positioned.fill(child: child),
                        ?currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, anim) {
                    return _sheetPageTransition(
                      child: child,
                      animation: anim,
                      pageDelta: _pageDelta,
                      childIndex: _pageIndexForKey(child.key),
                      currentIndex: _viewIndex,
                    );
                  },
                  child: _buildPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
