import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/play_tokens.dart';
import 'pause_menu_format.dart';

/// Shared tile / slot chrome used by pause-menu pages.
class PauseMenuWidgets {
  const PauseMenuWidgets._();

  static Widget titleStyle(String text) => Text(
        text,
        style: const TextStyle(
          color: PlayModal.title,
          fontSize: PlayModal.titleSize,
          fontWeight: FontWeight.w700,
          letterSpacing: PlayModal.titleTracking,
        ),
      );

  static Widget menuTile({
    required BuildContext context,
    required List<List<dynamic>> icon,
    required String title,
    required VoidCallback onTap,
    required VoidCallback onSfxTap,
    Color? textColor,
    Color? iconColor,
    bool enableSplash = true,
  }) {
    final fg = textColor ?? PlayModal.onSurface;
    final ic = iconColor ?? PlayColors.labelOn;

    final tile = ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      minVerticalPadding: 0,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PlayModal.tilePadH,
        vertical: PlayModal.tilePadV,
      ),
      splashColor: enableSplash ? PlayModal.inkSplash : Colors.transparent,
      hoverColor: enableSplash ? PlayModal.inkHover : Colors.transparent,
      focusColor: Colors.transparent,
      leading: HugeIcon(icon: icon, color: ic, size: PlayModal.tileIcon),
      title: Text(
        title,
        style: TextStyle(
          color: fg,
          fontSize: PlayModal.tileTitleSize,
          fontWeight: FontWeight.w600,
          shadows: PlayModal.titleShadows,
        ),
      ),
      trailing: const HugeIcon(
        icon: HugeIcons.strokeRoundedArrowRight01,
        color: PlayModal.chevron,
        size: PlayModal.trailingIcon,
      ),
      onTap: () {
        onSfxTap();
        onTap();
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PlayModal.tileRadius),
      ),
    );

    if (enableSplash) return tile;

    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: tile,
    );
  }

  static Widget slotAlignedNavTile({
    required List<List<dynamic>> icon,
    required String title,
    required VoidCallback onTap,
    required VoidCallback onSfxTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onSfxTap();
          onTap();
        },
        borderRadius: BorderRadius.circular(PlayModal.tileRadius),
        splashColor: PlayModal.inkSplash,
        highlightColor: PlayModal.inkHover,
        child: Padding(
          padding: PlayModal.slotPadding,
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: PlayColors.labelOn,
                size: PlayModal.tileIcon,
              ),
              const SizedBox(width: PlaySpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: PlayModal.onSurface,
                    fontSize: PlayModal.tileTitleSize,
                    fontWeight: FontWeight.w600,
                    shadows: PlayModal.titleShadows,
                  ),
                ),
              ),
              const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: PlayModal.chevron,
                size: PlayModal.trailingIcon,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget stateSlotRow({
    required String title,
    required DateTime? savedAt,
    required VoidCallback onLoad,
    required VoidCallback onSfxTap,
    VoidCallback? onSave,
    String? subtitle,
    bool highlight = false,
  }) {
    final isEmpty = savedAt == null;
    final meta =
        isEmpty ? 'Empty' : (subtitle ?? PauseMenuFormat.slotSavedAt(savedAt));
    return Padding(
      padding: PlayModal.slotPadding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: highlight
                        ? PlayModal.slotLabelHot
                        : PlayModal.slotLabel,
                    fontSize: PlayModal.slotLabelSize,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: PlaySpacing.xxs),
                Text(
                  meta,
                  style: TextStyle(
                    color: isEmpty
                        ? PlayModal.slotMetaEmpty
                        : highlight
                            ? PlayModal.slotMetaHot
                            : PlayModal.slotMeta,
                    fontSize: PlayModal.slotMetaSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onSave != null) ...[
                slotActionButton(
                  label: 'SAVE',
                  onTap: onSave,
                  onSfxTap: onSfxTap,
                ),
                const SizedBox(width: PlayModal.actionGap),
              ],
              slotActionButton(
                label: 'LOAD',
                onTap: onLoad,
                onSfxTap: onSfxTap,
                isPrimary: true,
                enabled: !isEmpty,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget slotActionButton({
    required String label,
    required VoidCallback onTap,
    required VoidCallback onSfxTap,
    bool isPrimary = false,
    bool enabled = true,
  }) {
    final fill = !enabled
        ? PlayModal.actionFillDisabled
        : isPrimary
            ? PlayModal.actionFillPrimary
            : PlayModal.actionFill;
    final border = !enabled
        ? PlayModal.actionBorderDisabled
        : isPrimary
            ? PlayModal.actionBorderPrimary
            : PlayModal.actionBorder;
    final text = !enabled
        ? PlayModal.actionTextDisabled
        : isPrimary
            ? PlayModal.onSurface
            : PlayModal.actionText;

    return GestureDetector(
      onTap: !enabled
          ? null
          : () {
              onSfxTap();
              onTap();
            },
      child: Container(
        padding: PlayModal.actionPadding,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(PlayModal.actionRadius),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: PlayModal.actionFont,
            fontWeight: FontWeight.w700,
            letterSpacing: PlayModal.actionTracking,
          ),
        ),
      ),
    );
  }

  static Widget pageHeaderBack({
    required String title,
    required VoidCallback onBack,
    required VoidCallback onSfxTap,
  }) {
    return Row(
      children: [
        IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: PlayModal.iconBack,
            size: PlayModal.backIcon,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            onSfxTap();
            onBack();
          },
        ),
        const SizedBox(width: PlayModal.headerIconGap),
        titleStyle(title),
      ],
    );
  }

  /// Read-only tip row for the Tips page (icon + title + body).
  static Widget tipRow({
    required List<List<dynamic>> icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PlayModal.tilePadH,
        vertical: PlaySpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: HugeIcon(
              icon: icon,
              color: PlayColors.labelOn,
              size: PlayModal.tileIcon,
            ),
          ),
          const SizedBox(width: PlaySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: PlayModal.onSurface,
                    fontSize: PlayModal.tileTitleSize,
                    fontWeight: FontWeight.w600,
                    shadows: PlayModal.titleShadows,
                  ),
                ),
                const SizedBox(height: PlaySpacing.xs),
                Text(
                  body,
                  style: const TextStyle(
                    color: PlayModal.slotMeta,
                    fontSize: PlayModal.slotMetaSize,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
