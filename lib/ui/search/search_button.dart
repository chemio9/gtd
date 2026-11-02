import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'search_page.dart';

/// Search icon used in the page app bars.
class SearchButton extends StatelessWidget {
  const SearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.search,
      icon: const Icon(Icons.search),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SearchPage()),
      ),
    );
  }
}
