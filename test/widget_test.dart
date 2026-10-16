import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_api/main.dart';
import 'package:flutter_application_api/models/pokemon.dart';
import 'package:flutter_application_api/services/pokemon_service.dart';

void main() {
  test('convierte el JSON de PokeAPI en un Pokémon', () {
    final pokemon = Pokemon.fromJson({
      'id': 1,
      'name': 'bulbasaur',
      'height': 7,
      'weight': 69,
      'sprites': {
        'front_default': 'https://example.com/sprite.png',
        'other': {
          'official-artwork': {
            'front_default': 'https://example.com/artwork.png',
          },
        },
      },
      'types': [
        {
          'type': {'name': 'grass'},
        },
        {
          'type': {'name': 'poison'},
        },
      ],
      'abilities': [
        {
          'ability': {'name': 'overgrow'},
        },
      ],
    });

    expect(pokemon.id, 1);
    expect(pokemon.name, 'bulbasaur');
    expect(pokemon.imageUrl, 'https://example.com/artwork.png');
    expect(pokemon.types, ['grass', 'poison']);
    expect(pokemon.abilities, ['overgrow']);
  });

  testWidgets('muestra los datos del Pokémon recibido', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PokemonPage(service: _FakePokemonService(_pikachu))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pikachu'), findsOneWidget);
    expect(find.text('Electric'), findsOneWidget);
    expect(find.text('6.0 kg'), findsOneWidget);
    expect(find.text('Static'), findsOneWidget);
  });

  testWidgets('permite reintentar cuando falla la petición', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PokemonPage(service: _FailingPokemonService())),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar los datos.'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
  });
}

const _pikachu = Pokemon(
  id: 25,
  name: 'pikachu',
  height: 4,
  weight: 60,
  imageUrl: '',
  types: ['electric'],
  abilities: ['static'],
);

class _FakePokemonService extends PokemonService {
  _FakePokemonService(this.pokemon);

  final Pokemon pokemon;

  @override
  Future<Pokemon> fetchPokemon([int id = 1]) async => pokemon;
}

class _FailingPokemonService extends PokemonService {
  @override
  Future<Pokemon> fetchPokemon([int id = 1]) async {
    throw Exception('Fallo de prueba');
  }
}
