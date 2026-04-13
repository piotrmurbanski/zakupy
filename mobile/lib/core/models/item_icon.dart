import 'package:flutter/material.dart';

const defaultItemIconKey = 'default';

class ItemIconOption {
  const ItemIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const itemIconOptions = <ItemIconOption>[
  ItemIconOption(
    key: defaultItemIconKey,
    label: 'Domyślna',
    icon: Icons.shopping_basket_outlined,
  ),
  ItemIconOption(key: 'eggs', label: 'Nabiał', icon: Icons.egg_outlined),
  ItemIconOption(
    key: 'bread',
    label: 'Pieczywo',
    icon: Icons.bakery_dining_outlined,
  ),
  ItemIconOption(
    key: 'meat',
    label: 'Wędliny',
    icon: Icons.lunch_dining_outlined,
  ),
  ItemIconOption(
    key: 'beer',
    label: 'Piwo',
    icon: Icons.sports_bar_outlined,
  ),
  ItemIconOption(
    key: 'toiletPaper',
    label: 'Papier toaletowy',
    icon: Icons.wc_outlined,
  ),
  ItemIconOption(
    key: 'cleaningSpray',
    label: 'Chemia',
    icon: Icons.cleaning_services_outlined,
  ),
];

ItemIconOption itemIconOptionForKey(String? key) {
  return itemIconOptions.firstWhere(
    (option) => option.key == key,
    orElse: () => itemIconOptions.first,
  );
}
