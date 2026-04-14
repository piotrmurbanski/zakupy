export const defaultItemIconKey = 'default';

export const itemIconKeys = [
  defaultItemIconKey,
  'sweetsSnacks',
  'clothes',
  'vege',
  'drinks',
  'cleaning',
  'produce',
  'stationery',
  'baking',
  'bread',
  'seasonings',
  'fishSeafood',
  'dryGoods',
  'hygiene',
  'coffeeTea',
  'cannedGoods',
  'meat',
  'frozen',
  'dairyEggs',
  'alcohol',
  'pharmacy',
  'readyMeals',
  'pets',
  'homeGarden',
  'child',
  'electronics'
] as const;

const itemIconKeyAliases = {
  eggs: 'dairyEggs',
  vegetables: 'produce',
  bread: 'bread',
  meat: 'meat',
  beer: 'alcohol',
  toiletPaper: 'hygiene',
  cleaningSpray: 'cleaning'
} as const;

export function normalizeItemIconKey(key: string | null | undefined): string {
  if (key == null) {
    return defaultItemIconKey;
  }

  const trimmed = key.trim();

  if (trimmed.length === 0) {
    return defaultItemIconKey;
  }

  return itemIconKeyAliases[trimmed as keyof typeof itemIconKeyAliases] ?? trimmed;
}
