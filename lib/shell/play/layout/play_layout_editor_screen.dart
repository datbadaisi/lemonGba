import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/emulation/emulator_input.dart';
import '../../../infrastructure/play/play_layout_store.dart';
import '../../../models/play_layout_profile.dart';
import '../../common/app_toast.dart';
import '../../common/console_chrome.dart';
import '../../common/shell_confirm_dialog.dart';
import '../../common/shell_sheet.dart';
import '../../theme/home_tokens.dart';
import '../../theme/play_tokens.dart';
import '../pad_interaction_scope.dart';
import '../virtual_pad.dart';
import 'play_layout.dart';
import 'play_layout_draft.dart';
import 'play_layout_resize.dart';

enum _EditorMenuAction { saveAndBack, reset, back }

/// Full-bleed layout editor. Draft until Save & back.
class PlayLayoutEditorScreen extends StatefulWidget {
  const PlayLayoutEditorScreen({super.key, required this.store});

  final PlayLayoutStore store;

  @override
  State<PlayLayoutEditorScreen> createState() => _PlayLayoutEditorScreenState();
}

class _PlayLayoutEditorScreenState extends State<PlayLayoutEditorScreen> {
  late final PlayLayoutDraft _draft = PlayLayoutDraft(widget.store);
  final GlobalKey _canvasKey = GlobalKey();
  bool _allowPop = false;
  Size _playSize = Size.zero;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  double get _bottomSafe => MediaQuery.viewPaddingOf(context).bottom;

