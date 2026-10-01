import 'package:flutter/material.dart';

import '../theme/home_tokens.dart';

/// Shared sub-page header: back + title + optional trailing action.
///
/// Used by Settings, Licenses, Display settings, and any future home form.
class ShellPageHeader extends StatelessWidget {
  const ShellPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeSpacing.topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HomeSpacing.screenPadH - HomeSpacing.sm,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack ?? () => Navigator.maybePop(context),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: HomeColors.cream,
              ),
            ),
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
    );
  }
}
