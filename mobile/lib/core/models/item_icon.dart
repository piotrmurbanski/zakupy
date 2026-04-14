import 'package:flutter/material.dart';

const defaultItemIconKey = 'default';

class ItemIconOption {
  const ItemIconOption({
    required this.key,
    required this.label,
    required this.glyph,
    required this.color,
    required this.backgroundColor,
  });

  final String key;
  final String label;
  final String glyph;
  final Color color;
  final Color backgroundColor;
}

const itemIconOptions = <ItemIconOption>[
  ItemIconOption(
    key: defaultItemIconKey,
    label: 'Inne',
    glyph: '🏷️',
    color: Color(0xFFE0B64B),
    backgroundColor: Color(0x1AE0B64B),
  ),
  ItemIconOption(
    key: 'sweetsSnacks',
    label: 'Słodycze i przekąski',
    glyph: '🍬',
    color: Color(0xFFE8A63A),
    backgroundColor: Color(0x1AE8A63A),
  ),
  ItemIconOption(
    key: 'clothes',
    label: 'Ubrania',
    glyph: '👕',
    color: Color(0xFF6BCF5C),
    backgroundColor: Color(0x1A6BCF5C),
  ),
  ItemIconOption(
    key: 'vege',
    label: 'Wege',
    glyph: '🌱',
    color: Color(0xFFA7C93B),
    backgroundColor: Color(0x1AA7C93B),
  ),
  ItemIconOption(
    key: 'drinks',
    label: 'Woda i napoje',
    glyph: '🍼',
    color: Color(0xFF7DBDE8),
    backgroundColor: Color(0x1A7DBDE8),
  ),
  ItemIconOption(
    key: 'cleaning',
    label: 'Środki czystości',
    glyph: '🧴',
    color: Color(0xFF52BFA8),
    backgroundColor: Color(0x1A52BFA8),
  ),
  ItemIconOption(
    key: 'produce',
    label: 'Owoce, warzywa i zioła',
    glyph: '🍎',
    color: Color(0xFFF25A2C),
    backgroundColor: Color(0x1AF25A2C),
  ),
  ItemIconOption(
    key: 'stationery',
    label: 'Papiernicze',
    glyph: '✏️',
    color: Color(0xFFF0C44C),
    backgroundColor: Color(0x1AF0C44C),
  ),
  ItemIconOption(
    key: 'baking',
    label: 'Pieczenie i dodatki',
    glyph: '🥧',
    color: Color(0xFFF6C08F),
    backgroundColor: Color(0x1AF6C08F),
  ),
  ItemIconOption(
    key: 'bread',
    label: 'Pieczywo',
    glyph: '🥖',
    color: Color(0xFFDEB47A),
    backgroundColor: Color(0x1ADEB47A),
  ),
  ItemIconOption(
    key: 'seasonings',
    label: 'Przyprawy, sosy i oleje',
    glyph: '🌶️',
    color: Color(0xFFE34B3B),
    backgroundColor: Color(0x1AE34B3B),
  ),
  ItemIconOption(
    key: 'fishSeafood',
    label: 'Ryby i owoce morza',
    glyph: '🐟',
    color: Color(0xFF69A9F0),
    backgroundColor: Color(0x1A69A9F0),
  ),
  ItemIconOption(
    key: 'dryGoods',
    label: 'Sypkie',
    glyph: '🌾',
    color: Color(0xFFF0B44C),
    backgroundColor: Color(0x1AF0B44C),
  ),
  ItemIconOption(
    key: 'hygiene',
    label: 'Higiena',
    glyph: '🧼',
    color: Color(0xFFCE6BF2),
    backgroundColor: Color(0x1ACE6BF2),
  ),
  ItemIconOption(
    key: 'coffeeTea',
    label: 'Kawa i herbata',
    glyph: '☕',
    color: Color(0xFFB8743B),
    backgroundColor: Color(0x1AB8743B),
  ),
  ItemIconOption(
    key: 'cannedGoods',
    label: 'Konserwy i przetwory',
    glyph: '🫙',
    color: Color(0xFFD96B78),
    backgroundColor: Color(0x1AD96B78),
  ),
  ItemIconOption(
    key: 'meat',
    label: 'Mięso i wędliny',
    glyph: '🥩',
    color: Color(0xFFE55E7A),
    backgroundColor: Color(0x1AE55E7A),
  ),
  ItemIconOption(
    key: 'frozen',
    label: 'Mrożonki',
    glyph: '🧊',
    color: Color(0xFF6BB6FF),
    backgroundColor: Color(0x1A6BB6FF),
  ),
  ItemIconOption(
    key: 'dairyEggs',
    label: 'Nabiał i jaja',
    glyph: '🥚',
    color: Color(0xFFF3B847),
    backgroundColor: Color(0x1AF3B847),
  ),
  ItemIconOption(
    key: 'alcohol',
    label: 'Alkohole',
    glyph: '🍷',
    color: Color(0xFFB74C4C),
    backgroundColor: Color(0x1AB74C4C),
  ),
  ItemIconOption(
    key: 'pharmacy',
    label: 'Apteczka',
    glyph: '💗',
    color: Color(0xFFE63B72),
    backgroundColor: Color(0x1AE63B72),
  ),
  ItemIconOption(
    key: 'readyMeals',
    label: 'Dania gotowe',
    glyph: '🍽️',
    color: Color(0xFF4E79D9),
    backgroundColor: Color(0x1A4E79D9),
  ),
  ItemIconOption(
    key: 'pets',
    label: 'Dla zwierząt',
    glyph: '🐾',
    color: Color(0xFFB77B45),
    backgroundColor: Color(0x1AB77B45),
  ),
  ItemIconOption(
    key: 'homeGarden',
    label: 'Dom i ogród',
    glyph: '🏡',
    color: Color(0xFF7CCF66),
    backgroundColor: Color(0x1A7CCF66),
  ),
  ItemIconOption(
    key: 'child',
    label: 'Dziecko',
    glyph: '🍼',
    color: Color(0xFFB16AF5),
    backgroundColor: Color(0x1AB16AF5),
  ),
  ItemIconOption(
    key: 'electronics',
    label: 'Elektronika',
    glyph: '💻',
    color: Color(0xFF79858D),
    backgroundColor: Color(0x1A79858D),
  ),
];

const _itemIconKeyAliases = <String, String>{
  'eggs': 'dairyEggs',
  'vegetables': 'produce',
  'bread': 'bread',
  'meat': 'meat',
  'beer': 'alcohol',
  'toiletPaper': 'hygiene',
  'cleaningSpray': 'cleaning',
};

ItemIconOption itemIconOptionForKey(String? key) {
  final normalizedKey = _itemIconKeyAliases[key] ?? key;

  return itemIconOptions.firstWhere(
    (option) => option.key == normalizedKey,
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
    alignment: Alignment.center,
    child: Text(
      option.glyph,
      style: TextStyle(fontSize: size * 0.52, height: 1, color: option.color),
    ),
  );
}
