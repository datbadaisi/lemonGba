import 'package:flutter/material.dart';

import '../theme/home_tokens.dart';

/// Horizontal shelf row (optional section label).
class GameRow extends StatelessWidget {
  const GameRow({
    super.key,
    required this.tileHeight,
    required this.children,
    this.label,
    this.controller,
  });

  /// When null/empty, no section title is shown.
  final String? label;
  final double tileHeight;
  final List<Widget> children;

  /// Optional; home uses this to jump back to the start after play / add.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    // Square cover + title under tile.
    final rowHeight = tileHeight + HomeSizes.tileTitleBlock;
    final showLabel = label != null && label!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeSpacing.screenPadH,
            ),
            child: Text(
              label!.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: HomeSizes.sectionLabelSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: HomeColors.labelDim,
              ),
            ),
          ),
          const SizedBox(height: HomeSpacing.rowLabelGap),
        ],
        SizedBox(
          height: rowHeight,
          // Full-width horizontal ListView (no shrinkWrap) so ScrollController
          // can reliably jump/animate back to the start after add / play.
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: HomeSpacing.screenPadH,
            ),
            itemCount: children.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: HomeSpacing.tileGap),
            itemBuilder: (context, i) =>
                SizedBox(height: rowHeight, child: children[i]),
          ),
        ),
      ],
    );
  }
}
