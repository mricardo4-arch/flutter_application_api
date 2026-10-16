# Consumo de PokeAPI con Flutter

Aplicación Flutter que obtiene los datos de Bulbasaur desde PokeAPI usando
Dio, convierte la respuesta JSON en un objeto `Pokemon` y muestra sus datos en
pantalla.

## Ejecutar

```bash
flutter pub get
flutter run
```

La aplicación consulta `https://pokeapi.co/api/v2/pokemon/1/`. Dio realiza la
petición en `lib/services/pokemon_service.dart`, y
`lib/models/pokemon.dart` convierte la respuesta a un modelo Dart. La pantalla
muestra el nombre, ilustración, tipos, altura, peso y habilidades; ante un error
de red permite volver a intentarlo.

El permiso de Internet para Android está declarado en
`android/app/src/main/AndroidManifest.xml`.

## Validar

```bash
flutter analyze
flutter test
```
