import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'dart:async';

import 'models/pokemon.dart';
import 'services/pokemon_service.dart';

void main() => runApp(const MyApp());

const _red = Color(0xFFEA48E8);
const _navy = Color(0xFF061A45);
const _panel = Color(0xFF0B3470);
const _blue = Color(0xFF20C8FF);

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pokédex',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _navy,
      colorScheme: const ColorScheme.dark(primary: _red, surface: _panel),
    ),
    home: const PokemonPage(),
  );
}

class PokemonPage extends StatefulWidget {
  const PokemonPage({super.key, this.service});
  final PokemonService? service;
  @override
  State<PokemonPage> createState() => _PokemonPageState();
}

class _PokemonPageState extends State<PokemonPage> {
  late final PokemonService _service = widget.service ?? PokemonService();
  late Future<Pokemon> _pokemon = _service.fetchPokemon();
  int _id = 1;
  final _searchController = TextEditingController();
  bool _searching = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _playingCry = false;
  int _layoutMode = 0; // 0: automático, 1: teléfono, 2: escritorio
  bool _shiny = false;
  Pokemon? _displayedPokemon;
  Pokemon? _hoveredPokemon;
  int? _hoveredPokemonId;
  Timer? _hoverTimer;
  Future<void> _playCryUrl(String url, {bool reportError = true}) async {
    if (mounted) setState(() => _playingCry = true);
    try {
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {
      if (mounted && reportError)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el sonido.')),
        );
    } finally {
      if (mounted) setState(() => _playingCry = false);
    }
  }

  String _homeSprite(Pokemon p) {
    final shiny = _shiny ? 'shiny/' : '';
    return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/$shiny${p.id}.png';
  }

  String _modelUrl(Pokemon p) {
    final variant = _shiny ? 'ani-shiny' : 'ani';
    return 'https://play.pokemonshowdown.com/sprites/$variant/${p.name.toLowerCase()}.gif';
  }

  Future<void> _playCryById(int id) => _playCryUrl(
    'https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/$id.ogg',
    reportError: false,
  );

  Future<void> _playCry(Pokemon p) => _playCryUrl(
    p.cryUrl.isNotEmpty
        ? p.cryUrl
        : 'https://play.pokemonshowdown.com/audio/cries/${p.name.toLowerCase()}.mp3',
  );

