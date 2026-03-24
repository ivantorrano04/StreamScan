import 'dart:async';
import 'dart:ui';
// dart:io removed to avoid unresolved symbol on some platforms
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/camera_model.dart';
import 'services/data_loader.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final v = await _storage.read(key: 'app_theme_mode');
      if (v == 'light') setState(() => _themeMode = ThemeMode.light);
      else setState(() => _themeMode = ThemeMode.dark);
    } catch (_) {}
  }

  Future<void> _toggleTheme() async {
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() => _themeMode = next);
    try { await _storage.write(key: 'app_theme_mode', value: next == ThemeMode.dark ? 'dark' : 'light'); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light);
    final darkScheme = ColorScheme.fromSeed(seedColor: Colors.tealAccent, brightness: Brightness.dark);

    return MaterialApp(
      title: 'Cams Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F7F8),
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 15, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 13, color: Colors.black87),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0F2F3),
          prefixIconColor: lightScheme.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: lightScheme.primary, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18))),
        cardTheme: CardThemeData(color: const Color(0xFFFFFFFF), elevation: 4, margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        listTileTheme: ListTileThemeData(textColor: Colors.black87, iconColor: lightScheme.primary, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: const Color(0xFF071018),
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 15, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B1416),
          prefixIconColor: darkScheme.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: darkScheme.primary, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18))),
        cardTheme: CardThemeData(color: const Color(0xFF0E1A1C), elevation: 6, margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        listTileTheme: ListTileThemeData(textColor: Colors.white, iconColor: darkScheme.primary, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      ),
      themeMode: _themeMode,
      home: MainDashboard(onToggleTheme: _toggleTheme, themeMode: _themeMode),
      debugShowCheckedModeBanner: false,
    );
  }

  
}

// Top-level native fallback widget (replaces MyApp-local helper)
class NativeFallbackWidget extends StatelessWidget {
  final String url;
  const NativeFallbackWidget({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final lower = url.toLowerCase();
    final isImage = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.contains('snapshot') || lower.contains('image');

    if (isImage) {
      return Center(child: Image.network(url, fit: BoxFit.contain));
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.public, size: 48, color: Colors.white70),
          const SizedBox(height: 8),
          const Text('Vista web no soportada internamente', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              try {
                final uri = Uri.parse(url);
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el navegador')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Abrir en navegador'),
          ),
        ]),
      ),
    );
  }
}

// MJPEG widget using `flutter_mjpeg` package (renders native MJPEG stream)
class MJpegWidget extends StatelessWidget {
  final String url;
  final String? user;
  final String? pass;
  const MJpegWidget({super.key, required this.url, this.user, this.pass});

  @override
  Widget build(BuildContext context) {
    // Build headers if basic auth provided
    final headers = <String, String>{};
    if (user != null && pass != null) {
      final cred = base64.encode(utf8.encode('${user!}:${pass!}'));
      headers['Authorization'] = 'Basic $cred';
    }

    return Mjpeg(
      stream: url,
      isLive: true,
      // Error builder: show icon + button to open in external browser
      error: (context, error, stack) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                try {
                  final uri = Uri.parse(url);
                  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el navegador')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Abrir en navegador'),
            ),
          ]),
        );
      },
      headers: headers,
      fit: BoxFit.contain,
    );
  }
}

class MainDashboard extends StatefulWidget {
  final Future<void> Function()? onToggleTheme;
  final ThemeMode? themeMode;
  const MainDashboard({super.key, this.onToggleTheme, this.themeMode});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;
  final MapController _mapController = MapController();
  List<CameraInfo> _cameras = [];
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  // store favorites as map url -> custom name
  Map<String, String> _favorites = {}; // url -> name
  String _filter = '';
  late final TextEditingController _searchController;
  bool _loading = true;
  String? _loadError;

