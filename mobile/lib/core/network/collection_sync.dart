T upsertById<T>({
  required List<T> target,
  required T value,
  required String Function(T item) idOf,
}) {
  final nextId = idOf(value);
  final existingIndex = target.indexWhere((item) => idOf(item) == nextId);

  if (existingIndex == -1) {
    target.add(value);
    return value;
  }

  target[existingIndex] = value;
  return value;
}

bool removeById<T>({
  required List<T> target,
  required String id,
  required String Function(T item) idOf,
}) {
  final existingIndex = target.indexWhere((item) => idOf(item) == id);

  if (existingIndex == -1) {
    return false;
  }

  target.removeAt(existingIndex);
  return true;
}
