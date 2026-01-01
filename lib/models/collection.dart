/// Represents a group of words, which can be a study set or a game mode.
class Collection {
  final int? id;
  final String name;
  final bool isFavorite;
  final bool isGame;

  Collection({
    this.id,
    required this.name,
    this.isFavorite = false,
    this.isGame = false,
  });

  /// Converts the Collection object to a Map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_favorite': isFavorite ? 1 : 0,
      'is_game': isGame ? 1 : 0,
    };
  }

  /// Creates a Collection object from a Map.
  factory Collection.fromMap(Map<String, dynamic> map) {
    return Collection(
      id: map['id'],
      name: map['name'],
      isFavorite: map['is_favorite'] == 1,
      isGame: map['is_game'] == 1,
    );
  }
}