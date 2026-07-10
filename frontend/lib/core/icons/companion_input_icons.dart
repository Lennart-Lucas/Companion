import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Icons for input-related navigation (registered in [setupCompanionIcons]).
const IconSet companionInputIcons = IconSet(
  categories: [
    IconCategory(name: 'Inputs', sequence: 6),
  ],
  entries: [
    IconEntry(
      name: 'Clapperboard',
      data: FontAwesomeIcons.clapperboard,
      category: 'Inputs',
      sequence: 0,
      tags: ['clapperboard', 'movie', 'cinema', 'film', 'tv', 'media'],
    ),
    IconEntry(
      name: 'Film',
      data: FontAwesomeIcons.film,
      category: 'Inputs',
      sequence: 1,
      tags: ['film', 'movie', 'cinema', 'video', 'media'],
    ),
  ],
);
