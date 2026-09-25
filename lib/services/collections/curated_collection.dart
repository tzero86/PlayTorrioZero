enum CuratedKind { era, saga }

class CuratedItem {
  final String imdbId;
  final String title;
  final int year;

  const CuratedItem({
    required this.imdbId,
    required this.title,
    required this.year,
  });
}

class CuratedCollection {
  final String id;
  final String title;
  final String subtitle;
  final CuratedKind kind;
  final List<CuratedItem> items;

  const CuratedCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.items,
  });

  int get count => items.length;
}