  Future<void> _openMenu() async {
    unawaited(HapticFeedback.selectionClick());
    final action = await showModalBottomSheet<_EditorMenuAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: PlayModal.surface,
      barrierColor: Colors.black.withValues(alpha: PlayModal.barrierOpacity),
      constraints: const BoxConstraints(maxWidth: PlayModal.sheetMaxWidth),
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
      builder: (ctx) {
        final bottomInset = MediaQuery.viewPaddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: HomeSpacing.sm),
              const ShellSheetHandle(),
              const SizedBox(height: HomeSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: HomeSpacing.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _draft.isDirty
                        ? 'Control layout · unsaved'
                        : 'Control layout',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: HomeSizes.headerTitleSize,
                      color: HomeColors.cream,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: HomeSpacing.xs),
              ShellSheetAction(
                icon: HugeIcons.strokeRoundedFloppyDisk,
                label: 'Save & back',
                color: HomeColors.lemon,
                onTap: () =>
                    Navigator.pop(ctx, _EditorMenuAction.saveAndBack),
              ),
              ShellSheetAction(
                icon: HugeIcons.strokeRoundedRefresh,
                label: 'Reset to defaults',
                color: _draft.profile.isDefault
                    ? HomeColors.labelDim
                    : HomeColors.labelOn,
                onTap: () => Navigator.pop(ctx, _EditorMenuAction.reset),
              ),
              ShellSheetAction(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                label: 'Back',
                onTap: () => Navigator.pop(ctx, _EditorMenuAction.back),
              ),
              const SizedBox(height: HomeSpacing.sm),
            ],
          ),
        );
      },
    );
    // Sheet fully dismissed — no sleep hacks.
    if (!mounted || action == null) return;
    switch (action) {
      case _EditorMenuAction.saveAndBack:
        await _saveAndBack();
      case _EditorMenuAction.reset:
        await _resetDraft();
      case _EditorMenuAction.back:
        await _leave();
    }
  }

  Future<void> _saveAndBack() async {
    try {
      await _draft.saveToStore();
    } catch (e, st) {
      debugPrint('PlayLayoutEditor.save: $e\n$st');
      if (mounted) AppToast.error(context, 'Could not save layout');
      return;
    }
    if (!mounted) return;
    AppToast.success(context, 'Layout saved');
    _allowPop = true;
    Navigator.of(context).pop();
  }

  Future<void> _resetDraft() async {
    if (_draft.profile.isDefault) return;
    final ok = await showShellConfirmDialog(
      context,
      title: 'Reset layout?',
      message:
          'Restore all controls to the default positions and sizes. '
          'Tap Save afterwards to keep the defaults.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (ok != true || !mounted) return;
    _draft.resetDraft();
  }

  Future<void> _leave() async {
    if (_draft.isDirty) {
      final ok = await showShellConfirmDialog(
        context,
        title: 'Discard changes?',
        message: 'You have unsaved layout changes.',
        confirmLabel: 'Discard',
        destructive: true,
      );
      if (ok != true || !mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _onCornerResizeUpdate(Offset globalPos) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    _draft.updateResizeFromPointer(box.globalToLocal(globalPos));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        return PopScope(
          canPop: !_draft.isDirty || _allowPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            unawaited(_leave());
          },
          child: Scaffold(
            backgroundColor: PlayColors.playBg,
            body: ConsoleChrome(
              backgroundColor: PlayColors.playBg,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _playSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final layout = _draft.resolve(
                    width: _playSize.width,
                    height: _playSize.height,
                    bottomSafe: _bottomSafe,
                  );
                  return Stack(
                    key: _canvasKey,
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _draft.deselect,
                        child: const ColoredBox(color: Colors.transparent),
                      ),
                      PadInteractionScope(
                        interactive: false,
                        child: _EditorCanvas(
                          layout: layout,
                          draft: _draft,
                          onCornerResizeUpdate: _onCornerResizeUpdate,
                        ),
                      ),
                      Center(
                        child: _MenuFab(
                          dirty: _draft.isDirty,
                          selected: _draft.selected,
                          onPressed: _openMenu,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditorCanvas extends StatelessWidget {
  const _EditorCanvas({
    required this.layout,
    required this.draft,
    required this.onCornerResizeUpdate,
  });

  final PlayLayout layout;
  final PlayLayoutDraft draft;
  final ValueChanged<Offset> onCornerResizeUpdate;

  static void _noop(EmulatorInput key, bool pressed) {}

  Widget _preview(PlayElementId id, Rect rect) {
    switch (id) {
      case PlayElementId.game:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: PlayColors.framePlaceholder,
            border: Border.all(
              color: PlayColors.plasticEdge.withValues(alpha: 0.55),
            ),
          ),
        );
      case PlayElementId.dpad:
        return VirtualDpad(onKey: _noop, size: rect.width);
      case PlayElementId.faceA:
        return VirtualFaceButton(
          label: 'A',
          keyId: EmulatorInput.a,
          onKey: _noop,
          size: rect.width,
        );
      case PlayElementId.faceB:
        return VirtualFaceButton(
          label: 'B',
          keyId: EmulatorInput.b,
          onKey: _noop,
          size: rect.width,
        );
      case PlayElementId.shoulderL:
        return VirtualShoulder(
          label: 'L',
          keyId: EmulatorInput.l,
          onKey: _noop,
          width: rect.width,
          height: rect.height,
        );
      case PlayElementId.shoulderR:
        return VirtualShoulder(
          label: 'R',
          keyId: EmulatorInput.r,
          onKey: _noop,
          width: rect.width,
          height: rect.height,
        );
      case PlayElementId.select:
        return VirtualMetaButton(
          label: 'SELECT',
          keyId: EmulatorInput.select,
          onKey: _noop,
          width: rect.width,
          height: rect.height,
        );
      case PlayElementId.start:
        return VirtualMetaButton(
          label: 'START',
          keyId: EmulatorInput.start,
          onKey: _noop,
          width: rect.width,
          height: rect.height,
        );
      case PlayElementId.menu:
        return VirtualMenuButton(onPressed: () {}, size: rect.width);
      case PlayElementId.speed:
        return VirtualSpeedButton(
          onLongPress: () {},
          onPressed: () {},
          size: rect.width,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final id in PlayElementId.values)
          _EditorSlot(
            id: id,
            rect: layout.rectOf(id),
            selected: draft.selected == id,
            opacity: id == PlayElementId.game
                ? 1.0
                : layout.opacityFor(layout.rectOf(id)),
            allowsPinch: id.allowsPinch,
            onSelect: () {
              unawaited(HapticFeedback.selectionClick());
              draft.select(id);
            },
            onDrag: (d) => draft.moveBy(id, d, layout),
            onResizeStart: () => draft.beginResize(id, layout),
            onCornerResizeUpdate: onCornerResizeUpdate,
            onResizeEnd: draft.endResize,
            onPinchUpdate: draft.updateResizeFromPinch,
            child: IgnorePointer(child: _preview(id, layout.rectOf(id))),
          ),
      ],
    );
  }
}

class _EditorSlot extends StatelessWidget {
  const _EditorSlot({
    required this.id,
    required this.rect,
    required this.selected,
    required this.opacity,
    required this.allowsPinch,
    required this.onSelect,
    required this.onDrag,
    required this.onResizeStart,
    required this.onCornerResizeUpdate,
    required this.onResizeEnd,
    required this.onPinchUpdate,
    required this.child,
  });

  final PlayElementId id;
  final Rect rect;
  final bool selected;
  final double opacity;
  final bool allowsPinch;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onResizeStart;
  final ValueChanged<Offset> onCornerResizeUpdate;
  final VoidCallback onResizeEnd;
  final ValueChanged<double> onPinchUpdate;
  final Widget child;

  static const double _handle = 22;
  static const double _pad = 11;

  @override
  Widget build(BuildContext context) {
    final pad = selected ? _pad : 0.0;
    return Positioned(
      left: rect.left - pad,
      top: rect.top - pad,
      width: rect.width + pad * 2,
      height: rect.height + pad * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: pad,
            top: pad,
            width: rect.width,
            height: rect.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelect,
              onScaleStart: allowsPinch
                  ? (_) {
                      onSelect();
                      onResizeStart();
                    }
                  : null,
              onScaleUpdate: allowsPinch
                  ? (d) {
                      if (d.pointerCount >= 2) {
                        onPinchUpdate(d.scale);
                      } else {
                        onDrag(d.focalPointDelta);
                      }
                    }
                  : null,
              onScaleEnd: allowsPinch ? (_) => onResizeEnd() : null,
              onPanUpdate: allowsPinch
                  ? null
                  : (d) {
                      onSelect();
                      onDrag(d.delta);
                    },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: selected
                      ? Border.all(color: HomeColors.lemon, width: 2)
                      : null,
                  borderRadius: BorderRadius.circular(PlaySpacing.xs),
                ),
                child: Opacity(opacity: opacity, child: child),
              ),
            ),
          ),
          if (selected) ...[
            Positioned(
              right: 0,
              top: 0,
              child: _CornerHandle(
                onStart: onResizeStart,
                onUpdate: onCornerResizeUpdate,
                onEnd: onResizeEnd,
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: _CornerHandle(
                onStart: onResizeStart,
                onUpdate: onCornerResizeUpdate,
                onEnd: onResizeEnd,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CornerHandle extends StatelessWidget {
  const _CornerHandle({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final VoidCallback onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        unawaited(HapticFeedback.selectionClick());
        onStart();
      },
      onPanUpdate: (d) => onUpdate(d.globalPosition),
      onPanEnd: (_) => onEnd(),
      onPanCancel: onEnd,
      child: Container(
        width: _EditorSlot._handle,
        height: _EditorSlot._handle,
        decoration: BoxDecoration(
          color: HomeColors.lemon,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.open_in_full_rounded,
          size: 12,
          color: HomeColors.onLemon,
        ),
      ),
    );
  }
}

class _MenuFab extends StatelessWidget {
  const _MenuFab({
    required this.dirty,
    required this.selected,
    required this.onPressed,
  });

  final bool dirty;
  final PlayElementId? selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hint = selected == null
        ? null
        : selected!.allowsPinch
            ? '${selected!.label} · drag · pinch or corners'
            : '${selected!.label} · drag · corner handles';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hint != null) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: HomeColors.lemon.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                hint,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: HomeColors.lemon,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HomeColors.lemon,
                  HomeColors.lemon.withValues(alpha: 0.85),
                  const Color(0xFFFFB020),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.tune_rounded,
                  color: HomeColors.onLemon,
                  size: 26,
                ),
                if (dirty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: HomeColors.missing,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: HomeColors.onLemon,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
