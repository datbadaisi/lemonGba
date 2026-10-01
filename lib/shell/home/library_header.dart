import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../models/game_group.dart';
import '../theme/home_tokens.dart';

/// Header: back · scrollable All/group chips · action buttons (right).
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    super.key,
    required this.groups,
    required this.selectedGroupId,
    required this.onBack,
    required this.onSelectAll,
    required this.onSelectGroup,
    required this.onCreateGroup,
    required this.onAddGames,
    this.onGroupOptions,
  });

  final List<GameGroup> groups;
  final String? selectedGroupId;
  final VoidCallback onBack;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onSelectGroup;
  final VoidCallback onCreateGroup;
  final VoidCallback onAddGames;
  final VoidCallback? onGroupOptions;

  @override
  Widget build(BuildContext context) {
    final viewingGroup = selectedGroupId != null;

    return Material(
      color: HomeColors.bg,
      child: SizedBox(
        height: HomeSpacing.topBarHeight,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: HomeColors.cream,
              ),
            ),
            const Text(
              'Library',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: HomeSizes.headerTitleSize,
                color: HomeColors.cream,
              ),
            ),
            const SizedBox(width: HomeSpacing.md),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: HomeSpacing.xs),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _GroupChip(
                            label: 'All',
                            selected: selectedGroupId == null,
                            onTap: onSelectAll,
                          ),
                          for (final g in groups) ...[
                            const SizedBox(width: HomeSpacing.sm),
                            _GroupChip(
                              label: g.name,
                              count: g.gameCount,
                              selected: selectedGroupId == g.id,
                              onTap: () => onSelectGroup(g.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (viewingGroup) ...[
              IconButton(
                tooltip: 'Add games',
                onPressed: onAddGames,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedPlusSign,
                  size: HomeSizes.sheetHeaderIconSize,
                  color: HomeColors.lemon,
                ),
              ),
              if (onGroupOptions != null)
                IconButton(
                  tooltip: 'Group options',
                  onPressed: onGroupOptions,
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreVertical,
                    size: HomeSizes.sheetHeaderIconSize,
                    color: HomeColors.cream,
                  ),
                ),
            ] else
              IconButton(
                tooltip: 'New group',
                onPressed: onCreateGroup,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedFolderAdd,
                  size: HomeSizes.sheetHeaderIconSize,
                  color: HomeColors.lemon,
                ),
              ),
            const SizedBox(width: HomeSpacing.xs),
          ],
        ),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final border = selected ? HomeColors.lemon : HomeColors.tileBorder;
    final bg = selected
        ? HomeColors.lemon.withValues(alpha: 0.14)
        : HomeColors.tileFace;
    final fg = selected ? HomeColors.lemon : HomeColors.labelOn;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeSizes.chipRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(HomeSizes.chipRadius),
            border: Border.all(color: border, width: selected ? 1.5 : 1),
          ),
          child: Padding(
            padding: HomeSizes.chipPad,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: HomeSizes.chipLabelSize,
                    color: fg,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: HomeSpacing.sm - 2),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      fontSize: HomeSizes.chipCountSize,
                      color: selected
                          ? HomeColors.lemon.withValues(alpha: 0.85)
                          : HomeColors.labelDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
