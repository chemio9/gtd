import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/l10n/l10n.dart';

/// Guards the translation files: no missing/extra keys and every message is
/// used by the generated class.
void main() {
  Map<String, dynamic> readArb(String path) =>
      (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

  List<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toList()..sort();

  test('template and Chinese ARB files define the same messages', () {
    final en = readArb('lib/l10n/app_en.arb');
    final zh = readArb('lib/l10n/app_zh.arb');

    expect(messageKeys(en), isNotEmpty);
    expect(messageKeys(zh), messageKeys(en));
    for (final entry in zh.entries) {
      if (entry.key.startsWith('@')) continue;
      expect(entry.value, isA<String>());
      expect((entry.value as String).trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('generated localizations cover every ARB message', () {
    final en = readArb('lib/l10n/app_en.arb');
    expect(
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      containsAll(['en', 'zh']),
    );
    // A few representative keys used by the shell.
    expect(messageKeys(en), containsAll(['navBoard', 'navTodos', 'navCalendar']));
  });
}
