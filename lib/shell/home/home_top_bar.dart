import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/home_tokens.dart';

/// Brand row + circular Settings / Multi backup / Add actions.
///
/// [onAdd] accepts a GBA ROM or a Lemon full pack (unified entry).
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.onAdd,
    required this.onSettings,
    this.onMultiBackup,
    this.multiBackupLocked = false,
    this.busy = false,
  });

  final VoidCallback? onAdd;
  final VoidCallback onSettings;

  /// Multi export/import of save packs and full packs. Sits beside [onSettings].
  /// Free users can open the screen to preview; export/import require Pro.
  final VoidCallback? onMultiBackup;

  /// When true, accent the control as a Pro feature (screen still opens).
  final bool multiBackupLocked;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeSpacing.topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HomeSpacing.screenPadH),
        child: Row(
          children: [
            // lemonGba wordmark
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: HomeSizes.brandSize,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
                children: [
                  TextSpan(
                    text: 'lemon',
                    style: TextStyle(color: HomeColors.lemon),
                  ),
                  TextSpan(
                    text: 'Gba',
                    style: TextStyle(color: HomeColors.cream),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _RoundIconButton(
              size: HomeSizes.headerActionSize,
              tooltip: 'Settings',
              onPressed: onSettings,
              background: HomeColors.tileFace,
              borderColor: HomeColors.tileBorder,
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedSetting07,
                size: HomeSizes.headerActionIcon,
                color: HomeColors.cream,
              ),
            ),
            if (onMultiBackup != null) ...[
              const SizedBox(width: HomeSpacing.sm),
              _RoundIconButton(
                size: HomeSizes.headerActionSize,
                tooltip: busy
                    ? 'Busy…'
                    : multiBackupLocked
                        ? 'Multi backup (Pro)'
                        : 'Multi backup',
                onPressed: busy ? null : onMultiBackup,
                background: HomeColors.tileFace,
                borderColor: multiBackupLocked
                    ? HomeColors.lemon.withValues(alpha: 0.55)
                    : HomeColors.tileBorder,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArchive02,
                  size: HomeSizes.headerActionIcon,
                  color: multiBackupLocked
                      ? HomeColors.lemon
                      : HomeColors.cream,
                ),
              ),
            ],
            const SizedBox(width: HomeSpacing.sm),
            _RoundIconButton(
              size: HomeSizes.headerActionSize,
              // Disabled while busy — progress is reported via AppProgressToast,
              // not a spinner inside this chrome.
              tooltip: busy ? 'Busy…' : 'Add game',
              onPressed: busy ? null : onAdd,
              background: HomeColors.lemon,
              borderColor: HomeColors.lemon,
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                size: HomeSizes.headerActionIcon,
                color: HomeColors.onLemon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.size,
    required this.onPressed,
    required this.background,
    required this.borderColor,
    required this.child,
    required this.tooltip,
  });

  final double size;
  final VoidCallback? onPressed;
  final Color background;
  final Color borderColor;
  final Widget child;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fill = enabled ? background : background.withValues(alpha: 0.4);
    final stroke = enabled ? borderColor : borderColor.withValues(alpha: 0.4);

    // Pure circle hit/paint surface — no Material boxShadow/Ink decoration
    // (those leave a faint square under round buttons on some GPUs).
    return Tooltip(
      message: tooltip,
      child: Material(
        color: fill,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: stroke),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
