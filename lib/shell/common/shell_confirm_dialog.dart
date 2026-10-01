import 'package:flutter/material.dart';

import '../theme/home_tokens.dart';
import '../theme/play_tokens.dart';

/// Home-styled confirm dialog (landscape-friendly max width).
///
/// Returns `true` when the user confirms, `false`/`null` otherwise.
Future<bool?> showShellConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) {
  final confirmColor = destructive ? HomeColors.missing : HomeColors.lemon;

  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: PlayModal.surface,
        constraints: const BoxConstraints(
          maxWidth: HomeSizes.confirmDialogMaxWidth,
        ),
        insetPadding: HomeSizes.confirmDialogInset,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: HomeSizes.headerTitleSize,
            color: HomeColors.cream,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: HomeSizes.formBodySize,
            color: HomeColors.labelOn,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              cancelLabel,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                fontSize: HomeSizes.sheetActionSize,
                color: HomeColors.labelDim,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: HomeSizes.sheetActionSize,
                color: confirmColor,
              ),
            ),
          ),
        ],
      );
    },
  );
}
