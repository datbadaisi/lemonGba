import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/home_tokens.dart';

/// Empty library / empty group placeholder for the full library grid.
class EmptyLibraryBody extends StatelessWidget {
  const EmptyLibraryBody({
    super.key,
    required this.isGroup,
    this.groupName,
  });

  final bool isGroup;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final title = isGroup
        ? (groupName == null ? 'Empty group' : '“$groupName” is empty')
        : 'No games yet';
    final subtitle = isGroup
        ? 'Use + in the header to add games to this group.'
        : 'Import a ROM or a Lemon pack from the home screen.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HomeSizes.emptyPadH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: isGroup
                  ? HugeIcons.strokeRoundedFolder01
                  : HugeIcons.strokeRoundedGameController01,
              size: HomeSizes.emptyIconSize,
              color: HomeColors.labelDim,
            ),
            const SizedBox(height: HomeSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: HomeSizes.emptyTitleSize,
                color: HomeColors.cream,
              ),
            ),
            const SizedBox(height: HomeSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: HomeSizes.emptyBodySize,
                color: HomeColors.labelDim,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
