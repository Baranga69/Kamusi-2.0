enum FavoriteKind { lexeme, expression }

class FavoriteItem {
  FavoriteItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final FavoriteKind kind;
  final String title;
  final String subtitle;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'title': title,
      'subtitle': subtitle,
    };
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    final kindName = (json['kind'] ?? '').toString();
    return FavoriteItem(
      id: (json['id'] ?? '').toString(),
      kind: FavoriteKind.values.firstWhere(
        (value) => value.name == kindName,
        orElse: () => FavoriteKind.lexeme,
      ),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
    );
  }
}
