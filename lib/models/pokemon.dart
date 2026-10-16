class Pokemon {
  const Pokemon({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.imageUrl,
    this.cryUrl = '',
    required this.types,
    required this.abilities,
    this.stats = const {},
    this.moves = const [],
    this.baseExperience = 0,
    this.species = '',
    this.description = '',
    this.hiddenAbilities = const {},
  });

  final int id, height, weight, baseExperience;
  final String name, imageUrl, species, description, cryUrl;
  final List<String> types, moves;
  final List<String> abilities;
  final Set<String> hiddenAbilities;
  final Map<String, int> stats;

  factory Pokemon.fromJson(
    Map<String, dynamic> json, {
    String description = '',
  }) {
    final sprites = json['sprites'] as Map<String, dynamic>? ?? {};
    final other = sprites['other'] as Map<String, dynamic>?;
    final artwork = other?['official-artwork'] as Map<String, dynamic>?;
    final speciesEntry = json['species'] as Map<String, dynamic>? ?? {};
    final typeEntries = json['types'] as List<dynamic>? ?? [];
    final abilityEntries = json['abilities'] as List<dynamic>? ?? [];
    final statEntries = json['stats'] as List<dynamic>? ?? [];
    final moveEntries = json['moves'] as List<dynamic>? ?? [];
    return Pokemon(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'unknown',
      height: json['height'] as int? ?? 0,
      weight: json['weight'] as int? ?? 0,
      baseExperience: json['base_experience'] as int? ?? 0,
      species: speciesEntry['name'] as String? ?? '',
      description: description,
      imageUrl:
          artwork?['front_default'] as String? ??
          sprites['front_default'] as String? ??
          '',
      cryUrl:
          (json['cries'] as Map<String, dynamic>?)?['latest'] as String? ?? '',
      types: typeEntries
          .map(
            (e) =>
                ((e as Map<String, dynamic>)['type']
                        as Map<String, dynamic>)['name']
                    as String,
          )
          .toList(growable: false),
      abilities: abilityEntries
          .map((e) {
            final entry = e as Map<String, dynamic>;
            final ability = entry['ability'] as Map<String, dynamic>;
            return ability['name'] as String;
          })
          .toList(growable: false),
      hiddenAbilities: abilityEntries
          .where((e) => (e as Map<String, dynamic>)['is_hidden'] == true)
          .map(
            (e) =>
                (((e as Map<String, dynamic>)['ability']
                        as Map<String, dynamic>)['name']
                    as String),
          )
          .toSet(),
      stats: {
        for (final e in statEntries)
          ((e as Map<String, dynamic>)['stat'] as Map<String, dynamic>)['name']
                  as String:
              e['base_stat'] as int,
      },
      moves: moveEntries
          .map(
            (e) =>
                ((e as Map<String, dynamic>)['move']
                        as Map<String, dynamic>)['name']
                    as String,
          )
          .toList(growable: false),
    );
  }

  String get category => species;
}
