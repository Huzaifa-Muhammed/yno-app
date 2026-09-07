import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'buttons.dart';

/// The app's one yes/no confirmation. Returns true only if the user confirmed —
/// dismissing by tapping outside counts as "no".
///
/// [danger] is the destructive-action convention (see [kDangerColor]) and is a
/// SEPARATE axis from confirming: an action can be worth a confirmation without
/// losing data (regenerating a code), and those keep the default green.
///
/// For anything heavier than this — deleting a team, wiping an account — use a
/// stronger gate (type-the-name, countdown) rather than just this dialog.
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line2, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppText.condensed(size: 22, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                style:
                    AppText.barlow(size: 14, color: AppColors.dim, height: 1.45)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: tr('common.cancel'),
                    height: 46,
                    fontSize: 16,
                    onTap: () => Navigator.pop(dialogCtx, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: confirmLabel,
                    height: 46,
                    fontSize: 16,
                    danger: danger,
                    onTap: () => Navigator.pop(dialogCtx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
