import 'package:flutter/material.dart';

const defaultItemIconKey = 'default';

class ItemIconOption {
  const ItemIconOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
}

const itemIconOptions = <ItemIconOption>[
  ItemIconOption(
    key: defaultItemIconKey,
    label: 'Domyślna',
    icon: Icons.shopping_basket_outlined,
    color: Color(0xFF1B8A5A),
    backgroundColor: Color(0x1A1B8A5A),
  ),
  ItemIconOption(
    key: 'eggs',
    label: 'Nabiał',
    icon: Icons.egg_outlined,
    color: Color(0xFFF2A900),
    backgroundColor: Color(0x1AF2A900),
  ),
  ItemIconOption(
    key: 'vegetables',
    label: 'Warzywa',
    icon: Icons.eco_outlined,
    color: Color(0xFF2E7D32),
    backgroundColor: Color(0x1A2E7D32),
  ),
  ItemIconOption(
    key: 'bread',
    label: 'Pieczywo',
    icon: Icons.bakery_dining_outlined,
    color: Color(0xFFB36B2C),
    backgroundColor: Color(0x1AB36B2C),
  ),
  ItemIconOption(
    key: 'meat',
    label: 'Wędliny',
    icon: Icons.lunch_dining_outlined,
    color: Color(0xFFD1495B),
    backgroundColor: Color(0x1AD1495B),
  ),
  ItemIconOption(
    key: 'beer',
    label: 'Piwo',
    icon: Icons.sports_bar_outlined,
    color: Color(0xFFE67E22),
    backgroundColor: Color(0x1AE67E22),
  ),
  ItemIconOption(
    key: 'toiletPaper',
    label: 'Papier toaletowy',
    icon: Icons.wc_outlined,
    color: Color(0xFF607D8B),
    backgroundColor: Color(0x1A607D8B),
  ),
  ItemIconOption(
    key: 'cleaningSpray',
    label: 'Chemia',
    icon: Icons.cleaning_services_outlined,
    color: Color(0xFF00A6C2),
    backgroundColor: Color(0x1A00A6C2),
  ),
];

ItemIconOption itemIconOptionForKey(String? key) {
  return itemIconOptions.firstWhere(
    (option) => option.key == key,
    orElse: () => itemIconOptions.first,
  );
}

Widget buildItemIconBadge(ItemIconOption option, {double size = 36}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: option.backgroundColor,
      borderRadius: BorderRadius.circular(size * 0.28),
    ),
    child: Icon(
      option.icon,
      color: option.color,
      size: size * 0.56,
    ),
  );
}
