import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/home_tokens.dart';
import '../theme/play_tokens.dart';

/// Canonical home/library modal sheet chrome (surface + top radius).
Future<T?> showShellModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  /// When false, the sheet body owns safe-area / IME insets (e.g. name panel).
  /// Default matches Material ([showModalBottomSheet] `useSafeArea: true`).
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: PlayModal.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PlayModal.sheetTopRadius),
      ),
    ),
    builder: builder,
  );
}

/// Short action-list body (game long-press, group options, backup rows…).
///
/// Call sites must open with [showShellModalSheet] `isScrollControlled: true`
/// so the sheet can grow to content (default half-screen max is ~200px and
/// overflows a few action rows).
///
/// [header] stays fixed (title bar). [children] grow with the sheet until the
/// top safe edge, then scroll under the header. [Flexible] + [FlexFit.loose]
/// keeps short sheets short; [ClampingScrollPhysics] avoids bounce when extent
/// is 0.
class ShellSheetActionColumn extends StatelessWidget {
  const ShellSheetActionColumn({
    super.key,
    required this.header,
    required this.children,
  });

  /// Fixed chrome (usually [ShellSheetTitleBar]) — does not scroll.
  final Widget header;

  /// Scrollable rows below the header.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      right: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Flexible(
                  fit: FlexFit.loose,
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    children: children,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Drag handle for home bottom sheets.
class ShellSheetHandle extends StatelessWidget {
  const ShellSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: PlayModal.sheetHandleWidth,
        height: PlayModal.sheetHandleHeight,
        decoration: BoxDecoration(
          color: HomeColors.tileBorder,
          borderRadius: BorderRadius.circular(PlayModal.sheetHandleRadius),
        ),
      ),
    );
  }
}

/// Standard sheet header: handle + title (+ optional trailing).
class ShellSheetTitleBar extends StatelessWidget {
  const ShellSheetTitleBar({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: HomeSpacing.sm),
        const ShellSheetHandle(),
        Padding(
          padding: EdgeInsets.fromLTRB(
            trailing == null ? HomeSpacing.lg : HomeSpacing.sheetTitlePadH,
            HomeSpacing.md,
            trailing == null ? HomeSpacing.lg : HomeSpacing.sm,
            HomeSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: HomeSizes.headerTitleSize,
                    color: HomeColors.cream,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

/// Action row for library / home bottom sheets (icon + label, no ListTile gutter).
class ShellSheetAction extends StatelessWidget {
  const ShellSheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = HomeColors.labelOn,
  });

  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HomeSpacing.sheetListPadH,
          HomeSpacing.md,
          HomeSpacing.lg,
          HomeSpacing.md,
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              size: HomeSizes.sheetIconSize,
              color: color,
            ),
            const SizedBox(width: HomeSpacing.sheetIconLabelGap),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: HomeSizes.sheetBodySize,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular multi-select row for group / game pickers.
class ShellSheetCheckRow extends StatelessWidget {
  const ShellSheetCheckRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.trailing,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HomeSpacing.sheetListPadH,
          HomeSpacing.md,
          HomeSpacing.lg,
          HomeSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: HomeSizes.sheetCheckSize,
              height: HomeSizes.sheetCheckSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? HomeColors.lemon : Colors.transparent,
                border: Border.all(
                  color: selected ? HomeColors.lemon : HomeColors.tileBorder,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: HomeSizes.sheetCheckIconSize,
                      color: HomeColors.onLemon,
                    )
                  : null,
            ),
            const SizedBox(width: HomeSpacing.sheetIconLabelGap),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: HomeSizes.sheetBodySize,
                  color: HomeColors.labelOn,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: HomeSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
