import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../common/text_prompt_dialog.dart';

/// Asks for a subtask title (multi-line, prefilled when editing).
Future<String?> promptSubtaskTitle(
  BuildContext context, {
  String? initialValue,
}) {
  return showTextPrompt(
    context,
    title: context.l10n.subtaskEdit,
    label: context.l10n.title,
    initialValue: initialValue,
    maxLines: 3,
  );
}