  static const String assetPath = 'assets/cams_con_info.json';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _filter);
    _searchController.addListener(() {
      if (_filter != _searchController.text) setState(() => _filter = _searchController.text);
    });
    _loadCameras();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCameras() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await DataLoader.loadFromAssets(assetPath);
      // load favorites then update
      _cameras = list;
      await _loadFavorites();
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final raw = await _storage.read(key: 'cam_favorites');
      if (raw != null && raw.isNotEmpty) {
        final data = json.decode(raw);
        // support legacy format (list of urls) and new format (list of {url,name})
        if (data is List) {
          final Map<String, String> map = {};
          for (var item in data) {
            if (item is String) map[item] = '';
            else if (item is Map) {
              final url = item['url']?.toString() ?? '';
              final name = item['name']?.toString() ?? '';
              if (url.isNotEmpty) map[url] = name;
            }
          }
          _favorites = map;
        } else {
          _favorites = {};
        }
      } else {
        _favorites = {};
      }
    } catch (_) {
      _favorites = {};
    }
  }

  Future<void> _saveFavorites() async {
    try {
      // store as list of objects for future extensibility
      final raw = json.encode(_favorites.entries.map((e) => {'url': e.key, 'name': e.value}).toList());
      await _storage.write(key: 'cam_favorites', value: raw);
    } catch (_) {}
  }

  Future<void> _clearFavorites() async {
    try {
      _favorites.clear();
      await _saveFavorites();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _toggleFavorite(CameraInfo cam) async {
    final id = cam.url;
    if (_favorites.containsKey(id)) {
      _favorites.remove(id);
      await _saveFavorites();
      setState(() {});
      return;
    }

    // Ask user for a name when adding to favorites
    final defaultName = cam.info?.city ?? cam.info?.isp ?? cam.url;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: defaultName);
        return AlertDialog(
          title: const Text('Nombre para favorito'),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Nombre visible')),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (name == null) return; // cancelled
    if (!mounted) return;
    _favorites[id] = name;
    await _saveFavorites();
    setState(() {});

    // Close camera details modal if open and go to map focusing this camera
    try {
      Navigator.of(context).pop(); // close bottom sheet (if present)
    } catch (_) {}
    _focusOnCamera(cam);
  }

  List<CameraInfo> get _filteredCameras {
    if (_filter.isEmpty) return _cameras;
    final q = _filter.toLowerCase();
    return _cameras.where((c) {
      final country = c.info?.country ?? '';
      final isp = c.info?.isp ?? '';
      final city = c.info?.city ?? '';
      final region = c.info?.regionName ?? '';
      final org = c.info?.org ?? '';
      final query = c.info?.query ?? '';
      return c.url.toLowerCase().contains(q) ||
          country.toLowerCase().contains(q) ||
          isp.toLowerCase().contains(q) ||
          city.toLowerCase().contains(q) ||
          region.toLowerCase().contains(q) ||
          org.toLowerCase().contains(q) ||
          query.toLowerCase().contains(q);
    }).toList();
  }

  Color? _alpha(Color? base, double opacity) {
    if (base == null) return null;
    return base.withAlpha((opacity * 255).round());
  }

  Future<void> _openPlayer(CameraInfo camera) async {
    // Show option dialog: fullscreen (try intelligent fullscreen playback) or open raw IP
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reproducir'),
        content: const Text('¿Cómo quieres reproducir esta cámara?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop('raw'),
            child: const Text('Abrir IP'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            onPressed: () => Navigator.of(ctx).pop('fullscreen'),
            child: const Text('Pantalla completa'),
          ),
        ],
      ),
    );

    if (choice == null) return;
    if (!mounted) return;

    if (choice == 'fullscreen') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CameraPlayerScreen(camera: camera)));
    } else if (choice == 'raw') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CameraPlayerScreen(camera: camera, raw: true)));
    }
    setState(() {});
  }

  void _focusOnCamera(CameraInfo cam) {
    setState(() => _selectedIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final lat = cam.info?.lat;
        final lon = cam.info?.lon;
        if (lat != null && lon != null) {
          _mapController.move(LatLng(lat, lon), 10.0);
        }
      } catch (_) {}
    });
  }

  void _showCameraDetails(CameraInfo cam) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.32,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(builder: (context, setModalState) {
              return Container(
                decoration: const BoxDecoration(color: Color(0xFF0B1114), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(cam.url, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      Row(children: [
                        IconButton(
                          tooltip: 'Reproducir',
                          icon: const Icon(Icons.play_arrow, color: Colors.white70),
                          onPressed: (){
                            Navigator.of(context).pop();
                            _openPlayer(cam);
                          },
                        ),
                        IconButton(
                          icon: Icon(_favorites.containsKey(cam.url) ? Icons.star : Icons.star_border, color: _favorites.containsKey(cam.url) ? Colors.amber : Colors.white70),
                          onPressed: (){
                            _toggleFavorite(cam);
                            // Update modal UI immediately
                            setModalState(() {});
                          },
                        )
                      ])
                    ]),
                    const SizedBox(height: 8),
                    if (cam.info != null) ...[
                      _infoRow('Estado', cam.info?.status),
                      _infoRow('País', cam.info?.country),
                      _infoRow('Código país', cam.info?.countryCode),
                      _infoRow('Región', cam.info?.region),
                      _infoRow('Nombre región', cam.info?.regionName),
                      _infoRow('Ciudad', cam.info?.city),
                      _infoRow('Zip', cam.info?.zip),
                      _infoRow('Lat, Lon', cam.info?.lat != null && cam.info?.lon != null ? '${cam.info!.lat}, ${cam.info!.lon}' : '-'),
                      _infoRow('Zona horaria', cam.info?.timezone),
                      _infoRow('ISP', cam.info?.isp),
                      _infoRow('AS', cam.info?.asName),
                      _infoRow('Org', cam.info?.org),
                      _infoRow('Modelo', cam.info?.model),
                      _infoRow('Query', cam.info?.query),
                      const SizedBox(height: 12),
                    ],
                  ]),
                ),
              );
            });
          }
        );
      }
    );
  }

  Widget _infoRow(String label, String? value){
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(children: [
        SizedBox(width: 110, child: Text('$label:', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value ?? '-', style: const TextStyle(color: Colors.white60, fontSize: 14)))
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final useRail = width >= 800; // show rail on wide screens

    return Scaffold(
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.map), label: Text('Mapa')),
                    NavigationRailDestination(icon: Icon(Icons.list), label: Text('Lista')),
                    NavigationRailDestination(icon: Icon(Icons.bar_chart), label: Text('Estadísticas')),
                    NavigationRailDestination(icon: Icon(Icons.star), label: Text('Favoritos')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(children: [
                    _buildHeader(context),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(key: ValueKey(_selectedIndex), child: _buildPage()),
                      ),
                    ),
                  ]),
                ),
              ],
            )
          : Column(children: [
              _buildHeader(context),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(key: ValueKey(_selectedIndex), child: _buildPage()),
                ),
              ),
            ]),
      bottomNavigationBar: useRail
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: _alpha(Theme.of(context).textTheme.bodySmall?.color, 0.7),
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
                BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Lista'),
                BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Estadísticas'),
                BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favoritos'),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
        child: Row(children: [
        // Left: logo only
        const Icon(Icons.videocam, color: Colors.cyanAccent, size: 28),
        const Spacer(),
        // Right: refresh and theme toggle
        IconButton(onPressed: _loadCameras, icon: const Icon(Icons.refresh), tooltip: 'Refrescar'),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Cambiar tema',
          onPressed: () => widget.onToggleTheme?.call(),
          icon: Icon(widget.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
        ),
      ]),
      )
    );
  }

  Widget _buildPage() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) return Center(child: Text('Error cargando datos: $_loadError'));

    switch (_selectedIndex) {
      case 0:
        return _buildMapPage();
      case 1:
        return _buildListPage();
      case 2:
        return _buildStatsPage();
      case 3:
        return _buildFavoritesPage();
      default:
        return _buildStatsPage();
    }
  }

  Widget _buildListPage() {
    final list = _filteredCameras;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          // Secondary search field for list page (keeps same filter state)
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Filtrar por URL, país, ciudad o ISP',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[100],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, idx) {
                final cam = list[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1.5,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: _alpha(Theme.of(context).colorScheme.primary, 0.12),
                      child: Icon(Icons.videocam, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(_favorites[cam.url]?.isNotEmpty == true ? _favorites[cam.url]! : cam.url, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: Text('${cam.info?.city ?? '-'} • ${cam.info?.country ?? '-'} • ${cam.info?.isp ?? '-'}', style: TextStyle(color: _alpha(Theme.of(context).textTheme.bodySmall?.color, 0.8) ?? Colors.grey)),
                    onTap: () => _showCameraDetails(cam),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1.0, end: _favorites.containsKey(cam.url) ? 1.12 : 1.0),
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut, 
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: IconButton(
                              icon: Icon(_favorites.containsKey(cam.url) ? Icons.star : Icons.star_border, color: _favorites.containsKey(cam.url) ? Colors.amber : Theme.of(context).iconTheme.color),
                              onPressed: () => _toggleFavorite(cam),
                            ),
                          );
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'open') _openPlayer(cam);
                          if (v == 'map') _focusOnCamera(cam);
                          if (v == 'favorite') await _toggleFavorite(cam);
                            if (v == 'rename') {
                            // edit existing favorite name
                            final current = _favorites[cam.url] ?? '';
                            final name = await showDialog<String>(
                              context: context,
                              builder: (ctx) {
                                final controller = TextEditingController(text: current.isNotEmpty ? current : (cam.info?.city ?? cam.url));
                                return AlertDialog(
                                  title: const Text('Editar nombre favorito'),
                                  content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Nombre visible')),
                                  actions: [
                                    TextButton(
                                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                                      onPressed: () => Navigator.of(ctx).pop(null),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                                      onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                                      child: const Text('Guardar'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (name != null) {
                              if (name.isEmpty) {
                                _favorites[cam.url] = '';
                              } else {
                                _favorites[cam.url] = name;
                              }
                              await _saveFavorites();
                              setState(() {});
                            }
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'open', child: Text('Abrir')),
                          const PopupMenuItem(value: 'map', child: Text('Ver en mapa')),
                          PopupMenuItem(value: 'favorite', child: Text(_favorites.containsKey(cam.url) ? 'Quitar favorito' : 'Añadir a favoritos')),
                          if (_favorites.containsKey(cam.url)) const PopupMenuItem(value: 'rename', child: Text('Editar nombre')),
                        ],
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPage() {
    final camsWithCoords = _cameras.where((c) => c.info?.lat != null && c.info?.lon != null).toList();
    final markers = camsWithCoords.map((c) => Marker(
      point: LatLng(c.info!.lat!, c.info!.lon!),
      width: 44,
      height: 44,
      builder: (ctx) => GestureDetector(
        onTap: () => _showCameraDetails(c),
        child: Tooltip(
          message: c.info?.city ?? c.url,
          child: Semantics(
            label: 'Cámara ${c.info?.city ?? c.url}',
            child: Stack(alignment: Alignment.center, children: [
              Icon(Icons.location_on, size: 40, color: _favorites.containsKey(c.url) ? Colors.amber : ((c.requiresAuth == true) ? Colors.red : Colors.cyanAccent)),
              Icon(Icons.videocam, color: Colors.white, size: 16),
            ]),
          ),
        ),
      ),
    )).toList();

    final center = camsWithCoords.isNotEmpty ? LatLng(camsWithCoords.first.info!.lat!, camsWithCoords.first.info!.lon!) : LatLng(0,0);

    // Wrap map in a Stack so we can add floating buttons
    return Stack(children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(center: center, zoom: 4.0),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.cam_app',
          ),
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 50,
              size: const Size(40, 40),
              markers: markers,
              fitBoundsOptions: const FitBoundsOptions(padding: EdgeInsets.all(40)),
              builder: (context, cluster) {
                int count = 0;
                try {
                  final dyn = cluster as dynamic;
                  count = (dyn.length ?? dyn.markers?.length ?? dyn.children?.length ?? dyn.items?.length) ?? 0;
                } catch (_) {
                  count = 0;
                }
                final size = 40.0 + (count > 10 ? 10 : (count > 4 ? 6 : 0));
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer]),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.26 * 255).round()), blurRadius: 6, offset: const Offset(0, 3))],
                    ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                );
              },
              onClusterTap: (cluster) {
                // Robustly extract markers from whatever cluster type the plugin provides
                List<Marker> clusterMarkers = [];
                try {
                  final dyn = cluster as dynamic;
                  final maybe = (dyn is Iterable) ? dyn : (dyn.markers ?? dyn.children ?? dyn.items);
                  if (maybe is Iterable) clusterMarkers = maybe.cast<Marker>().toList();
                } catch (_) {
                  // fallback: empty list
                  clusterMarkers = [];
                }

                // Map markers back to cameras using a small coordinate tolerance
                final cameras = <CameraInfo>[];
                for (var m in clusterMarkers) {
                  final lat = m.point.latitude;
                  final lon = m.point.longitude;
                  final cam = _findCameraByCoords(lat, lon, tol: 0.0005);
                  if (cam != null) cameras.add(cam);
                }

                if (cameras.isNotEmpty) _showClusterContents(cameras);
              },
            ),
          ),
        ],
      ),

      // Floating actions: fit bounds and center on first camera
      Positioned(top: 12, right: 12, child: Column(children: [
        FloatingActionButton.small(
          heroTag: 'fit',
          onPressed: _fitBoundsToAllCameras,
          child: const Icon(Icons.fit_screen),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'center',
          onPressed: (){
            if (camsWithCoords.isNotEmpty) {
              final c = camsWithCoords.first;
              try { _mapController.move(LatLng(c.info!.lat!, c.info!.lon!), 6.0); } catch (_) {}
            }
          },
          child: const Icon(Icons.my_location),
        ),
      ])),
    ]);
  }

  CameraInfo? _findCameraByCoords(double lat, double lon, {double tol = 0.0001}) {
    for (var c in _cameras) {
      final clat = c.info?.lat;
      final clon = c.info?.lon;
      if (clat == null || clon == null) continue;
      if ((clat - lat).abs() <= tol && (clon - lon).abs() <= tol) return c;
    }
    return null;
  }

  void _showClusterContents(List<CameraInfo> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, controller) {
          return Container(
            decoration: const BoxDecoration(color: Color(0xFF0B1114), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(12.0), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))])),
              Expanded(child: ListView.builder(
                controller: controller,
                itemCount: list.length,
                itemBuilder: (context, idx) {
                  final cam = list[idx];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: _alpha(Theme.of(context).colorScheme.primary, 0.15), child: Icon(Icons.videocam, color: Theme.of(context).colorScheme.primary)),
                      title: Text(cam.url, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${cam.info?.country ?? '-'} • ${cam.info?.isp ?? '-'}'),
                      onTap: (){ Navigator.of(context).pop(); _showCameraDetails(cam); },
                      trailing: IconButton(icon: Icon(_favorites.containsKey(cam.url) ? Icons.star : Icons.star_border, color: _favorites.containsKey(cam.url) ? Colors.amber : Colors.white70), onPressed: () => _toggleFavorite(cam)),
                    ),
                  );
                },
              )),
            ]),
          );
        }
      )
    );
  }

  void _fitBoundsToAllCameras() async {
    final points = _cameras.where((c) => c.info?.lat != null && c.info?.lon != null).map((c) => LatLng(c.info!.lat!, c.info!.lon!)).toList();
    if (points.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(points);
      // try to use fitBounds if available; otherwise move to center
      try {
        _mapController.fitBounds(bounds, options: FitBoundsOptions(padding: EdgeInsets.all(40)));
      } catch (_) {
        final center = LatLng((bounds.south + bounds.north)/2, (bounds.west + bounds.east)/2);
        _mapController.move(center, 4.0);
      }
    } catch (_) {}
  }

  Widget _buildStatsPage() {
    final total = _cameras.length;
    final extracted = _cameras.where((c) => c.estado == 'extraido').length;
    final highImportance = _cameras.where((c) => c.importancia == 'alta').length;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total cámaras: $total', style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Text('Estado "extraido": $extracted', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text('Importancia alta: $highImportance', style: const TextStyle(fontSize: 16)),
      ]),
    );
  }

  Widget _buildFavoritesPage() {
    final list = _cameras.where((c) => _favorites.containsKey(c.url)).toList();
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text('Favoritos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: _clearFavorites, icon: const Icon(Icons.delete_outline), label: const Text('Limpiar')),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text('No hay favoritos', style: TextStyle(color: _alpha(Theme.of(context).textTheme.bodyMedium?.color, 0.7))))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, idx) {
                      final cam = list[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1.5,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: _alpha(Theme.of(context).colorScheme.primary, 0.12),
                            child: Icon(Icons.videocam, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(_favorites[cam.url]?.isNotEmpty == true ? _favorites[cam.url]! : cam.url, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          subtitle: Text('${cam.info?.city ?? '-'} • ${cam.info?.country ?? '-'} • ${cam.info?.isp ?? '-'}', style: TextStyle(color: _alpha(Theme.of(context).textTheme.bodySmall?.color, 0.8))),
                          onTap: () => _showCameraDetails(cam),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 1.0, end: _favorites.containsKey(cam.url) ? 1.12 : 1.0),
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: IconButton(
                                    icon: Icon(_favorites.containsKey(cam.url) ? Icons.star : Icons.star_border, color: _favorites.containsKey(cam.url) ? Colors.amber : Theme.of(context).iconTheme.color),
                                    onPressed: () => _toggleFavorite(cam),
                                  ),
                                );
                              },
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'open') _openPlayer(cam);
                                if (v == 'map') _focusOnCamera(cam);
                                if (v == 'favorite') await _toggleFavorite(cam);
                                if (v == 'rename' && _favorites.containsKey(cam.url)) {
                                  final current = _favorites[cam.url] ?? '';
                                  final name = await showDialog<String>(
                                    context: context,
                                    builder: (ctx) {
                                      final controller = TextEditingController(text: current.isNotEmpty ? current : (cam.info?.city ?? cam.url));
                                      return AlertDialog(
                                        title: const Text('Editar nombre favorito'),
                                        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Nombre visible')),
                                        actions: [
                                          TextButton(
                                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                                            onPressed: () => Navigator.of(ctx).pop(null),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                                            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                                            child: const Text('Guardar'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (name != null) {
                                    _favorites[cam.url] = name;
                                    await _saveFavorites();
                                    setState(() {});
                                  }
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'open', child: Text('Abrir')),
                                const PopupMenuItem(value: 'map', child: Text('Ver en mapa')),
                                PopupMenuItem(value: 'favorite', child: Text(_favorites.containsKey(cam.url) ? 'Quitar favorito' : 'Añadir a favoritos')),
                                if (_favorites.containsKey(cam.url)) const PopupMenuItem(value: 'rename', child: Text('Editar nombre')),
                              ],
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CameraPlayerScreen extends StatefulWidget {
  final CameraInfo camera;
  final bool raw; // if true, load the camera URL directly without probing
  const CameraPlayerScreen({super.key, required this.camera, this.raw = false});

  @override
  State<CameraPlayerScreen> createState() => _CameraPlayerScreenState();
}

class _CameraPlayerScreenState extends State<CameraPlayerScreen> {
  late final WebViewController _webController;
  bool isLocked = false;
  bool _useMjpegHtml = false;
  bool _useFallback = false;
  bool _webviewFailed = false;
  // Debug overlay
  final List<String> _debugLogs = [];
  bool _showDebugOverlay = true;
  String _videoUrl = '';
  bool _controllerInitialized = false;
  bool _controlsVisible = true;
  bool _pageLoading = true;
  Timer? _slowLoadTimer;
  bool _showedSlowLoadDisclaimer = false;
  Timer? _hideTimer;
  String _streamLabel = '';
  bool _fitCover = false;
  final TextEditingController _authUserController = TextEditingController();
  final TextEditingController _authPassController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  void _addDebug(String msg) {
    try {
      final ts = DateTime.now().toIso8601String();
      _debugLogs.insert(0, '[$ts] $msg');
      if (_debugLogs.length > 200) _debugLogs.removeRange(100, _debugLogs.length);
      if (mounted) setState(() {});
      debugPrint(msg);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();

    // Force landscape and immersive UI
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Async setup: determine stream type then initialize WebViewController as needed
    _setup();
  }

  Future<void> _setup() async {
    _addDebug('>> _setup START');
    _webviewFailed = false;

    // 1. Determinar la URL y el tipo de stream
    if (widget.raw) {
      _videoUrl = _ensureHttpSafe(widget.camera.url);
      _useMjpegHtml = false;
      _useFallback = true;
      // En modo raw no probamos autenticación
      _addDebug('raw mode -> videoUrl=$_videoUrl');
    } else {
      _addDebug('calling _determineStreamType()');
      await _determineStreamType();

      _addDebug('after _determineStreamType -> isLocked=$isLocked useMjpeg=$_useMjpegHtml useFallback=$_useFallback video=$_videoUrl');

      if (isLocked) {
        _addDebug('isLocked -> requires auth, aborting setup');
        if (mounted) setState(() {});
        return;
      }
    }

    // 2. Inicializar el controlador del WebView
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    // 3. Configurar User Agent inteligente según la plataforma
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // User Agent de Safari en iPhone para saltar bloqueos de Apple
        _webController.setUserAgent(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1");
        _addDebug('set UA: iOS Safari-like');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // User Agent de Chrome en Android (tu Redmi K20 Pro)
        _webController.setUserAgent(
            "Mozilla/5.0 (Linux; Android 11; Redmi K20 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36");
        _addDebug('set UA: Android Chrome-like');
      } else {
        // User Agent genérico para otros sistemas
        _webController.setUserAgent(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36");
        _addDebug('set UA: generic desktop-like');
      }
    } catch (e) {
      debugPrint("Error configurando UserAgent: $e");
      _addDebug('error setting UA: $e');
    }

    // 4. Único NavigationDelegate (Fusión de logs de error + limpieza de JS)
    _webController.setNavigationDelegate(NavigationDelegate(
      onPageStarted: (url) {
        _addDebug('onPageStarted: ${url ?? ''}');
        _onPageStarted();
      },
      onPageFinished: (url) async {
        _addDebug('onPageFinished: ${url ?? ''}');
        // Inyectamos el limpiador de CSS/JS para quitar menús de la cámara
        await _injectCleaner();
        try {
          await _enableZoomAndScroll();
          _addDebug('enableZoomAndScroll executed');
        } catch (e) {
          _addDebug('enableZoomAndScroll failed: $e');
        }
        _onPageFinished();
      },
      onWebResourceError: (WebResourceError error) {
        // LOG CRÍTICO: Aquí verás en la consola de Codemagic por qué falla en iPhone
        final descr = error.description ?? '';
        final code = error.errorCode;
        String url = '';
        try {
          url = (error as dynamic).failingUrl ?? (error as dynamic).url ?? '';
        } catch (_) {
          url = '';
        }
        debugPrint("❌ Error WebView: $descr | Código: $code | URL: $url");
        _addDebug('WebView ERROR: $descr | code=$code | url=$url');
        // Mark webview as failed so UI switches to native fallback
        if (mounted) {
          setState(() {
            _pageLoading = false;
            _useFallback = true;
            _useMjpegHtml = false;
            _controllerInitialized = true;
            _webviewFailed = true;
            widget.camera.useFullWeb = true;
          });
          _addDebug('WebView failed -> will show NativeFallbackWidget');
        }
      },
    ));

    // 5. Cargar el contenido (HTML para MJPEG o URL directa)
    if (_useMjpegHtml) {
      final html = '''
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        </head>
        <body style="margin:0;padding:0;background:black;display:flex;justify-content:center;align-items:center;">
          <img src="$_videoUrl" 
               onerror="this.src=this.src;" 
               style="width:100vw;height:100vh;object-fit:contain;">
        </body>
      </html>
      ''';
      _addDebug('loading MJPEG HTML with $_videoUrl');
      // For MJPEG streams, prefer native MJPEG parser widget to avoid WebView ORB blocking
      _controllerInitialized = true;
      _videoUrl = _ensureHttpSafe(_videoUrl);
      // store html in _videoUrl? we will use _useMjpegHtml flag in build to show MJPEG widget
    } else {
      _addDebug('loading URL request: $_videoUrl');
      _videoUrl = _ensureHttpSafe(_videoUrl);
      // mark controller as initialized so build shows the WebView, not the spinner
      _controllerInitialized = true;
      _webController.loadRequest(Uri.parse(_videoUrl));
    }

    _addDebug('<< _setup END');
    if (mounted) setState(() {});
  }

  void _startHideTimer([int seconds = 4]){
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: seconds), (){
      setState(()=>_controlsVisible = false);
    });
  }

  void _showControls(){
    setState((){ _controlsVisible = true; });
    _startHideTimer();
  }

  void _toggleControls(){
    setState(()=> _controlsVisible = !_controlsVisible);
    if(_controlsVisible) _startHideTimer(); else _hideTimer?.cancel();
  }

  void _onPageStarted(){
    _showedSlowLoadDisclaimer = false;
    _slowLoadTimer?.cancel();
    setState(()=> _pageLoading = true);
    _slowLoadTimer = Timer(const Duration(seconds: 6), () async {
      if (_pageLoading && !_showedSlowLoadDisclaimer) {
        _showedSlowLoadDisclaimer = true;
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tarda en cargar'),
            content: const Text('La cámara está tardando en cargar. Esto puede ser normal; algunas cámaras tardan más. Puedes esperar unos segundos más o abrir la IP directamente.'),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final raw = _ensureHttpSafe(widget.camera.url);
                    setState(()=> _pageLoading = true);
                    await _webController.loadRequest(Uri.parse(raw));
                  } catch (_) {}
                },
                child: const Text('Abrir IP'),
              ),
            ],
          ),
        );
      }
    });
  }

  void _onPageFinished(){
    _slowLoadTimer?.cancel();
    setState(()=> _pageLoading = false);
  }

  Future<void> _determineStreamType() async {
    final base = _ensureHttpSafe(widget.camera.url.trim());
    // Try to load credentials from model or secure storage
    if ((widget.camera.authUser == null || widget.camera.authPass == null)) {
      final key = _storageKeyForCamera(base);
      try {
        final creds = await _secureStorage.read(key: key);
        if (creds != null && creds.contains(':')) {
          final parts = creds.split(':');
          if (parts.length >= 2) {
            widget.camera.authUser = parts[0];
            widget.camera.authPass = parts.sublist(1).join(':');
          }
        }
      } catch (_) {}
    }

    // Build brand-aware candidate routes
    final model = (widget.camera.info?.model ?? '').toLowerCase();
    final org = (widget.camera.info?.org ?? '').toLowerCase();
    final q = (widget.camera.info?.query ?? '').toLowerCase();

    final List<String> candidates = [];

    void addAll(List<String> items){ for(var s in items) if(!candidates.contains(s)) candidates.add(s); }

    _addDebug('determineStreamType base=$base');

    // Prioritize known good routes before brand-specific heuristics
    addAll([
      '/viewer/live/es/live.html',
      '/viewer/live/en/fullscreen.html',
      '/mjpg/video.mjpg',
      '/live/index.html',
    ]);

    // Brand-specific hints
    if (model.contains('axis') || org.contains('axis')) {
      addAll(['/axis-cgi/mjpg/video.cgi', '/axis-cgi/mjpg/video.mjpg', '/mjpg/video.mjpg', '/axis-cgi/jpg/image.cgi']);
    }
    if (model.contains('hikvision') || org.contains('hikvision')) {
      addAll(['/Streaming/Channels/1/picture', '/Streaming/channels/1/httppreview', '/ISAPI/Streaming/channels/101/picture']);
    }
    if (model.contains('dahua') || org.contains('dahua')) {
      addAll(['/cgi-bin/mjpeg?stream=1', '/cgi-bin/mjpeg.cgi?stream=1', '/cgi-bin/preview.cgi?1']);
    }
    if (model.contains('vivotek') || org.contains('vivotek') || model.contains('vico') ) {
      addAll(['/mjpg/1', '/cgi/mjpg/mjpg.cgi?camera=1', '/live/mjpeg']);
    }
    if (model.contains('panasonic') || model.contains('sanyo') || org.contains('panasonic')) {
      addAll(['/snapshot.jpg', '/image.jpg', '/video/mjpg.cgi']);
    }
    if (model.contains('hanwha') || model.contains('samsung') || org.contains('hanwha') || org.contains('samsung')) {
      addAll(['/snapshot.cgi', '/cgi-bin/snapshot.cgi', '/Video/Live_stream']);
    }

    // Generic common paths
    addAll(['/mjpg/video.mjpg', '/mjpg.cgi', '/cgi-bin/mjpg.cgi', '/video.cgi', '/cgi-bin/video.cgi', '/video.mjpg', '/snapshot.jpg', '/jpg/image.jpg', '/']);

    // If original contains a path, try using it as-is and also try common suffixes
    try {
      final orig = Uri.parse(base);
      final basePath = orig.path.isEmpty ? '' : orig.path;
      if (basePath.isNotEmpty && !candidates.contains(basePath)) candidates.insert(0, basePath);
    } catch (_) {}

    // Probe candidates in order with short timeout
    _addDebug('candidates (${candidates.length}): ${candidates.join(', ')}');
    for (var path in candidates) {
      String probeUrl;
      try {
        if (path.startsWith('http://') || path.startsWith('https://')) {
          probeUrl = path;
        } else if (path == '/' || path.isEmpty) {
          probeUrl = base;
        } else {
          // construct from base origin
          try {
            final u = Uri.parse(base);
            final scheme = (u.scheme.isEmpty) ? 'http' : u.scheme;
            final host = u.host.isNotEmpty ? u.host : (u.pathSegments.isNotEmpty ? u.pathSegments[0] : '');
            final port = u.hasPort ? u.port : null;
            final userInfo = (widget.camera.authUser != null && widget.camera.authPass != null) ? '${widget.camera.authUser}:${widget.camera.authPass}' : null;
            final built = Uri(scheme: scheme, userInfo: userInfo, host: host, port: port, path: path.startsWith('/') ? path : '/$path');
            probeUrl = built.toString();
          } catch (_) {
            probeUrl = base + (path.startsWith('/') ? path : '/$path');
          }
        }
      } catch (_) {
        probeUrl = base;
      }

      _videoUrl = probeUrl;
      try {
        _addDebug('probing -> $probeUrl');
        final uri = Uri.parse(probeUrl);
        final resp = await http.get(uri).timeout(const Duration(seconds: 2));
        final code = resp.statusCode;
        final contentType = (resp.headers['content-type'] ?? '').toLowerCase();
        final body = resp.body.toLowerCase();
        _addDebug('probe result -> $probeUrl status=$code content-type=$contentType bodyLen=${resp.body.length}');

        if (code == 401) {
          isLocked = true;
          widget.camera.requiresAuth = true;
          return;
        }

        if (code == 200) {
          // Conservative MJPEG detection:
          // - Prefer content-type 'multipart/x-mixed-replace' OR explicit image/*
          // - If path ends with .mjpg/.mjpeg only accept when header suggests image/multipart
          bool looksLikeMjpeg = false;
          final bytes = resp.bodyBytes;

          if (contentType.contains('multipart/x-mixed-replace')) {
            looksLikeMjpeg = true;
            _addDebug('probe hint: content-type is multipart');
          } else if (contentType.startsWith('image/')) {
            // single JPEG snapshot or MJPEG served with image/* header
            // treat as snapshot (fallback to native image viewer)
            _addDebug('probe hint: content-type is image/* -> will use native image fallback');
            _useMjpegHtml = false;
            _useFallback = true;
            _videoUrl = probeUrl;
            return;
          } else if (probeUrl.toLowerCase().endsWith('.mjpg') || probeUrl.toLowerCase().endsWith('.mjpeg')) {
            // only accept .mjpg when headers or initial bytes look like MJPEG
            if (contentType.contains('multipart') || (bytes.length > 4 && bytes.contains(0xFF) && bytes.contains(0xD8))) {
              looksLikeMjpeg = true;
              _addDebug('probe hint: .mjpg URL with matching headers/bytes');
            }
          }

          if (looksLikeMjpeg) {
            _useMjpegHtml = true;
            _useFallback = false;
            isLocked = false;
            widget.camera.requiresAuth = false;
            widget.camera.useFullWeb = false;
            try { await _secureStorage.delete(key: _storageKeyForCamera(base)); } catch (_) {}
            return;
          }

          // HTML pages: prefer loading UI in webview
          if (contentType.contains('text/html') || body.contains('<html')) {
            _useFallback = true;
            _useMjpegHtml = false;
            _videoUrl = probeUrl;
            widget.camera.useFullWeb = true;
            return;
          }

          // If unsure but 200, treat as fallback page (may contain embedded player)
          _useFallback = true;
          _useMjpegHtml = false;
          _videoUrl = probeUrl;
          return;
        }

        if (code == 403 || code == 404) {
          // forbidden/not found -> try next candidate but mark fallback if all fail
          continue;
        }
      } catch (e) {
        // timed out or network error -> try next
        _addDebug('probe error for $probeUrl: $e');
        continue;
      }
    }

    // nothing matched: fallback to original URL
    _videoUrl = base;
    _useFallback = true;
    _useMjpegHtml = false;
  }

  String _storageKeyForCamera(String baseUrl) {
    try {
      final u = Uri.parse(_ensureHttp(baseUrl));
      final host = u.host;
      final port = u.hasPort ? u.port.toString() : 'default';
      return 'cam_auth_${host}_$port';
    } catch (_) {
      return 'cam_auth_${baseUrl.hashCode}';
    }
  }

  Future<void> _runJs(String code) async {
    try {
      await _webController.runJavaScript(code);
    } catch (_) {}
  }

  Future<void> _injectCleaner() async {
    // First inject a small shim to define missing camera-specific functions
    // and a global error handler to avoid noisy console errors from device UIs.
    await _injectShim();
    const script = r"""
(function(){
  try{
    function setFull(el){
      el.style.setProperty('position','fixed','important');
      el.style.setProperty('top','0','important');
      el.style.setProperty('left','0','important');
      el.style.setProperty('width','100vw','important');
      el.style.setProperty('height','100vh','important');
      el.style.setProperty('object-fit','contain','important');
      el.style.setProperty('z-index','99999','important');
      el.style.setProperty('background','#000','important');
      el.style.setProperty('margin','0','important');
      el.style.setProperty('padding','0','important');
    }

    // Prefer element with id 'stream'
    var candidate = document.getElementById('stream');
    if(!candidate){
      var imgs = Array.from(document.images || []);
      if(imgs.length>0){
        imgs.sort(function(a,b){
          var aa = (a.naturalWidth||a.width) * (a.naturalHeight||a.height);
          var bb = (b.naturalWidth||b.width) * (b.naturalHeight||b.height);
          return bb - aa;
        });
        candidate = imgs[0];
      }
    }

    if(candidate){
      // Hide everything, then show only the chosen element
      document.documentElement.style.setProperty('overflow','hidden','important');
      document.body.style.setProperty('visibility','hidden','important');
      setFull(candidate);
      candidate.style.setProperty('visibility','visible','important');
      // Ensure parent chain is visible
      var p = candidate.parentElement;
      while(p){ p.style.setProperty('visibility','visible','important'); p = p.parentElement; }
      return true;
    } else {
      // Fallback: try video element
      var v = document.querySelector('video');
      if(v){
        document.body.style.setProperty('visibility','hidden','important');
        setFull(v);
        v.style.setProperty('visibility','visible','important');
        var p2 = v.parentElement;
        while(p2){ p2.style.setProperty('visibility','visible','important'); p2 = p2.parentElement; }
        return true;
      }
    }
  }catch(e){ return false; }
  return false;
})();
""";

    await _runJs(script);
  }

  Future<void> _injectShim() async {
    const shim = r"""
(function(){
  try{
    window.PreLoadImages = window.PreLoadImages || function(){};
    window.updateLogoInfo = window.updateLogoInfo || function(){};
    window.capability_nmediastream = window.capability_nmediastream || function(){};
    window.custom_translator_ok = window.custom_translator_ok || function(){};
    window.updatePowerByVVTLogo = window.updatePowerByVVTLogo || function(){};
    window.ShowCustomCmd = window.ShowCustomCmd || function(){};
    window.loadCurrentSetting = window.loadCurrentSetting || function(){};
    // swallow uncaught errors to avoid noisy logs
    window.onerror = window.onerror || function(){ return true; };
    return true;
  }catch(e){ return false; }
})();
""";
    await _runJs(shim);
  }

  Future<void> _enableZoomAndScroll() async {
    const js = r"""
(function(){
  try {
    var mv = document.querySelector('meta[name=viewport]');
    if(!mv){
      mv = document.createElement('meta');
      mv.name = 'viewport';
      document.head.appendChild(mv);
    }
    mv.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=1';

    document.documentElement.style.overflow = 'auto';
    document.body.style.overflow = 'auto';
    try { document.body.style.webkitOverflowScrolling = 'touch'; } catch(e) {}

    // Force touch-action and pointer settings on all elements so sites that disable gestures stop doing that
    try {
      var all = Array.from(document.getElementsByTagName('*'));
      for(var i=0;i<all.length;i++){
        try{
          all[i].style.touchAction = 'auto';
          all[i].style['-webkit-user-select'] = 'auto';
          all[i].style['-webkit-touch-callout'] = 'default';
          all[i].style['-ms-touch-action'] = 'auto';
        }catch(e){}
      }
    } catch(e){}

    // Remove blocking touch event handlers by overriding addEventListener to allow passive listeners
    try {
      var origAdd = EventTarget.prototype.addEventListener;
      EventTarget.prototype.addEventListener = function(type, listener, options){
        if(type === 'touchstart' || type === 'touchmove' || type === 'touchend' || type === 'gesturestart' || type === 'gesturechange' || type === 'gestureend'){
          try{ return origAdd.call(this, type, listener, {passive:true}); }catch(e){}
        }
        return origAdd.call(this, type, listener, options);
      };
    } catch(e){}

    return true;
  } catch(e){ return false; }
})();
""";
    await _runJs(js);
  }

  Future<void> _applyImageCss() async {
    const css = r"""
document.body.style.margin = '0';
document.body.style.padding = '0';
var imgs = document.getElementsByTagName('img');
if(imgs && imgs.length>0){
  imgs[0].style.setProperty('width','100vw','important');
  imgs[0].style.setProperty('height','100vh','important');
}
""";
    await _runJs(css);
  }

  String _ensureHttp(String url) {
    var s = url.trim();
    // Collapse repeated protocol prefixes like 'http://http://'
    s = s.replaceAll(RegExp(r'^(?:https?:\/\/)+', caseSensitive: false), 'http://');
    // Remove trailing slashes
    s = s.replaceAll(RegExp(r'\/+ ?\s* ? ?\z'), '');
    s = s.replaceAll(RegExp(r'\/+\s* ?\z'), '');
    s = s.replaceAll(RegExp(r'\s+'), '');
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'http://$s';
  }

  String _axisMjpegUrl(String original) {
    // Simplified: always return base + /mjpg/video.mjpg (avoid duplicate slashes)
    final base = original.trim();
    final pref = _ensureHttp(base);
    if (pref.endsWith('/')) return '${pref}mjpg/video.mjpg';
    return '$pref/mjpg/video.mjpg';
  }

  // A safer URL normalizer used by the player logic to avoid malformed URLs
  // on iOS/WebView. This is preferred inside CameraPlayerScreen.
  String _ensureHttpSafe(String url) {
    var s = url.trim();
    if (s.isEmpty) return s;
    // Remove whitespace
    s = s.replaceAll(RegExp(r'\s+'), '');

    // Normalize repeated scheme prefixes to a single one
    final schemeMatch = RegExp(r'^(?:https?:\/\/)+', caseSensitive: false).firstMatch(s);
    if (schemeMatch != null) {
      final wantsHttps = s.toLowerCase().startsWith('https://');
      final scheme = wantsHttps ? 'https://' : 'http://';
      s = s.replaceFirst(RegExp(r'^(?:https?:\/\/)+', caseSensitive: false), scheme);
    }

    // Ensure scheme
    if (!s.toLowerCase().startsWith('http://') && !s.toLowerCase().startsWith('https://')) {
      s = 'http://$s';
    }

    // Trim trailing slashes
    s = s.replaceAll(RegExp(r'\/+\s*\z'), '');

    return s;
  }

  void _moveUp() async {
    _sendPtzCommand('up');
    await _runJs('if(typeof moveUp=="function") moveUp(); else if(document.querySelector(".ptz-up")) document.querySelector(".ptz-up").click();');
  }

  void _moveDown() async {
    _sendPtzCommand('down');
    await _runJs('if(typeof moveDown=="function") moveDown(); else if(document.querySelector(".ptz-down")) document.querySelector(".ptz-down").click();');
  }

  void _moveLeft() async {
    _sendPtzCommand('left');
    await _runJs('if(typeof moveLeft=="function") moveLeft(); else if(document.querySelector(".ptz-left")) document.querySelector(".ptz-left").click();');
  }

  void _moveRight() async {
    _sendPtzCommand('right');
    await _runJs('if(typeof moveRight=="function") moveRight(); else if(document.querySelector(".ptz-right")) document.querySelector(".ptz-right").click();');
  }


  Future<void> _sendPtzCommand(String dir) async {
    try {
      final src = _ensureHttpSafe(widget.camera.url.trim());
      final u = Uri.parse(src);
      final scheme = u.scheme.isEmpty ? 'http' : u.scheme;
      final host = u.host;
      final port = u.hasPort ? u.port : null;
      final ptzUri = Uri(scheme: scheme, host: host, port: port, path: '/axis-cgi/com/ptz.cgi', queryParameters: {'move': dir});
      await http.get(ptzUri).timeout(const Duration(seconds: 3));
    } catch (e) {
      // ignore network errors silently
    }
  }

  Future<void> _attemptLogin(String user, String pass) async {
    try {
      final base = _ensureHttpSafe(widget.camera.url.trim());
      final u = Uri.parse(base);
      final scheme = u.scheme.isEmpty ? 'http' : u.scheme;
      final host = u.host.isNotEmpty ? u.host : (u.pathSegments.isNotEmpty ? u.pathSegments[0] : '');
      final port = u.hasPort ? u.port : null;
      final authUserInfo = '$user:$pass';
      final authUri = Uri(scheme: scheme, userInfo: authUserInfo, host: host, port: port, path: '/mjpg/video.mjpg');

      final resp = await http.get(authUri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        // success: persist creds and load stream
        widget.camera.authUser = user;
        widget.camera.authPass = pass;
        widget.camera.requiresAuth = false;
        isLocked = false;
        // persist securely
        final key = _storageKeyForCamera(_ensureHttpSafe(widget.camera.url));
        try { await _secureStorage.write(key: key, value: '$user:$pass'); } catch (_) {}
        _videoUrl = authUri.toString();
        _useMjpegHtml = true;
        _useFallback = false;
        // load HTML with auth URL
        final html = '''
  <html>
    <body style="margin:0;padding:0;background:black;display:flex;justify-content:center;align-items:center;">
      <img src="$_videoUrl" onerror="this.src=this.src;" style="width:100vw;height:100vh;object-fit:fill;">
    </body>
  </html>
''';
        await _webController.loadHtmlString(html, baseUrl: base);
        _streamLabel = 'MJPEG';
        _showControls();
        setState(() {});
      } else if (resp.statusCode == 401) {
        // still unauthorized
        widget.camera.requiresAuth = true;
        setState(() {});
      } else {
        // other failures: fallback
        _useFallback = true;
        _useMjpegHtml = false;
        widget.camera.useFullWeb = true;
        setState(() {});
      }
    } catch (e) {
      _useFallback = true;
      _useMjpegHtml = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _authUserController.dispose();
    _authPassController.dispose();
    _hideTimer?.cancel();
    _slowLoadTimer?.cancel();
    // Restore portrait and system UI
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Widget _floatingCircle(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.6 * 255).round()), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 26)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // If locked, show lock UI
          if (isLocked)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 96, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      const Text('Esta cámara requiere credenciales', style: TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: TextField(
                          controller: _authUserController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Usuario', labelStyle: TextStyle(color: Colors.white70), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: TextField(
                          controller: _authPassController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Contraseña', labelStyle: TextStyle(color: Colors.white70), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final u = _authUserController.text.trim();
                          final p = _authPassController.text.trim();
                          if (u.isNotEmpty) {
                            await _attemptLogin(u, p);
                          }
                        },
                        child: const Text('Conectar'),
                      ),
                      const SizedBox(height: 8),

                // Debug overlay (toggleable)
                if (_showDebugOverlay)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: GestureDetector(
                      onLongPress: () {
                        // long press to hide
                        setState(() => _showDebugOverlay = false);
                      },
                      child: Container(
                        width: 360,
                        height: 220,
                        decoration: BoxDecoration(color: Colors.black87.withOpacity(0.7), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                        padding: const EdgeInsets.all(8),
                        child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('DEBUG', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 18), onPressed: () => setState(() => _showDebugOverlay = false))
                          ]),
                          const Divider(color: Colors.white12),
                          Expanded(
                            child: _debugLogs.isEmpty
                                ? const Text('No logs', style: TextStyle(color: Colors.white54, fontSize: 12))
                                : ListView.builder(
                                    itemCount: _debugLogs.length,
                                    itemBuilder: (ctx, i) => Text(_debugLogs[i], style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Volver', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (!_controllerInitialized)
            const Positioned.fill(child: Center(child: CircularProgressIndicator()))
          else if (_useMjpegHtml)
            // MJPEG native viewer (avoids WebView ORB blocking)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: MJpegWidget(url: _videoUrl, user: widget.camera.authUser, pass: widget.camera.authPass),
              ),
            )
          else if (_webviewFailed)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: NativeFallbackWidget(url: _videoUrl),
              ),
            )
          else
            // Fullscreen webview with tap-to-toggle controls (show in-app WebView, keep external fallback button available)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: Stack(children: [
                  // Render the WebView controller content
                  WebViewWidget(controller: _webController),
                  // Small floating fallback button if user prefers external browser
                  Positioned(
                    bottom: 18,
                    right: 18,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _controlsVisible ? 1.0 : 0.0,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black54),
                        onPressed: () async {
                          try {
                            final uri = Uri.parse(_videoUrl);
                            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el navegador')));
                            }
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Abrir en navegador'),
                      ),
                    ),
                  ),
                ]),
              ),
            ),

          // Loading overlay while the page/stream is loading
          if (_pageLoading)
            Positioned.fill(child: Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator()))) ,

          // Minimal close button (always available while in player)
          Positioned(top: 16, right: 16, child: SafeArea(child: _floatingCircle(Icons.close, () => Navigator.of(context).pop()))),

          // subtle top-left info chip (shows for web fallback)
          if (_controllerInitialized && !_useMjpegHtml)
            Positioned(top: 18, left: 18, child: AnimatedOpacity(duration: const Duration(milliseconds: 220), opacity: _controlsVisible ? 1.0 : 0.0, child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), color: Colors.black45, child: Text(widget.camera.url, style: const TextStyle(color: Colors.white70, fontSize: 12))),
              ),
            ))),

          // NOTE: Removed in-player overlay controls (PTZ, refresh, labels) to keep player clean
        ],
      ),
    );
  }
}