  void _onRailHover(int id, bool hovering) {
    _hoverTimer?.cancel();
    if (!hovering) {
      _hoverTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted || _hoveredPokemonId != id) return;
        setState(() {
          _hoveredPokemonId = null;
          _hoveredPokemon = null;
        });
      });
      return;
    }

    setState(() {
      _hoveredPokemonId = id;
      _hoveredPokemon = null;
    });
    _hoverTimer = Timer(const Duration(milliseconds: 220), () async {
      try {
        final pokemon = await _service.fetchPokemon(id);
        if (!mounted || _hoveredPokemonId != id) return;
        setState(() => _hoveredPokemon = pokemon);
      } catch (_) {
        // El icono sigue siendo utilizable aunque falle la ficha emergente.
      }
    });
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _search(String raw) async {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) return;
    if (int.tryParse(query) != null) {
      _select(int.parse(query));
      return;
    }
    const typeNames = {
      'normal',
      'fighting',
      'flying',
      'poison',
      'ground',
      'rock',
      'bug',
      'ghost',
      'steel',
      'fire',
      'water',
      'grass',
      'electric',
      'psychic',
      'ice',
      'dragon',
      'dark',
      'fairy',
    };
    if (!typeNames.contains(query)) {
      unawaited(
        _playCryUrl(
          'https://play.pokemonshowdown.com/audio/cries/$query.mp3',
          reportError: false,
        ),
      );
    }
    setState(() => _searching = true);
    try {
      final typeIds = await _service.fetchPokemonByType(query);
      if (!mounted) return;
      if (typeIds.isNotEmpty) {
        final chosen = await showModalBottomSheet<int>(
          context: context,
          backgroundColor: _navy,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Pokémon de tipo ${_cap(query)} (${typeIds.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: typeIds.length,
                      itemBuilder: (context, index) {
                        final id = typeIds[index];
                        return ListTile(
                          leading: Image.network(
                            'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png',
                            width: 48,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.catching_pokemon),
                          ),
                          title: Text('#${id.toString().padLeft(3, '0')}'),
                          onTap: () => Navigator.pop(context, id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (chosen != null) _select(chosen);
      } else {
        _selectByName(query);
      }
    } catch (_) {
      _selectByName(query);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectByName(String name) {
    _shiny = false;
    setState(
      () => _pokemon = _service.fetchPokemonByName(name).then((p) {
        _id = p.id;
        return p;
      }),
    );
  }

  void _select(int id) {
    if (id < 1 || id > 1025) return;
    unawaited(_playCryById(id));
    _shiny = false;
    setState(() {
      _id = id;
      _pokemon = _service.fetchPokemon(id);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          _header(),
          _searchBar(),
          Expanded(
            child: FutureBuilder<Pokemon>(
              future: _pokemon,
              builder: (context, snapshot) {
                if (snapshot.hasData) _displayedPokemon = snapshot.data;
                final pokemon = snapshot.data ?? _displayedPokemon;
                if (pokemon == null &&
                    snapshot.connectionState == ConnectionState.waiting)
                  return const Center(
                    child: CircularProgressIndicator(color: _red),
                  );
                if (pokemon == null && snapshot.hasError)
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No se pudieron cargar los datos.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => _select(_id),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                if (pokemon == null) return const SizedBox.shrink();
                return Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, box) =>
                            _dex(pokemon, box.maxWidth, box.maxHeight),
                      ),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Positioned(
                        top: 4,
                        right: 16,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _red,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          _footer(),
        ],
      ),
    ),
  );

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
    child: SizedBox(
      height: 46,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: _search,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, número o tipo (ej. Pikachu, 25, fuego)',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Buscar',
                  onPressed: () => _search(_searchController.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
          filled: true,
          fillColor: _panel,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _blue),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Container(
    height: 76,
    margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1476D4), _red, Color(0xFF7137D9)],
      ),
      border: Border.all(color: _red, width: 2),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.catching_pokemon, size: 48),
        const SizedBox(width: 12),
        const Text(
          'POKÉDEX',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        if (MediaQuery.sizeOf(context).width > 650) const Spacer(),
        if (MediaQuery.sizeOf(context).width > 650)
          const Text(
            'ATRAPA  ·  INVESTIGA  ·  COMPLETA',
            style: TextStyle(color: Colors.white70, letterSpacing: 1),
          ),
        IconButton(
          tooltip: _layoutMode == 0
              ? 'Vista automática'
              : _layoutMode == 1
              ? 'Vista teléfono'
              : 'Vista escritorio',
          onPressed: () => setState(() => _layoutMode = (_layoutMode + 1) % 3),
          icon: Icon(
            _layoutMode == 1
                ? Icons.phone_android
                : _layoutMode == 2
                ? Icons.desktop_windows
                : Icons.devices,
          ),
        ),
      ],
    ),
  );

  Widget _dex(Pokemon p, double width, double height) {
    final compact =
        _layoutMode == 1 || (_layoutMode == 0 && (width < 760 || height < 620));
    final railWidth = compact ? 68.0 : 104.0;
    final rail = SizedBox(width: railWidth, child: _pokemonRail());
    final detail = _details(p, compact);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              rail,
              Expanded(child: detail),
            ],
          ),
        ),
        if (_hoveredPokemon != null)
          Positioned(
            left: railWidth - 2,
            top: 28,
            child: IgnorePointer(child: _pokemonHoverCard(_hoveredPokemon!)),
          ),
      ],
    );
  }

  Widget _pokemonRail() => Container(
    margin: const EdgeInsets.only(left: 8, bottom: 8),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _red.withValues(alpha: .65)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(7),
          child: Text(
            '#${_id.toString().padLeft(3, '0')}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 1025,
            itemBuilder: (context, i) {
              final id = i + 1;
              final selected = id == _id;
              final image =
                  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                child: Material(
                  color: selected
                      ? _red.withValues(alpha: .25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _select(id),
                    borderRadius: BorderRadius.circular(12),
                    child: Tooltip(
                      message: 'Pokémon #${id.toString().padLeft(3, '0')}',
                      child: _RailPokemonPreview(
                        id: id,
                        imageUrl: image,
                        selected: selected,
                        onHover: (hovering) => _onRailHover(id, hovering),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _pokemonHoverCard(Pokemon pokemon) => Container(
    width: 245,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _navy.withValues(alpha: .97),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _blue, width: 1.5),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
    ),
    child: Row(
      children: [
        Image.network(
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png',
          width: 64,
          height: 64,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.catching_pokemon, size: 42),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#${pokemon.id.toString().padLeft(3, '0')} · ${_cap(pokemon.name)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: pokemon.types.map((type) => _tag(type)).toList(),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _details(Pokemon p, bool compact) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
    child: Column(
      children: [
        Expanded(
          child: compact
              ? ListView(
                  children: [
                    _hero(p, 270),
                    const SizedBox(height: 10),
                    _identity(p),
                    const SizedBox(height: 10),
                    _measurements(p),
                    const SizedBox(height: 10),
                    _stats(p),
                    const SizedBox(height: 10),
                    _abilities(p),
                    const SizedBox(height: 10),
                    SizedBox(height: 230, child: _moves(p)),
                    const SizedBox(height: 10),
                    _description(p),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          Expanded(child: _hero(p, double.infinity)),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: _stats(p)),
                                const SizedBox(width: 10),
                                Expanded(child: _abilities(p)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _identity(p),
                          const SizedBox(height: 10),
                          _measurements(p),
                          const SizedBox(height: 10),
                          Expanded(child: _description(p)),
                          const SizedBox(height: 10),
                          Expanded(child: _moves(p)),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: _id > 1 ? () => _select(_id - 1) : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Anterior'),
            ),
            OutlinedButton.icon(
              onPressed: _id < 1025 ? () => _select(_id + 1) : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Siguiente'),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _box({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_panel, Color(0xFF08131E)],
      ),
      border: Border.all(color: _blue, width: 1.3),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  String _habitat(Pokemon p) {
    if (p.types.length > 1) return 'assets/habitats/multi_type.png';
    final type = p.types.isEmpty ? null : p.types.first;
    if (type == 'water') return 'assets/habitats/ocean.png';
    if (type == 'fire') return 'assets/habitats/volcano.png';
    if (type == 'ice') return 'assets/habitats/arctic.png';
    if (type == 'ghost' || type == 'dark')
      return 'assets/habitats/night_ruins.png';
    if (type == 'electric' || type == 'poison')
      return 'assets/habitats/city.png';
    if (type == 'rock' || type == 'ground' || type == 'steel')
      return 'assets/habitats/cave.png';
    return 'assets/habitats/forest.png';
  }

  String _habitatName(Pokemon p) {
    final asset = _habitat(p);
    if (asset.endsWith('multi_type.png')) return 'Hábitat de tipos mixtos';
    if (asset.endsWith('night_ruins.png')) return 'Espacios nocturnos y ruinas';
    if (asset.endsWith('forest.png')) return 'Bosque y pradera';
    if (asset.endsWith('cave.png')) return 'Montañas y cuevas';
    if (asset.endsWith('ocean.png')) return 'Océanos, ríos y playas';
    if (asset.endsWith('volcano.png')) return 'Volcanes y zonas áridas';
    if (asset.endsWith('arctic.png')) return 'Árticos y tundras';
    return 'Ciudad nocturna y ruinas';
  }

  Widget _hero(Pokemon p, double height) => _box(
    padding: const EdgeInsets.all(8),
    child: InkWell(
      onTap: () => _showFullDetails(p),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(_habitat(p), fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF061A45).withValues(alpha: .28),
                          const Color(0xFF061A45).withValues(alpha: .78),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Image.network(
              _modelUrl(p),
              height: height == double.infinity ? null : height,
              width: double.infinity,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              frameBuilder: (context, child, frame, sync) =>
                  Transform.translate(
                    offset: const Offset(0, -4),
                    child: Transform.scale(scale: 1.08, child: child),
                  ),
              errorBuilder: (_, __, ___) => Image.network(
                _homeSprite(p),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.network(
                  p.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.catching_pokemon,
                    size: 150,
                    color: _red,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 4,
              children: [
                _modelChip(
                  'Normal',
                  !_shiny,
                  () => setState(() => _shiny = false),
                ),
                _modelChip(
                  'Shiny',
                  _shiny,
                  () => setState(() => _shiny = true),
                ),
              ],
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Text(
              'N.º ${p.id.toString().padLeft(3, '0')}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Positioned(
            left: 8,
            top: 38,
            child: Text(
              _habitatName(p),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 8)],
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: FilledButton.tonalIcon(
              onPressed: () => _playCry(p),
              icon: Icon(
                _playingCry ? Icons.volume_up : Icons.play_arrow,
                size: 18,
              ),
              label: const Text('Escuchar'),
              style: FilledButton.styleFrom(
                backgroundColor: _navy.withValues(alpha: .78),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _modelChip(String label, bool selected, VoidCallback onTap) =>
      ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        backgroundColor: _navy.withValues(alpha: .84),
        selectedColor: _red,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: selected ? _red : _blue.withValues(alpha: .8)),
      );

  Widget _identity(Pokemon p) => _box(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#${p.id.toString().padLeft(3, '0')}  ·  ${_cap(p.name)}',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          'Experiencia base: ${p.baseExperience}   ·   ${p.category}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 9),
        Wrap(spacing: 7, children: p.types.map(_tag).toList()),
      ],
    ),
  );
  Widget _measurements(Pokemon p) => _box(
    child: Row(
      children: [
        Expanded(
          child: _metric('ALTURA', '${(p.height / 10).toStringAsFixed(1)} m'),
        ),
        Expanded(
          child: _metric('PESO', '${(p.weight / 10).toStringAsFixed(1)} kg'),
        ),
      ],
    ),
  );
  Widget _metric(String title, String value) => Column(
    children: [
      Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ],
  );
  Color _statColor(String stat) => switch (stat) {
    'hp' => const Color(0xFFFF5B75),
    'attack' => const Color(0xFFFF9D42),
    'defense' => const Color(0xFF56D5A5),
    'special-attack' => const Color(0xFFAE83FF),
    'special-defense' => const Color(0xFF46C8D8),
    'speed' => const Color(0xFFFFD34E),
    _ => _blue,
  };

  String _statEmoji(String stat) => switch (stat) {
    'hp' => '❤️',
    'attack' => '⚔️',
    'defense' => '🛡️',
    'special-attack' => '✨',
    'special-defense' => '🔰',
    'speed' => '⚡',
    _ => '📊',
  };

  Widget _stats(Pokemon p) => _box(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estadísticas base',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 8),
        ...p.stats.entries.map((e) {
          final color = _statColor(e.key);
          final percentage = (e.value / 255).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_statEmoji(e.key)}  ${_cap(e.key.replaceAll('-', ' '))}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: Text(
                    '${e.value} · ${(percentage * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: percentage,
                      color: color,
                      backgroundColor: color.withValues(alpha: .2),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
  Widget _abilities(Pokemon p) => _box(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Habilidades',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 8),
        ...p.abilities.map(
          (a) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '›  ${_cap(a)}${p.hiddenAbilities.contains(a) ? ' (oculta)' : ''}',
            ),
          ),
        ),
      ],
    ),
  );
  Widget _moves(Pokemon p) => _box(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Movimientos (${p.moves.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: p.moves
                .map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('›  ${_cap(m.replaceAll('-', ' '))}'),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );
  Widget _description(Pokemon p) => _box(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descripción',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Text(
          p.description.isEmpty
              ? 'No hay descripción disponible en la API.'
              : p.description,
          style: const TextStyle(height: 1.45),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        const Divider(color: _blue),
        Text(
          'Especie: ${_cap(p.species)}',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );
  Color _typeColor(String type) => switch (type) {
    'normal' => const Color(0xFFA8A77A),
    'fire' => const Color(0xFFEE8130),
    'water' => const Color(0xFF6390F0),
    'electric' => const Color(0xFFF7D02C),
    'grass' => const Color(0xFF7AC74C),
    'ice' => const Color(0xFF96D9D6),
    'fighting' => const Color(0xFFC22E28),
    'poison' => const Color(0xFFA33EA1),
    'ground' => const Color(0xFFE2BF65),
    'flying' => const Color(0xFFA98FF3),
    'psychic' => const Color(0xFFF95587),
    'bug' => const Color(0xFFA6B91A),
    'rock' => const Color(0xFFB6A136),
    'ghost' => const Color(0xFF735797),
    'dragon' => const Color(0xFF6F35FC),
    'dark' => const Color(0xFF705746),
    'steel' => const Color(0xFFB7B7CE),
    'fairy' => const Color(0xFFD685AD),
    _ => _blue,
  };

  String _typeEmoji(String type) => switch (type) {
    'normal' => '⚪',
    'fire' => '🔥',
    'water' => '💧',
    'electric' => '⚡',
    'grass' => '🌿',
    'ice' => '❄️',
    'fighting' => '🥊',
    'poison' => '☠️',
    'ground' => '🌍',
    'flying' => '🪽',
    'psychic' => '🔮',
    'bug' => '🐛',
    'rock' => '🪨',
    'ghost' => '👻',
    'dragon' => '🐉',
    'dark' => '🌑',
    'steel' => '⚙️',
    'fairy' => '✨',
    _ => '🔹',
  };

  Widget _tag(String type) {
    final color = _typeColor(type);
    return Chip(
      label: Text('${_typeEmoji(type)} ${_cap(type)}'),
      backgroundColor: color.withValues(alpha: .2),
      side: BorderSide(color: color.withValues(alpha: .9)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _footer() => Container(
    height: 12,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF4B0912), _red, Color(0xFF4B0912)],
      ),
    ),
  );
  void _showFullDetails(Pokemon p) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _navy,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          _hero(p, 260),
          const SizedBox(height: 12),
          _identity(p),
          const SizedBox(height: 10),
          _measurements(p),
          const SizedBox(height: 10),
          _stats(p),
          const SizedBox(height: 10),
          _abilities(p),
          const SizedBox(height: 10),
          _description(p),
          const SizedBox(height: 10),
          SizedBox(height: 330, child: _moves(p)),
        ],
      ),
    ),
  );
}

String _cap(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

class _RailPokemonPreview extends StatefulWidget {
  const _RailPokemonPreview({
    required this.id,
    required this.imageUrl,
    required this.selected,
    required this.onHover,
  });

  final int id;
  final String imageUrl;
  final bool selected;
  final ValueChanged<bool> onHover;

  @override
  State<_RailPokemonPreview> createState() => _RailPokemonPreviewState();
}

class _RailPokemonPreviewState extends State<_RailPokemonPreview> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHover(value);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _setHovered(true),
    onExit: (_) => _setHovered(false),
    child: AnimatedScale(
      scale: _hovered ? 1.22 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: SizedBox(
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: _hovered || widget.selected ? .8 : .15,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.catching_pokemon,
                size: 28,
                color: widget.selected ? _red : _blue,
              ),
            ),
            Image.network(
              widget.imageUrl,
              height: 48,
              width: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.catching_pokemon, color: Colors.white54),
            ),
          ],
        ),
      ),
    ),
  );
}
