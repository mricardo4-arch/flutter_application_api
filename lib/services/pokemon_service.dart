import 'package:dio/dio.dart';

import '../models/pokemon.dart';

class PokemonService {
  PokemonService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://pokeapi.co/api/v2/',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  Future<List<int>> fetchPokemonByType(String type) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'type/${type.toLowerCase().trim()}/',
    );
    final entries = response.data?['pokemon'] as List<dynamic>? ?? [];
    return entries.map((entry) {
      final pokemon =
          (entry as Map<String, dynamic>)['pokemon'] as Map<String, dynamic>;
      final uri = Uri.parse(pokemon['url'] as String);
      return int.parse(uri.pathSegments[uri.pathSegments.length - 2]);
    }).toList()..sort();
  }

  Future<Pokemon> fetchPokemonByName(String name) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'pokemon/${name.toLowerCase().trim()}/',
    );
    final data = response.data;
    if (data == null)
      throw const FormatException('No se encontró ese Pokémon.');
    final speciesUrl =
        (data['species'] as Map<String, dynamic>?)?['url'] as String?;
    var description = '';
    if (speciesUrl != null) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(speciesUrl);
        final entries =
            response.data?['flavor_text_entries'] as List<dynamic>? ?? [];
        final english = entries.cast<Map<String, dynamic>>().where(
          (e) => (e['language'] as Map<String, dynamic>?)?['name'] == 'en',
        );
        if (english.isNotEmpty)
          description = (english.first['flavor_text'] as String).replaceAll(
            RegExp(r'\s+'),
            ' ',
          );
      } on DioException {}
    }
    return Pokemon.fromJson(data, description: description);
  }

  Future<Pokemon> fetchPokemon([int id = 1]) async {
    final response = await _dio.get<Map<String, dynamic>>('pokemon/$id/');
    final data = response.data;
    if (data == null) {
      throw const FormatException('La API devolvió una respuesta vacía.');
    }

    final speciesUrl =
        (data['species'] as Map<String, dynamic>?)?['url'] as String?;
    var description = '';
    if (speciesUrl != null) {
      try {
        final speciesResponse = await _dio.get<Map<String, dynamic>>(
          speciesUrl,
        );
        final entries =
            speciesResponse.data?['flavor_text_entries'] as List<dynamic>? ??
            [];
        final english = entries.cast<Map<String, dynamic>>().where(
          (entry) =>
              (entry['language'] as Map<String, dynamic>?)?['name'] == 'en',
        );
        if (english.isNotEmpty) {
          description = (english.first['flavor_text'] as String).replaceAll(
            RegExp(r'\\s+'),
            ' ',
          );
        }
      } on DioException {
        // The main Pokémon record remains useful if species text is unavailable.
      }
    }
    return Pokemon.fromJson(data, description: description);
  }
}
