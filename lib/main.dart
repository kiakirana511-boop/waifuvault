import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const WaifuVaultApp());
}

const Color kBg = Color(0xFF050B1C);
const Color kPanel = Color(0xFF0B1328);
const Color kPanel2 = Color(0xFF121C36);
const Color kPink = Color(0xFFFF8AAF);
const Color kPurple = Color(0xFFB58CFF);
const Color kBlue = Color(0xFF89B8FF);
const Color kTextSoft = Color(0xFFC9C7E6);
const Color kCosmicGold = Color(0xFFFFD7A3);
const String kFixedSdImportPath = '/storage/4394-15F8/DCM Waifu';
const String kPublicInternalVaultPath = '/storage/emulated/0/DCM Waifu';
const String kPublicInternalCachePath = '/storage/emulated/0/DCM Waifu/.waifuvault_cache';
const List<String> kFixedSdImportPathCandidates = [
  '/storage/4394-15F8/DCM Waifu',
  '/storage/4394-15F8/DCM Waifu/',
  '/storage/4394-15F8/DCIM Waifu',
  '/storage/4394-15F8/DCIM Waifu/',
  '/storage/4394-15F8/DCM_Waifu',
];

class VaultCategory {
  final String name;
  final IconData icon;
  final List<Color> colors;

  const VaultCategory(this.name, this.icon, this.colors);
}

const List<VaultCategory> defaultCategories = [
  VaultCategory('Hoshino', Icons.star_rounded, [Color(0xFFFF68C9), Color(0xFF7B4DFF)]),
  VaultCategory('Blue Archive', Icons.auto_awesome_rounded, [Color(0xFF55D6FF), Color(0xFF6C5CFF)]),
  VaultCategory('Video JJ', Icons.play_arrow_rounded, [Color(0xFFFF4FB8), Color(0xFF00E5FF)]),
  VaultCategory('Wallpaper', Icons.wallpaper_rounded, [Color(0xFF895CFF), Color(0xFFFF8ACF)]),
  VaultCategory('Lainnya', Icons.grid_view_rounded, [Color(0xFF5C6CFF), Color(0xFF2BE7FF)]),
];


PageRouteBuilder<T> smoothPageRoute<T>(Widget page) {
  // V8.10.1 Ultra Light Route: route/menu transition dibuat super ringan.
  // Ini buat HP 60Hz/low-end supaya masuk-keluar Profil/Storage tidak terasa patah.
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 90),
    reverseTransitionDuration: const Duration(milliseconds: 70),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.linearToEaseOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}


String mediaHeroTag(VaultMedia item) => 'waifuvault_media_${item.id}';

String displayMediaTitle(VaultMedia item) {
  final raw = item.title.trim();
  final fallback = item.isVideo ? 'Video Baru' : 'Foto Baru';
  if (raw.isEmpty) return fallback;
  final looksTooLong = raw.length > 30;
  final looksLikeCameraName = RegExp(r'^(img|vid|video|photo|screenshot|screenrecord|received|wa|pxl|dsc|mv|100)[_\-\s]?\d', caseSensitive: false).hasMatch(raw);
  final looksLikeTimestamp = RegExp(r'\d{8,}').hasMatch(raw);
  final looksLikeExtension = RegExp(r'\.(jpg|jpeg|png|webp|gif|heic|heif|mp4|mov|mkv|3gp)$', caseSensitive: false).hasMatch(raw);
  if (looksTooLong || looksLikeCameraName || looksLikeTimestamp || looksLikeExtension) return fallback;
  return raw;
}

class VaultMedia {
  final String id;
  final String path;
  final String type; // image / video
  final String title;
  final String category;
  final String? thumbnailPath;
  final int createdAt;
  final bool favorite;
  final int? accentColor;
  final List<int> videoAccentColors;
  final List<String> videoFramePaths;
  final String? sourcePath;

  const VaultMedia({
    required this.id,
    required this.path,
    required this.type,
    required this.title,
    required this.category,
    this.thumbnailPath,
    required this.createdAt,
    required this.favorite,
    required this.accentColor,
    this.videoAccentColors = const [],
    this.videoFramePaths = const [],
    this.sourcePath,
  });

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';

  VaultMedia copyWith({
    String? id,
    String? path,
    String? type,
    String? title,
    String? category,
    String? thumbnailPath,
    int? createdAt,
    bool? favorite,
    int? accentColor,
    List<int>? videoAccentColors,
    List<String>? videoFramePaths,
    String? sourcePath,
  }) {
    return VaultMedia(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      title: title ?? this.title,
      category: category ?? this.category,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      favorite: favorite ?? this.favorite,
      accentColor: accentColor ?? this.accentColor,
      videoAccentColors: videoAccentColors ?? this.videoAccentColors,
      videoFramePaths: videoFramePaths ?? this.videoFramePaths,
      sourcePath: sourcePath ?? this.sourcePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'type': type,
        'title': title,
        'category': category,
        'thumbnailPath': thumbnailPath,
        'createdAt': createdAt,
        'favorite': favorite,
        'accentColor': accentColor,
        'videoAccentColors': videoAccentColors,
        'videoFramePaths': videoFramePaths,
        'sourcePath': sourcePath,
      };

  factory VaultMedia.fromJson(Map<String, dynamic> json) {
    return VaultMedia(
      id: json['id'] as String,
      path: json['path'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      createdAt: json['createdAt'] as int,
      favorite: json['favorite'] as bool? ?? false,
      accentColor: json['accentColor'] as int?,
      videoAccentColors: (json['videoAccentColors'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList(),
      videoFramePaths: (json['videoFramePaths'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      sourcePath: json['sourcePath'] as String?,
    );
  }
}

class VaultStore extends ChangeNotifier {
  static const String _itemsKey = 'waifuvault_items_v1';
  static const String _privateKey = 'waifuvault_private_mode_v1';
  static const String _sdPathKey = 'waifuvault_sd_card_path_v1';

  final List<VaultMedia> _items = [];
  bool privateMode = false;
  String? sdCardPath;
  bool loaded = false;

  List<VaultMedia> get items {
    final sorted = [..._items];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_itemsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(list.map((e) => VaultMedia.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        _items.clear();
      }
    }
    privateMode = prefs.getBool(_privateKey) ?? false;
    sdCardPath = prefs.getString(_sdPathKey) ?? kFixedSdImportPath;
    loaded = true;
    notifyListeners();

    // V8.6: auto-scan folder publik setelah app kebuka.
    // Jadi file yang ditaruh manual di DCM Waifu bisa muncul tanpa import picker.
    Future.microtask(() async {
      await scanManagedFolders(silent: true);
    });
  }

  Future<({int internalAdded, int sdAdded})> scanManagedFolders({bool silent = false}) async {
    int internalAdded = 0;
    int sdAdded = 0;
    try {
      internalAdded = await importFromFolder(kPublicInternalVaultPath, category: 'Lainnya', silent: silent);
    } catch (_) {}
    try {
      final path = await resolveFixedSdImportPath();
      if (path != null) {
        sdCardPath = path;
        sdAdded = await importFromFolder(path, category: 'Lainnya', silent: silent);
      }
    } catch (_) {}
    if (!silent) {
      notifyListeners();
      await _save();
    }
    return (internalAdded: internalAdded, sdAdded: sdAdded);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_itemsKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
    await prefs.setBool(_privateKey, privateMode);
    if (sdCardPath == null || sdCardPath!.trim().isEmpty) {
      await prefs.remove(_sdPathKey);
    } else {
      await prefs.setString(_sdPathKey, sdCardPath!.trim());
    }
  }

  Future<void> add(VaultMedia item) async {
    _items.add(item);
    notifyListeners();
    await _save();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(favorite: !_items[index].favorite);
    notifyListeners();
    await _save();
  }

  Future<void> updateDetails(String id, {required String title, required String category}) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final cleanTitle = title.trim().isEmpty ? _items[index].title : title.trim();
    final cleanCategory = category.trim().isEmpty ? _items[index].category : category.trim();
    _items[index] = _items[index].copyWith(title: cleanTitle, category: cleanCategory);
    notifyListeners();
    await _save();
  }

  Future<void> deleteMany(Iterable<String> ids) async {
    final set = ids.toSet();
    if (set.isEmpty) return;
    final targets = _items.where((e) => set.contains(e.id)).toList();
    _items.removeWhere((e) => set.contains(e.id));
    notifyListeners();
    for (final item in targets) {
      await _deleteVaultFile(item.path);
      if (item.thumbnailPath != null) await _deleteVaultFile(item.thumbnailPath!);
      for (final framePath in item.videoFramePaths) {
        await _deleteVaultFile(framePath);
      }
    }
    await _save();
  }

  Future<void> updateVideoDynamicData(String id, VideoDynamicData data) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1 || data.accentColors.isEmpty) return;

    _items[index] = _items[index].copyWith(
      thumbnailPath: data.thumbnailPath ?? _items[index].thumbnailPath,
      accentColor: data.accentColors.first,
      videoAccentColors: data.accentColors,
      videoFramePaths: data.framePaths,
    );

    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final item = _items[index];
    _items.removeAt(index);
    notifyListeners();
    await _deleteVaultFile(item.path);
    if (item.thumbnailPath != null) {
      await _deleteVaultFile(item.thumbnailPath!);
    }
    for (final framePath in item.videoFramePaths) {
      await _deleteVaultFile(framePath);
    }
    await _save();
  }

  Future<void> _deleteVaultFile(String path) async {
    try {
      final isInternalVaultFile = isManagedInternalMediaPath(path) || isManagedInternalCachePath(path);
      final isSdPrimaryFile = isManagedSdMediaPath(path);
      if (!isInternalVaultFile && !isSdPrimaryFile) return;
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> setPrivateMode(bool value) async {
    privateMode = value;
    notifyListeners();
    await _save();
  }

  Future<void> setSdCardPath(String? value) async {
    final clean = value?.trim();
    sdCardPath = clean == null || clean.isEmpty ? null : clean;
    notifyListeners();
    await _save();
  }

  Map<String, dynamic> backupPayload() => {
        'app': 'WaifuVault',
        'version': '2.0.5 V9.3 Reference Final Polish',
        'exportedAt': DateTime.now().toIso8601String(),
        'itemCount': _items.length,
        'items': _items.map((e) => e.toJson()).toList(),
      };

  Future<String> exportBackup() async {
    final external = await getExternalStorageDirectory();
    final docs = await getApplicationDocumentsDirectory();
    final base = external ?? docs;
    final backupDir = Directory(p.join(base.path, 'WaifuVault_Backup'));
    if (!await backupDir.exists()) await backupDir.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File(p.join(backupDir.path, 'waifuvault_backup_$stamp.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(backupPayload()), flush: true);
    return file.path;
  }

  int get copiedFileCount {
    int count = 0;
    for (final item in _items) {
      if (isManagedInternalMediaPath(item.path)) count++;
      if (isManagedInternalCachePath(item.thumbnailPath ?? '')) count++;
      count += item.videoFramePaths.where(isManagedInternalCachePath).length;
    }
    return count;
  }

  Future<int> countMissingMediaFiles() async {
    int missing = 0;
    for (final item in _items) {
      if (!await File(item.path).exists()) missing++;
    }
    return missing;
  }

  Future<int> cleanMissingMediaItems() async {
    final before = _items.length;
    final kept = <VaultMedia>[];
    for (final item in _items) {
      if (await File(item.path).exists()) {
        kept.add(item);
      } else {
        if (item.thumbnailPath != null) await _deleteVaultFile(item.thumbnailPath!);
        for (final framePath in item.videoFramePaths) {
          await _deleteVaultFile(framePath);
        }
      }
    }
    _items
      ..clear()
      ..addAll(kept);
    final removed = before - _items.length;
    if (removed > 0) {
      notifyListeners();
      await _save();
    }
    return removed;
  }

  Future<int> importFromFolder(String folderPath, {String category = 'Lainnya', bool silent = false}) async {
    // V8.6: Dual Folder Auto Scan + startup permission scan.
    // Media dari SD Card tetap di SD Card sebagai path utama, tanpa copy ke internal.
    // Media dari picker biasa dicopy ke folder publik internal: /storage/emulated/0/DCM Waifu/.
    // Saat item SD dihapus dari WaifuVault, file asli di folder SD ikut dihapus.
    final files = await findMediaFiles(folderPath);
    var added = 0;
    for (final file in files) {
      final originalPath = file.path;
      if (_items.any((e) => e.sourcePath == originalPath || e.path == originalPath)) continue;
      final type = mediaTypeFromPath(originalPath);
      if (type == null) continue;
      try {
        final linkedPath = originalPath;
        VideoDynamicData? videoData;
        if (type == 'video') {
          videoData = await makeVideoDynamicData(linkedPath);
        }
        final thumbPath = videoData?.thumbnailPath;
        final accent = type == 'video' && (videoData?.accentColors.isNotEmpty ?? false)
            ? videoData!.accentColors.first
            : await accentFromImageFile(type == 'video' ? (thumbPath ?? linkedPath) : linkedPath, fallback: type == 'video' ? kBlue.value : kPurple.value);
        _items.add(
          VaultMedia(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            path: linkedPath,
            type: type,
            title: titleFromFile(originalPath, type),
            category: type == 'video' ? 'Video JJ' : category,
            thumbnailPath: thumbPath,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            favorite: false,
            accentColor: accent,
            videoAccentColors: videoData?.accentColors ?? const [],
            videoFramePaths: videoData?.framePaths ?? const [],
            sourcePath: originalPath,
          ),
        );
        added++;
      } catch (_) {}
    }
    if (added > 0) {
      if (!silent) notifyListeners();
      await _save();
      if (silent) notifyListeners();
    }
    return added;
  }

  int countFor(String category) => _items.where((e) => e.category == category).length;
  int get imageCount => _items.where((e) => e.isImage).length;
  int get videoCount => _items.where((e) => e.isVideo).length;
  int get favoriteCount => _items.where((e) => e.favorite).length;
}

class WaifuVaultApp extends StatefulWidget {
  const WaifuVaultApp({super.key});

  @override
  State<WaifuVaultApp> createState() => _WaifuVaultAppState();
}

class _WaifuVaultAppState extends State<WaifuVaultApp> {
  final VaultStore store = VaultStore();

  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hoshino',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return DefaultTextStyle.merge(
          style: const TextStyle(decoration: TextDecoration.none),
          child: child ?? const SizedBox.shrink(),
        );
      },
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPink,
          brightness: Brightness.dark,
          primary: kPink,
          secondary: kBlue,
          surface: kPanel,
        ),
        fontFamily: 'Roboto',
      ),
      home: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (!store.loaded) {
            return const SplashLoadingScreen();
          }
          return VaultShell(store: store);
        },
      ),
    );
  }
}

class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const VaultLogo(size: 96),
              const SizedBox(height: 24),
              GradientText(
                'Hoshino',
                style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w500, letterSpacing: 1.3),
              ),
              const SizedBox(height: 8),
              const Text('✦ Private Waifu Gallery ✦', style: TextStyle(color: kCosmicGold, letterSpacing: 2.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class VaultShell extends StatefulWidget {
  final VaultStore store;
  const VaultShell({super.key, required this.store});

  @override
  State<VaultShell> createState() => _VaultShellState();
}

class _VaultShellState extends State<VaultShell> {
  int index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void openAddMedia() {
    Navigator.push(context, smoothPageRoute(AddMediaScreen(store: widget.store)));
  }

  void _goToTab(int newIndex) {
    if (newIndex == index) return;
    setState(() => index = newIndex);
    _pageController.animateToPage(
      newIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      RepaintBoundary(child: HomeScreen(store: widget.store)),
      RepaintBoundary(child: GalleryScreen(store: widget.store)),
      RepaintBoundary(child: VoiceScreen(store: widget.store)),
      RepaintBoundary(child: ProfileScreen(store: widget.store)),
    ];

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        allowImplicitScrolling: true,
        children: pages,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 78,
              decoration: BoxDecoration(
                color: const Color(0xD0081026),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Color(0x339D5CFF), blurRadius: 24, offset: Offset(0, 12)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  BottomNavButton(
                    label: 'Home',
                    icon: Icons.home_rounded,
                    active: index == 0,
                    onTap: () => _goToTab(0),
                  ),
                  BottomNavButton(
                    label: 'Gallery',
                    icon: Icons.grid_view_rounded,
                    active: index == 1,
                    onTap: () => _goToTab(1),
                  ),
                  BottomNavButton(
                    label: 'Voice',
                    icon: Icons.graphic_eq_rounded,
                    active: index == 2,
                    onTap: () => _goToTab(2),
                  ),
                  BottomNavButton(
                    label: 'Profile',
                    icon: Icons.person_rounded,
                    active: index == 3,
                    onTap: () => _goToTab(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class HomeScreen extends StatefulWidget {
  final VaultStore store;
  const HomeScreen({super.key, required this.store});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool startupScanDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => runStartupFolderScan());
  }

  Future<void> runStartupFolderScan() async {
    if (startupScanDone || !mounted) return;
    startupScanDone = true;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final allowed = await ensureStorageAccessForFixedSd(context);
    if (!mounted || !allowed) return;
    final result = await widget.store.scanManagedFolders(silent: true);
    if (!mounted) return;
    final added = result.internalAdded + result.sdAdded;
    if (added > 0) showSnack(context, '$added media otomatis masuk dari DCM Waifu.');
  }

  Future<void> scanAllManagedFoldersFromHome() async {
    final allowed = await ensureStorageAccessForFixedSd(context);
    if (!mounted) return;
    if (!allowed) {
      showSnack(context, 'Aktifkan izin file dulu, lalu scan ulang.');
      return;
    }
    final result = await widget.store.scanManagedFolders();
    if (!mounted) return;
    final added = result.internalAdded + result.sdAdded;
    showSnack(context, added == 0 ? 'Tidak ada media baru di DCM Waifu.' : '$added media baru masuk dari DCM Waifu.');
  }

  void showHomeMenu() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: kPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Menu Hoshino', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_rounded, color: kPink),
              title: const Text('Tambah Media'),
              subtitle: const Text('Pilih foto/video dari galeri', style: TextStyle(color: kTextSoft)),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(context, smoothPageRoute(AddMediaScreen(store: widget.store)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded, color: kBlue),
              title: const Text('Scan Semua DCM Waifu'),
              subtitle: const Text('Cek folder internal dan SD', style: TextStyle(color: kTextSoft)),
              onTap: () {
                Navigator.pop(sheetContext);
                scanAllManagedFoldersFromHome();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final latest = widget.store.items.isNotEmpty ? widget.store.items.first : null;
            final previewFile = mediaPreviewFile(latest);
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
              children: [
                CosmicHeader(title: 'Hoshino', subtitle: '✦  Private Waifu Gallery  ✦', onMenu: showHomeMenu),
                const SizedBox(height: 18),
                HomeWelcomeCard(store: widget.store, latest: latest, previewFile: previewFile),
                const SizedBox(height: 16),
                const Text('Quick Access', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.45,
                  children: [
                    QuickAccessTile(icon: Icons.image_rounded, label: 'Gallery', color: kPink, onTap: () => DefaultTabController.maybeOf(context)),
                    QuickAccessTile(icon: Icons.graphic_eq_rounded, label: 'Voice', color: kBlue, onTap: () => showSnack(context, 'Buka tab Voice dari bawah.')),
                    QuickAccessTile(icon: Icons.favorite_rounded, label: 'Favorites', color: kPink, onTap: () => showSnack(context, '${widget.store.favoriteCount} item favorit.')),
                    QuickAccessTile(icon: Icons.calendar_month_rounded, label: 'Moments', color: kPurple, onTap: scanAllManagedFoldersFromHome),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

File? mediaPreviewFile(VaultMedia? item) {
  if (item == null) return null;
  final path = item.isImage ? item.path : item.thumbnailPath;
  if (path == null) return null;
  final file = File(path);
  return file.existsSync() ? file : null;
}

class CosmicHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onMenu;
  final bool showBack;
  const CosmicHeader({super.key, required this.title, required this.subtitle, this.onMenu, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showBack)
            Positioned(left: 0, top: 18, child: NeonIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context))),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GradientText(title, style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w400, letterSpacing: 1.6, fontFamily: 'serif')),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: kCosmicGold, fontSize: 12, letterSpacing: 3.1, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (onMenu != null) Positioned(right: 0, top: 20, child: NeonIconButton(icon: Icons.more_vert_rounded, onTap: onMenu!)),
        ],
      ),
    );
  }
}

class HomeWelcomeCard extends StatelessWidget {
  final VaultStore store;
  final VaultMedia? latest;
  final File? previewFile;
  const HomeWelcomeCard({super.key, required this.store, required this.latest, required this.previewFile});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 286,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
        boxShadow: const [BoxShadow(color: Color(0x33779BFF), blurRadius: 26, offset: Offset(0, 14))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (previewFile != null)
            Image.file(previewFile!, fit: BoxFit.cover)
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF132044), Color(0xFF171A38), Color(0xFF090F22)],
                ),
              ),
            ),
          const Positioned.fill(child: CustomPaint(painter: MiniStarPainter())),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.15), Colors.black.withOpacity(0.82)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            right: 18,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back,', style: TextStyle(color: Colors.white.withOpacity(.86), fontSize: 12)),
                      const SizedBox(height: 2),
                      const Row(
                        children: [
                          Text('Sensei', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: .5)),
                          SizedBox(width: 8),
                          Icon(Icons.favorite_rounded, size: 18, color: kPink),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Hoshino is happy to see you again.', style: TextStyle(color: Colors.white.withOpacity(.70), fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.notifications_none_rounded, color: kPink),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(latest == null ? 'Good evening, Sensei.' : displayMediaTitle(latest!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${store.items.length} saved moments • ${store.favoriteCount} favorites', style: TextStyle(color: Colors.white.withOpacity(.72))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const QuickAccessTile({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.all(8),
        borderColor: color.withOpacity(.20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class GalleryScreen extends StatefulWidget {
  final VaultStore store;
  const GalleryScreen({super.key, required this.store});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String filter = 'all';
  String search = '';
  bool selectionMode = false;
  final Set<String> selectedIds = <String>{};

  List<VaultMedia> get filteredItems {
    var list = widget.store.items;
    if (filter == 'image') list = list.where((e) => e.isImage).toList();
    if (filter == 'video') list = list.where((e) => e.isVideo).toList();
    if (filter == 'favorite') list = list.where((e) => e.favorite).toList();
    if (search.trim().isNotEmpty) {
      final q = search.toLowerCase().trim();
      list = list.where((e) => e.title.toLowerCase().contains(q) || e.category.toLowerCase().contains(q)).toList();
    }
    return [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void toggleSelect(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
      selectionMode = selectedIds.isNotEmpty;
    });
  }

  void startSelect(String id) {
    setState(() {
      selectionMode = true;
      selectedIds.add(id);
    });
  }

  void clearSelection() => setState(() { selectionMode = false; selectedIds.clear(); });

  Future<void> deleteSelected() async {
    final ids = selectedIds.toList();
    if (ids.isEmpty) return;
    final ok = await confirmBulkDelete(context, ids.length);
    if (ok != true) return;
    clearSelection();
    await widget.store.deleteMany(ids);
    if (mounted) showSnack(context, '${ids.length} item dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: Text('Gallery', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: .6))),
                      const SizedBox(height: 14),
                      SearchBox(hint: 'Search memories...', onChanged: (v) => setState(() => search = v)),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          VaultChip(label: 'All', icon: Icons.favorite_rounded, active: filter == 'all', onTap: () => setState(() => filter = 'all')),
                          VaultChip(label: 'Cute', icon: Icons.auto_awesome_rounded, active: false, onTap: () => setState(() => filter = 'all')),
                          VaultChip(label: 'Wallpaper', icon: Icons.wallpaper_rounded, active: false, onTap: () => setState(() => filter = 'image')),
                          VaultChip(label: 'Live', icon: Icons.play_circle_rounded, active: filter == 'video', onTap: () => setState(() => filter = 'video')),
                          VaultChip(label: 'Favorite', icon: Icons.favorite_rounded, active: filter == 'favorite', onTap: () => setState(() => filter = 'favorite')),
                        ]),
                      ),
                      if (selectionMode) ...[
                        const SizedBox(height: 12),
                        SelectionToolbar(
                          count: selectedIds.length,
                          total: filteredItems.length,
                          onCancel: clearSelection,
                          onSelectAll: () => setState(() { selectedIds..clear()..addAll(filteredItems.map((e) => e.id)); selectionMode = selectedIds.isNotEmpty; }),
                          onDelete: deleteSelected,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (filteredItems.isEmpty)
                const SliverFillRemaining(hasScrollBody: false, child: EmptyState(title: 'Gallery kosong', subtitle: '', icon: Icons.image_rounded))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final item = filteredItems[i];
                      return AnimatedMediaEntry(
                        index: i,
                        child: MediaTile(
                          item: item,
                          store: widget.store,
                          selectionMode: selectionMode,
                          selected: selectedIds.contains(item.id),
                          onSelectedTap: () => toggleSelect(item.id),
                          onLongPress: () => startSelect(item.id),
                        ),
                      );
                    }, childCount: filteredItems.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoiceScreen extends StatelessWidget {
  final VaultStore store;
  const VoiceScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final latest = store.items.isNotEmpty ? store.items.first : null;
    final avatar = mediaPreviewFile(latest);
    return NeonBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: [
            const Center(child: Text('Voice', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w400, color: Colors.white, letterSpacing: .8, fontFamily: 'serif'))),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 138,
                    height: 138,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kBlue.withOpacity(.55), width: 2), boxShadow: const [BoxShadow(color: Color(0x6689B8FF), blurRadius: 38)]),
                    clipBehavior: Clip.antiAlias,
                    child: avatar != null ? Image.file(avatar, fit: BoxFit.cover) : const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [kPink, kBlue])), child: Icon(Icons.graphic_eq_rounded, size: 68)),
                  ),
                  Container(width: 46, height: 46, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kPink, kBlue])), child: const Icon(Icons.favorite_rounded, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(child: GradientText('Hoshino', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500))),
            const Center(child: Text('Voice Collection', style: TextStyle(color: kTextSoft))),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              SmallVoiceChip(label: 'Greeting', active: true),
              SmallVoiceChip(label: 'Cute'),
              SmallVoiceChip(label: 'Sleep'),
              SmallVoiceChip(label: 'Custom'),
            ]),
            const SizedBox(height: 18),
            GlassPanel(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: const [
                  FakeWaveform(),
                  SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.skip_previous_rounded, size: 36, color: Colors.white),
                    SizedBox(width: 22),
                    CirclePlayButton(),
                    SizedBox(width: 22),
                    Icon(Icons.skip_next_rounded, size: 36, color: Colors.white),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const VoiceLineTile(text: 'Good morning, Sensei.', time: '00:12'),
            const VoiceLineTile(text: 'You did great today!', time: '00:10'),
            const VoiceLineTile(text: 'Need a little break?', time: '00:11'),
            const VoiceLineTile(text: 'Sweet dreams, Sensei.', time: '00:13'),
          ],
        ),
      ),
    );
  }
}

class SmallVoiceChip extends StatelessWidget {
  final String label;
  final bool active;
  const SmallVoiceChip({super.key, required this.label, this.active = false});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: active ? kPink : Colors.white.withOpacity(.07), border: Border.all(color: active ? kPink : Colors.white12)),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : kTextSoft)),
  );
}

class FakeWaveform extends StatelessWidget {
  const FakeWaveform({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(height: 96, child: CustomPaint(painter: WavePainter()));
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round..strokeWidth = 3;
    for (int i = 0; i < 64; i++) {
      final x = i * (size.width / 63);
      final h = 12 + ((i * 17) % 35).toDouble();
      paint.color = Color.lerp(kBlue, kPink, i / 63)!.withOpacity(.88);
      canvas.drawLine(Offset(x, size.height / 2 - h / 2), Offset(x, size.height / 2 + h / 2), paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CirclePlayButton extends StatelessWidget {
  const CirclePlayButton({super.key});
  @override
  Widget build(BuildContext context) => Container(width: 62, height: 62, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kPink, kPurple])), child: const Icon(Icons.play_arrow_rounded, size: 38, color: Colors.white));
}

class VoiceLineTile extends StatelessWidget {
  final String text;
  final String time;
  const VoiceLineTile({super.key, required this.text, required this.time});
  @override
  Widget build(BuildContext context) => GlassPanel(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(children: [
      const Icon(Icons.play_circle_outline_rounded, color: kPink),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      Text(time, style: const TextStyle(color: kTextSoft, fontSize: 12)),
      const SizedBox(width: 8),
      const Icon(Icons.favorite_border_rounded, color: kTextSoft, size: 18),
    ]),
  );
}



class PremiumDashboard extends StatelessWidget {
  final VaultStore store;
  final List<VaultMedia> items;
  const PremiumDashboard({super.key, required this.store, required this.items});

  @override
  Widget build(BuildContext context) {
    final latest = store.items.isNotEmpty ? store.items.first : null;
    final latestImage = latest == null
        ? null
        : latest.isImage
            ? File(latest.path)
            : latest.thumbnailPath == null
                ? null
                : File(latest.thumbnailPath!);
    final accent = Color(latest?.accentColor ?? kPink.value);

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 318,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(0.24), blurRadius: 34, offset: const Offset(0, 18)),
              BoxShadow(color: kBlue.withOpacity(0.08), blurRadius: 44, offset: const Offset(0, -8)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (latestImage != null && latestImage.existsSync())
                Image.file(latestImage, fit: BoxFit.cover)
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF111D3D), Color(0xFF1B1735), Color(0xFF090E20)],
                    ),
                  ),
                ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22000000), Color(0x18000000), Color(0xCC000000)],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(child: CustomPaint(painter: MiniStarPainter())),
              Positioned(
                left: 20,
                top: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 14)),
                    const SizedBox(height: 2),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Sensei', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: 0.4)),
                        SizedBox(width: 8),
                        Icon(Icons.favorite_rounded, size: 18, color: kPink),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Koleksi Hoshino siap dibuka lagi.', style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 13)),
                  ],
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kPink.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: kPink.withOpacity(0.45)),
                      ),
                      child: const Text('V9.3 FINAL UI', style: TextStyle(fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      latest == null ? 'Good evening, Sensei.' : displayMediaTitle(latest),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text('${store.items.length} item • ${store.favoriteCount} favorit • ${store.videoCount} video', style: TextStyle(color: Colors.white.withOpacity(0.72))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: DashboardStat(icon: Icons.image_rounded, label: 'Gallery', value: '${store.imageCount}', color: kPink)),
            const SizedBox(width: 10),
            Expanded(child: DashboardStat(icon: Icons.graphic_eq_rounded, label: 'Video', value: '${store.videoCount}', color: kBlue)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: DashboardStat(icon: Icons.favorite_rounded, label: 'Favorite', value: '${store.favoriteCount}', color: kPink)),
            const SizedBox(width: 10),
            Expanded(child: DashboardStat(icon: Icons.auto_awesome_rounded, label: 'Moments', value: '${store.items.length}', color: kCosmicGold)),
          ],
        ),
      ],
    );
  }
}

class MiniStarPainter extends CustomPainter {
  const MiniStarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.8);
    final points = <Offset>[
      Offset(size.width * .18, size.height * .22),
      Offset(size.width * .76, size.height * .18),
      Offset(size.width * .88, size.height * .42),
      Offset(size.width * .34, size.height * .58),
      Offset(size.width * .63, size.height * .78),
    ];
    for (final point in points) {
      canvas.drawCircle(point, 1.2, paint);
      canvas.drawLine(Offset(point.dx - 4, point.dy), Offset(point.dx + 4, point.dy), paint..strokeWidth = .75);
      canvas.drawLine(Offset(point.dx, point.dy - 4), Offset(point.dx, point.dy + 4), paint..strokeWidth = .75);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashboardStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const DashboardStat({super.key, required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.085), color.withOpacity(0.08), Colors.white.withOpacity(0.035)],
        ),
        border: Border.all(color: color.withOpacity(0.30)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.11), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 11, color: kTextSoft, letterSpacing: .4)),
        ],
      ),
    );
  }
}

class CategoryScreen extends StatelessWidget {
  final VaultStore store;
  const CategoryScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: kPurple),
                    const SizedBox(width: 8),
                    GradientText('Kategori', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    const ProBadge(),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Pilih kategori koleksi favoritmu', style: TextStyle(color: kTextSoft)),
                const SizedBox(height: 20),
                for (final cat in defaultCategories)
                  CategoryCard(
                    category: cat,
                    count: store.countFor(cat.name),
                    onTap: () {
                      Navigator.push(context, smoothPageRoute(CategoryDetailScreen(store: store, category: cat.name)));
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CategoryDetailScreen extends StatelessWidget {
  final VaultStore store;
  final String category;
  const CategoryDetailScreen({super.key, required this.store, required this.category});

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final items = store.items.where((e) => e.category == category).toList();
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    child: Row(
                      children: [
                        NeonIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                        const SizedBox(width: 14),
                        Expanded(child: GradientText(category, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: 'Kategori kosong',
                      subtitle: 'Belum ada media di kategori $category.',
                      icon: Icons.folder_open_rounded,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate((context, i) => AnimatedMediaEntry(index: i, child: MediaTile(item: items[i], store: store)), childCount: items.length),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  final VaultStore store;
  const FavoritesScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final items = store.items.where((e) => e.favorite).toList();
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GradientText('Koleksi Saya', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('${items.length} item favorit', style: const TextStyle(color: kTextSoft)),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: 'Belum ada favorit',
                      subtitle: 'Tekan ikon hati di media untuk memasukkannya ke koleksi favorit.',
                      icon: Icons.favorite_border_rounded,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate((context, i) => AnimatedMediaEntry(index: i, child: MediaTile(item: items[i], store: store)), childCount: items.length),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}


class ProfileScreen extends StatelessWidget {
  final VaultStore store;
  const ProfileScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final latest = store.items.isNotEmpty ? store.items.first : null;
            final avatar = mediaPreviewFile(latest);
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              children: [
                const Center(child: Text('Profile', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w400, color: Colors.white, letterSpacing: .8, fontFamily: 'serif'))),
                const SizedBox(height: 18),
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: kPink.withOpacity(.35))),
                        clipBehavior: Clip.antiAlias,
                        child: avatar != null ? Image.file(avatar, fit: BoxFit.cover) : const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [kPink, kBlue])), child: Icon(Icons.favorite_rounded, size: 48)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Hoshino ✦', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500, color: Colors.white, fontFamily: 'serif')),
                            SizedBox(height: 5),
                            Text('Your devoted companion', style: TextStyle(color: kTextSoft)),
                            SizedBox(height: 12),
                            Text('Birthday', style: TextStyle(color: kTextSoft, fontSize: 12)),
                            Text('March 14', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            SizedBox(height: 8),
                            Text('Theme', style: TextStyle(color: kTextSoft, fontSize: 12)),
                            Text('Cosmic Pink', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: const [
                        Text('Bond Level', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        Spacer(),
                        Icon(Icons.favorite_rounded, color: kPink, size: 38),
                      ]),
                      const SizedBox(height: 4),
                      const Text('Lv. 28', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: .78, minHeight: 10, backgroundColor: Colors.white10, color: kPink),
                      ),
                      const SizedBox(height: 6),
                      const Align(alignment: Alignment.centerRight, child: Text('7,860 / 10,000', style: TextStyle(color: kTextSoft, fontSize: 12))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: ProfileMiniStat(icon: Icons.image_rounded, label: 'Saved Photos', value: '${store.imageCount}')),
                  const SizedBox(width: 10),
                  Expanded(child: ProfileMiniStat(icon: Icons.graphic_eq_rounded, label: 'Favorite Voice', value: '48')),
                  const SizedBox(width: 10),
                  Expanded(child: ProfileMiniStat(icon: Icons.favorite_rounded, label: 'Favorites', value: '${store.favoriteCount}')),
                ]),
                const SizedBox(height: 14),
                SettingsTile(icon: Icons.color_lens_rounded, title: 'Theme Color', subtitle: 'Pink / Blue', trailing: Icons.chevron_right_rounded),
                SettingsTile(icon: Icons.storage_rounded, title: 'Storage Mode', subtitle: 'Internal + SD DCM Waifu', trailing: Icons.chevron_right_rounded, onTap: () => Navigator.push(context, smoothPageRoute(StorageModeScreen(store: store)))),
                SettingsTile(icon: Icons.cloud_upload_rounded, title: 'Backup & Sync', subtitle: 'Backup JSON koleksi', trailing: Icons.chevron_right_rounded, onTap: () => Navigator.push(context, smoothPageRoute(StorageModeScreen(store: store)))),
                SettingsTile(icon: Icons.lock_rounded, title: 'App Lock', subtitle: 'Off', trailing: Icons.chevron_right_rounded),
                SettingsTile(icon: Icons.info_rounded, title: 'About', subtitle: 'v2.0.5+35 V9.3 Reference Final Polish', trailing: Icons.chevron_right_rounded),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ProfileMiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const ProfileMiniStat({super.key, required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
    child: Column(children: [
      Icon(icon, color: kPink, size: 24),
      const SizedBox(height: 7),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
      const SizedBox(height: 2),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextSoft, fontSize: 10)),
    ]),
  );
}




Future<bool> ensureStorageAccessForFixedSd(BuildContext context) async {
  if (!Platform.isAndroid) return true;
  try {
    if (await Permission.manageExternalStorage.isGranted) return true;

    // Normal media permissions help on Android 13+, but removable SD folder paths
    // usually need All files access for Directory.list to work reliably.
    await Permission.photos.request();
    await Permission.videos.request();
    await Permission.storage.request();

    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    if (!context.mounted) return false;
    final open = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Izinkan akses file'),
        content: const Text(
          'Android masih ngeblok scan folder SD Card langsung. Buka pengaturan aplikasi, aktifkan izin file / All files access untuk WaifuVault, lalu balik dan scan lagi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nanti')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Buka Settings')),
        ],
      ),
    );
    if (open == true) {
      await openAppSettings();
    }
    return false;
  } catch (_) {
    return true;
  }
}

Future<String?> resolveFixedSdImportPath() async {
  for (final raw in kFixedSdImportPathCandidates) {
    final clean = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    final dir = Directory(clean);
    try {
      if (await dir.exists()) return clean;
    } catch (_) {}
  }
  return null;
}

class StorageModeScreen extends StatefulWidget {
  final VaultStore store;
  const StorageModeScreen({super.key, required this.store});

  @override
  State<StorageModeScreen> createState() => _StorageModeScreenState();
}

class _StorageModeScreenState extends State<StorageModeScreen> {
  bool busy = false;
  String? lastMessage;
  String? lastBackupPath;
  int? missingCount;

  Future<void> exportBackup() async {
    if (busy) return;
    setState(() {
      busy = true;
      lastMessage = 'Membuat backup...';
    });
    try {
      final path = await widget.store.exportBackup();
      if (!mounted) return;
      setState(() {
        busy = false;
        lastBackupPath = path;
        lastMessage = 'Backup berhasil dibuat.';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup WaifuVault berhasil dibuat.')));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        lastMessage = 'Gagal membuat backup.';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuat backup.')));
    }
  }

  Future<void> scanMissing() async {
    if (busy) return;
    setState(() {
      busy = true;
      lastMessage = 'Scan file media...';
    });
    final count = await widget.store.countMissingMediaFiles();
    if (!mounted) return;
    setState(() {
      busy = false;
      missingCount = count;
      lastMessage = count == 0 ? 'Semua file media aman.' : '$count item file medianya hilang.';
    });
  }

  Future<void> cleanMissing() async {
    if (busy) return;
    setState(() {
      busy = true;
      lastMessage = 'Membersihkan item rusak...';
    });
    final removed = await widget.store.cleanMissingMediaItems();
    if (!mounted) return;
    setState(() {
      busy = false;
      missingCount = null;
      lastMessage = removed == 0 ? 'Tidak ada item rusak.' : '$removed item rusak dibersihkan.';
    });
  }

  Future<void> scanAllManagedFolders() async {
    if (busy) return;
    setState(() {
      busy = true;
      lastMessage = 'Cek izin storage Android...';
    });

    final allowed = await ensureStorageAccessForFixedSd(context);
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        busy = false;
        lastMessage = 'Izin file belum aktif. Aktifkan All files access lalu scan ulang.';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aktifkan izin file dulu, lalu scan ulang.')));
      return;
    }

    setState(() {
      busy = true;
      lastMessage = 'Scan internal + SD DCM Waifu...';
    });

    final internalFound = await findMediaFiles(kPublicInternalVaultPath);
    final sdPath = await resolveFixedSdImportPath();
    final sdFound = sdPath == null ? <File>[] : await findMediaFiles(sdPath);
    final result = await widget.store.scanManagedFolders();

    if (!mounted) return;
    final totalFound = internalFound.length + sdFound.length;
    final totalAdded = result.internalAdded + result.sdAdded;
    setState(() {
      busy = false;
      lastMessage = totalFound == 0
          ? 'Dua folder kebaca, tapi 0 media didukung. Cek ekstensi file atau izin storage.'
          : 'Scan selesai: internal ${internalFound.length} file, SD ${sdFound.length} file, $totalAdded item baru masuk.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(totalAdded == 0 ? 'Tidak ada item baru. Media mungkin sudah masuk.' : '$totalAdded media baru masuk dari folder DCM Waifu.')),
    );
  }

  Future<void> importFixedSdFolder() async {
    if (busy) return;
    setState(() {
      busy = true;
      lastMessage = 'Cek izin storage Android...';
    });

    final allowed = await ensureStorageAccessForFixedSd(context);
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        busy = false;
        lastMessage = 'Izin file belum aktif. Aktifkan All files access lalu scan ulang.';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aktifkan izin file dulu, lalu scan ulang.')));
      return;
    }

    final path = await resolveFixedSdImportPath();
    if (path == null) {
      if (!mounted) return;
      setState(() {
        busy = false;
        lastMessage = 'Folder SD belum ketemu: $kFixedSdImportPath';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folder SD belum ketemu. Cek nama folder DCM Waifu.')));
      return;
    }

    setState(() {
      busy = true;
      lastMessage = 'Scan folder SD: $path';
    });
    await widget.store.setSdCardPath(path);
    final found = await findMediaFiles(path);
    final added = await widget.store.importFromFolder(path);
    if (!mounted) return;
    setState(() {
      busy = false;
      lastMessage = found.isEmpty
          ? 'Folder kebaca, tapi 0 media didukung. Cek ekstensi file: jpg/png/webp/heic/mp4/mov/mkv.'
          : 'SD scan selesai: ketemu ${found.length} media, $added item baru masuk path SD.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          found.isEmpty
              ? 'Folder kebaca, tapi media belum terdeteksi. Cek izin/ekstensi file.'
              : (added == 0 ? 'Media sudah pernah masuk / tidak ada item baru.' : '$added media berhasil masuk dari path SD.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                children: [
                  Row(
                    children: [
                      NeonIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GradientText('Storage Mode', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                      ),
                      const ProBadge(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GlassPanel(
                    padding: const EdgeInsets.all(18),
                    borderColor: kBlue.withOpacity(0.32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(colors: [kBlue, kPurple]),
                                boxShadow: const [BoxShadow(color: Color(0x6600E5FF), blurRadius: 24)],
                              ),
                              child: const Icon(Icons.folder_copy_rounded, color: Colors.white, size: 30),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dual Folder Auto Scan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                                  SizedBox(height: 4),
                                  Text('Taruh file manual di folder DCM Waifu, lalu scan / buka ulang.', style: TextStyle(color: kTextSoft)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'V8.10 Smooth Tab: transisi dibuat lebih ringan, FPS lebih stabil di HP, card media lebih clean, nama file panjang otomatis dirapikan jadi Foto Baru / Video Baru.',
                          style: TextStyle(color: kTextSoft, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: DashboardStat(icon: Icons.grid_view_rounded, label: 'Item', value: '${widget.store.items.length}', color: kPurple)),
                      const SizedBox(width: 10),
                      Expanded(child: DashboardStat(icon: Icons.sd_storage_rounded, label: 'Public', value: '${widget.store.copiedFileCount}', color: kBlue)),
                      const SizedBox(width: 10),
                      Expanded(child: DashboardStat(icon: Icons.favorite_rounded, label: 'Favorit', value: '${widget.store.favoriteCount}', color: kPink)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GlassPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Backup Koleksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        const Text('Bikin file JSON berisi data koleksi. Media tetap ada di folder DCM Waifu internal/SD, backup ini buat daftar item dan metadata.', style: TextStyle(color: kTextSoft)),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: busy ? null : exportBackup,
                            style: FilledButton.styleFrom(backgroundColor: kPink, foregroundColor: Colors.white),
                            icon: const Icon(Icons.cloud_upload_rounded),
                            label: const Text('Buat Backup JSON'),
                          ),
                        ),
                        if (lastBackupPath != null) ...[
                          const SizedBox(height: 12),
                          SelectableText(lastBackupPath!, style: const TextStyle(color: kTextSoft, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Perawatan Storage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                          missingCount == null ? 'Scan file untuk cek apakah ada item yang filenya hilang.' : 'Hasil scan: $missingCount file hilang.',
                          style: const TextStyle(color: kTextSoft),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : scanMissing,
                                icon: const Icon(Icons.search_rounded),
                                label: const Text('Scan'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : cleanMissing,
                                icon: const Icon(Icons.cleaning_services_rounded),
                                label: const Text('Bersihkan'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: busy ? null : scanAllManagedFolders,
                    child: GlassPanel(
                      padding: const EdgeInsets.all(16),
                      borderColor: kBlue.withOpacity(0.34),
                      child: Row(
                        children: [
                          const Icon(Icons.sync_rounded, color: kBlue, size: 32),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scan Semua DCM Waifu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                                SizedBox(height: 4),
                                Text('Baca internal + SD. Cocok kalau lu pindah file manual ke folder.', style: TextStyle(color: kTextSoft)),
                                SizedBox(height: 4),
                                Text('/storage/emulated/0/DCM Waifu/ + /storage/4394-15F8/DCM Waifu/', style: TextStyle(color: kTextSoft, fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) else const Icon(Icons.sync_rounded, color: kPink),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: busy ? null : importFixedSdFolder,
                    child: GlassPanel(
                      padding: const EdgeInsets.all(16),
                      borderColor: kPurple.withOpacity(0.3),
                      child: Row(
                        children: [
                          const Icon(Icons.sd_storage_rounded, color: kPurple, size: 32),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scan SD Card DCM Waifu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                                SizedBox(height: 4),
                                Text('Path tetap: /storage/4394-15F8/DCM Waifu/', style: TextStyle(color: kTextSoft)),
                                SizedBox(height: 4),
                                Text('Scan khusus SD. Media tetap di SD; hapus item = hapus file SD.', style: TextStyle(color: kTextSoft, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) else const Icon(Icons.drive_folder_upload_rounded, color: kBlue),
                        ],
                      ),
                    ),
                  ),
                  if (busy || lastMessage != null) ...[
                    const SizedBox(height: 14),
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) else const Icon(Icons.check_circle_rounded, color: kBlue),
                          const SizedBox(width: 12),
                          Expanded(child: Text(lastMessage ?? 'Memproses...', style: const TextStyle(color: kTextSoft))),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}


Future<Directory> getVaultDirectory(String folderName) async {
  // V8.6: jangan simpan media utama di folder private /data/user/0.
  // Import biasa masuk folder publik internal, namanya disamain dengan folder SD: DCM Waifu.
  Directory dir;
  if (folderName == 'waifuvault_media') {
    dir = Directory(kPublicInternalVaultPath);
  } else if (folderName == 'waifuvault_thumbs') {
    dir = Directory(kPublicInternalCachePath);
  } else {
    final base = await getApplicationDocumentsDirectory();
    dir = Directory(p.join(base.path, folderName));
  }
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

bool isManagedSdMediaPath(String filePath) {
  final normalized = filePath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final base = kFixedSdImportPath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  return normalized.startsWith('$base/');
}

bool isManagedInternalMediaPath(String filePath) {
  final normalized = filePath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final base = kPublicInternalVaultPath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final cacheBase = kPublicInternalCachePath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  return normalized.startsWith('$base/') && !normalized.startsWith('$cacheBase/');
}

bool isManagedInternalCachePath(String filePath) {
  final normalized = filePath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final base = kPublicInternalCachePath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  return normalized.startsWith('$base/');
}

Future<String> copyFileToVault(String originalPath, String mediaType) async {
  final source = File(originalPath);
  final mediaDir = await getVaultDirectory('waifuvault_media');
  final ext = p.extension(originalPath).isEmpty ? (mediaType == 'video' ? '.mp4' : '.jpg') : p.extension(originalPath);
  final safeExt = ext.toLowerCase();
  final name = '${DateTime.now().microsecondsSinceEpoch}_$mediaType$safeExt';
  final targetPath = p.join(mediaDir.path, name);
  return (await source.copy(targetPath)).path;
}

String? mediaTypeFromPath(String filePath) {
  final ext = p.extension(filePath).toLowerCase();
  const imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.heif', '.bmp', '.avif'};
  const videoExts = {'.mp4', '.mov', '.m4v', '.3gp', '.webm', '.mkv', '.avi'};
  if (imageExts.contains(ext)) return 'image';
  if (videoExts.contains(ext)) return 'video';
  return null;
}

String titleFromFile(String filePath, String type) {
  return type == 'video' ? 'Video Baru' : 'Foto Baru';
}

Future<List<File>> findMediaFiles(String folderPath, {int limit = 200}) async {
  final root = Directory(folderPath);
  final files = <File>[];
  if (!await root.exists()) return files;
  try {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (files.length >= limit) break;
      if (entity is! File) continue;
      if (mediaTypeFromPath(entity.path) == null) continue;
      files.add(entity);
    }
  } catch (_) {}
  files.sort((a, b) {
    try {
      return b.statSync().modified.compareTo(a.statSync().modified);
    } catch (_) {
      return b.path.compareTo(a.path);
    }
  });
  return files;
}

Future<String?> makeVideoThumb(String videoPath, {int timeMs = 0}) async {
  try {
    final thumbDir = await getVaultDirectory('waifuvault_thumbs');
    final bytes = await VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 720,
      timeMs: timeMs,
      quality: 82,
    );
    if (bytes == null || bytes.isEmpty) return null;

    final safeBase = p.basenameWithoutExtension(videoPath).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeTime = timeMs.clamp(0, 999999999).toInt();
    final out = File(p.join(
      thumbDir.path,
      '${safeBase}_${safeTime}_${DateTime.now().microsecondsSinceEpoch}.jpg',
    ));
    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  } catch (_) {
    return null;
  }
}

Future<int> accentFromImageFile(String path, {int fallback = 0xFF00E5FF}) async {
  try {
    final palette = await PaletteGenerator.fromImageProvider(
      FileImage(File(path)),
      maximumColorCount: 16,
    );
    return (palette.vibrantColor ?? palette.dominantColor ?? palette.mutedColor)?.color.value ?? fallback;
  } catch (_) {
    return fallback;
  }
}

Future<Duration?> getVideoDurationForSampling(String videoPath) async {
  VideoPlayerController? probe;
  try {
    probe = VideoPlayerController.file(File(videoPath));
    await probe.initialize();
    return probe.value.duration;
  } catch (_) {
    return null;
  } finally {
    await probe?.dispose();
  }
}

class VideoDynamicData {
  final String? thumbnailPath;
  final List<String> framePaths;
  final List<int> accentColors;

  const VideoDynamicData({
    required this.thumbnailPath,
    required this.framePaths,
    required this.accentColors,
  });
}

Future<VideoDynamicData> makeVideoDynamicData(String videoPath) async {
  final duration = await getVideoDurationForSampling(videoPath);
  final totalMs = duration?.inMilliseconds ?? 0;
  final safeTotal = totalMs <= 0 ? 12000 : totalMs;
  final points = <int>[
    0,
    (safeTotal * 0.25).round(),
    (safeTotal * 0.50).round(),
    (safeTotal * 0.75).round(),
    (safeTotal * 0.95).round(),
  ];

  final framePaths = <String>[];
  final colors = <int>[];
  final seenPaths = <String>{};

  for (final rawPoint in points) {
    final timeMs = rawPoint.clamp(0, safeTotal).toInt();
    final framePath = await makeVideoThumb(videoPath, timeMs: timeMs);
    if (framePath == null || !File(framePath).existsSync()) continue;
    if (!seenPaths.add(framePath)) continue;
    framePaths.add(framePath);
    colors.add(await accentFromImageFile(framePath, fallback: colors.isEmpty ? kBlue.value : colors.last));
  }

  if (framePaths.isEmpty) {
    final fallbackThumb = await makeVideoThumb(videoPath);
    if (fallbackThumb != null && File(fallbackThumb).existsSync()) {
      framePaths.add(fallbackThumb);
      colors.add(await accentFromImageFile(fallbackThumb, fallback: kBlue.value));
    }
  }

  return VideoDynamicData(
    thumbnailPath: framePaths.isEmpty ? null : framePaths.first,
    framePaths: framePaths,
    accentColors: colors,
  );
}

class AddMediaScreen extends StatefulWidget {
  final VaultStore store;
  const AddMediaScreen({super.key, required this.store});

  @override
  State<AddMediaScreen> createState() => _AddMediaScreenState();
}

class _AddMediaScreenState extends State<AddMediaScreen> {
  final picker = ImagePicker();
  final titleController = TextEditingController();
  String category = defaultCategories.first.name;
  String? selectedPath;
  String? selectedType;
  bool saving = false;

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (file == null) return;
    setState(() {
      selectedPath = file.path;
      selectedType = 'image';
      if (titleController.text.trim().isEmpty) titleController.text = 'Foto Baru';
    });
  }

  Future<void> pickVideo() async {
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      selectedPath = file.path;
      selectedType = 'video';
      category = 'Video JJ';
      if (titleController.text.trim().isEmpty) titleController.text = 'Video Baru';
    });
  }

  Future<int?> getAccent(String path, String type, {String? thumbnailPath}) async {
    final targetPath = type == 'video' ? thumbnailPath : path;
    if (targetPath == null) return kBlue.value;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(File(targetPath)),
        maximumColorCount: 12,
      );
      return (palette.vibrantColor ?? palette.dominantColor ?? palette.mutedColor)?.color.value;
    } catch (_) {
      return type == 'video' ? kBlue.value : kPurple.value;
    }
  }

  Future<void> saveMedia() async {
    if (selectedPath == null || selectedType == null || saving) return;
    setState(() => saving = true);
    try {
      final copiedPath = await copyFileToVault(selectedPath!, selectedType!);
      VideoDynamicData? videoData;
      if (selectedType == 'video') {
        videoData = await makeVideoDynamicData(copiedPath);
      }
      final thumbPath = videoData?.thumbnailPath;
      final accent = selectedType == 'video' && (videoData?.accentColors.isNotEmpty ?? false)
          ? videoData!.accentColors.first
          : await getAccent(copiedPath, selectedType!, thumbnailPath: thumbPath);
      final media = VaultMedia(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        path: copiedPath,
        type: selectedType!,
        title: titleController.text.trim().isEmpty ? 'Untitled' : titleController.text.trim(),
        category: category,
        thumbnailPath: thumbPath,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        favorite: false,
        accentColor: accent,
        videoAccentColors: videoData?.accentColors ?? const [],
        videoFramePaths: videoData?.framePaths ?? const [],
        sourcePath: selectedPath,
      );
      await widget.store.add(media);
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan media. Coba pilih file lain.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = selectedPath != null && selectedType != null;
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              Row(
                children: [
                  NeonIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 14),
                  Expanded(child: GradientText('Tambah Media', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Tambahkan foto atau video ke koleksi WaifuVault Anda.', textAlign: TextAlign.center, style: TextStyle(color: kTextSoft)),
              const SizedBox(height: 20),
              ImportCard(
                title: 'Impor Foto',
                subtitle: 'Pilih foto dari perangkat Anda',
                button: 'Pilih Foto',
                icon: Icons.image_rounded,
                colors: const [kPink, kPurple],
                onTap: pickImage,
              ),
              const SizedBox(height: 14),
              ImportCard(
                title: 'Impor Video',
                subtitle: 'Pilih video dari perangkat Anda',
                button: 'Pilih Video',
                icon: Icons.play_arrow_rounded,
                colors: const [kBlue, kPurple],
                onTap: pickVideo,
              ),
              const SizedBox(height: 16),
              GlassPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Info Media', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Judul',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: InputDecoration(
                        labelText: 'Kategori',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      ),
                      items: defaultCategories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                      onChanged: (v) => setState(() => category = v ?? category),
                    ),
                    const SizedBox(height: 16),
                    if (hasMedia)
                      PreviewMini(path: selectedPath!, type: selectedType!)
                    else
                      Container(
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white12),
                          color: Colors.white.withOpacity(0.04),
                        ),
                        child: const Text('Belum ada file dipilih', style: TextStyle(color: kTextSoft)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(colors: [kPurple, kPink]),
                  boxShadow: const [BoxShadow(color: Color(0x66FF4FB8), blurRadius: 24)],
                ),
                child: FilledButton.icon(
                  onPressed: hasMedia && !saving ? saveMedia : null,
                  style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, disabledBackgroundColor: Colors.white10),
                  icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
                  label: Text(saving ? 'Menyimpan...' : 'Tambah ke Koleksi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImagePreviewScreen extends StatelessWidget {
  final VaultMedia item;
  final VaultStore store;
  const ImagePreviewScreen({super.key, required this.item, required this.store});

  @override
  Widget build(BuildContext context) {
    final file = File(item.path);
    final accent = Color(item.accentColor ?? kPurple.value);
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AdaptiveMediaBackground(
              accent: accent,
              imagePath: file.existsSync() ? item.path : null,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      NeonIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      Expanded(child: GradientText('WaifuVault', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
                      NeonIconButton(icon: item.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, onTap: () => store.toggleFavorite(item.id)),
                      const SizedBox(width: 8),
                      NeonIconButton(icon: Icons.more_vert_rounded, onTap: () => showMediaOptionsSheet(context, store, item)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Hero(
                      tag: mediaHeroTag(item),
                      transitionOnUserGestures: true,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: file.existsSync()
                            ? InteractiveViewer(child: Image.file(file, fit: BoxFit.contain, width: double.infinity))
                            : const Center(child: Text('File tidak ditemukan')),
                      ),
                    ),
                  ),
                ),
                PreviewActionPanel(
                  accent: accent,
                  title: displayMediaTitle(item),
                  subtitle: '${item.category} • ${formatDate(item.createdAt)}',
                  indexText: '1 / ${store.items.length}',
                  favorite: item.favorite,
                  onFavorite: () => store.toggleFavorite(item.id),
                  onDelete: () => confirmDelete(context, store, item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPreviewScreen extends StatefulWidget {
  final VaultMedia item;
  final VaultStore store;
  const VideoPreviewScreen({super.key, required this.item, required this.store});

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  VideoPlayerController? controller;
  bool ready = false;
  bool missing = false;
  bool generatingDynamicColors = false;
  late List<int> localVideoAccentColors;
  late List<String> localVideoFramePaths;
  String? localThumbnailPath;

  @override
  void initState() {
    super.initState();
    localVideoAccentColors = List<int>.from(widget.item.videoAccentColors);
    localVideoFramePaths = List<String>.from(widget.item.videoFramePaths);
    localThumbnailPath = widget.item.thumbnailPath;

    final file = File(widget.item.path);
    if (!file.existsSync()) {
      missing = true;
      return;
    }
    controller = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (!mounted) return;
        controller!.addListener(() {
          if (mounted) setState(() {});
        });
        controller!.setLooping(false);
        setState(() => ready = true);
        ensureDynamicColors();
      });
  }

  Future<void> ensureDynamicColors() async {
    if (generatingDynamicColors || localVideoAccentColors.length > 1) return;
    if (!File(widget.item.path).existsSync()) return;

    setState(() => generatingDynamicColors = true);
    final data = await makeVideoDynamicData(widget.item.path);
    if (!mounted) return;

    if (data.accentColors.isNotEmpty) {
      setState(() {
        localVideoAccentColors = data.accentColors;
        localVideoFramePaths = data.framePaths;
        localThumbnailPath = data.thumbnailPath ?? localThumbnailPath;
        generatingDynamicColors = false;
      });
      await widget.store.updateVideoDynamicData(widget.item.id, data);
    } else {
      setState(() => generatingDynamicColors = false);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void togglePlay() {
    if (controller == null || !ready) return;
    if (controller!.value.isPlaying) {
      controller!.pause();
    } else {
      controller!.play();
    }
    setState(() {});
  }

  void seekBy(int seconds) {
    if (controller == null || !ready) return;
    final current = controller!.value.position;
    final target = current + Duration(seconds: seconds);
    final duration = controller!.value.duration;
    if (target < Duration.zero) {
      controller!.seekTo(Duration.zero);
    } else if (target > duration) {
      controller!.seekTo(duration);
    } else {
      controller!.seekTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = ready ? controller!.value.duration : Duration.zero;
    final position = ready ? controller!.value.position : Duration.zero;
    final progress = duration.inMilliseconds == 0 ? 0.0 : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final dynamicCount = localVideoAccentColors.length;
    final dynamicIndex = dynamicCount <= 1 ? 0 : (progress * (dynamicCount - 1)).round().clamp(0, dynamicCount - 1).toInt();
    final accentValue = dynamicCount > 0 ? localVideoAccentColors[dynamicIndex] : (widget.item.accentColor ?? kBlue.value);
    final accent = Color(accentValue);
    final dynamicFramePath = localVideoFramePaths.length > dynamicIndex && File(localVideoFramePaths[dynamicIndex]).existsSync()
        ? localVideoFramePaths[dynamicIndex]
        : localThumbnailPath;

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AdaptiveMediaBackground(
              accent: accent,
              imagePath: dynamicFramePath != null && File(dynamicFramePath).existsSync() ? dynamicFramePath : null,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      NeonIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                      const Spacer(),
                      const Text('Video JJ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(width: 8),
                      if (generatingDynamicColors)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                        )
                      else
                        const ProBadge(),
                      const Spacer(),
                      NeonIconButton(icon: Icons.cast_rounded, onTap: () => showPreviewModeSheet(context)),
                      const SizedBox(width: 8),
                      NeonIconButton(icon: Icons.more_vert_rounded, onTap: () => showMediaOptionsSheet(context, widget.store, widget.item, onRefreshVideoColors: ensureDynamicColors)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Hero(
                        tag: mediaHeroTag(widget.item),
                        transitionOnUserGestures: true,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            color: Colors.black,
                            child: missing
                                ? const Center(child: Text('File video tidak ditemukan'))
                                : ready
                                    ? AspectRatio(aspectRatio: controller!.value.aspectRatio, child: VideoPlayer(controller!))
                                    : const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Row(
                    children: [
                      Text(formatDuration(position), style: const TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: progress,
                          activeColor: kPink,
                          inactiveColor: Colors.white24,
                          onChanged: ready
                              ? (v) {
                                  final target = Duration(milliseconds: (duration.inMilliseconds * v).round());
                                  controller!.seekTo(target);
                                }
                              : null,
                        ),
                      ),
                      Text(formatDuration(duration), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(onPressed: () => seekBy(-10), icon: const Icon(Icons.replay_10_rounded), iconSize: 34),
                    IconButton(onPressed: () => seekBy(-3), icon: const Icon(Icons.skip_previous_rounded), iconSize: 42),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [accent.withOpacity(0.95), kPink]),
                        boxShadow: [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 28)],
                      ),
                      child: IconButton(
                        onPressed: togglePlay,
                        icon: Icon(ready && controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        iconSize: 42,
                      ),
                    ),
                    IconButton(onPressed: () => seekBy(3), icon: const Icon(Icons.skip_next_rounded), iconSize: 42),
                    IconButton(onPressed: () => seekBy(10), icon: const Icon(Icons.forward_10_rounded), iconSize: 34),
                  ],
                ),
                const SizedBox(height: 12),
                GlassPanel(
                  margin: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(displayMediaTitle(widget.item), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                          IconButton(
                            onPressed: () => widget.store.toggleFavorite(widget.item.id),
                            icon: Icon(widget.item.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: widget.item.favorite ? kPink : Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${widget.item.category} • ${formatDate(widget.item.createdAt)}', style: const TextStyle(color: kTextSoft)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: SmallInfoButton(label: 'Kualitas', value: '1080p', icon: Icons.hd_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: SmallInfoButton(label: 'Kecepatan', value: '1.0x', icon: Icons.speed_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: SmallInfoButton(label: 'Ulangi', value: 'Nonaktif', icon: Icons.repeat_rounded)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class SdCardPathScreen extends StatefulWidget {
  final VaultStore store;
  const SdCardPathScreen({super.key, required this.store});

  @override
  State<SdCardPathScreen> createState() => _SdCardPathScreenState();
}

class _SdCardPathScreenState extends State<SdCardPathScreen> {
  late final TextEditingController pathController;
  bool scanning = false;
  bool importing = false;
  String? importInfo;
  List<String> detectedPaths = [];

  @override
  void initState() {
    super.initState();
    pathController = TextEditingController(text: widget.store.sdCardPath ?? '');
    scanStorageRoots();
  }

  @override
  void dispose() {
    pathController.dispose();
    super.dispose();
  }

  Future<void> scanStorageRoots() async {
    setState(() => scanning = true);
    final found = <String>[];
    try {
      final storage = Directory('/storage');
      if (await storage.exists()) {
        await for (final entity in storage.list(followLinks: false)) {
          if (entity is Directory) {
            final path = entity.path;
            final name = p.basename(path).toLowerCase();
            if (name == 'emulated' || name == 'self') continue;
            found.add(path);
          }
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      detectedPaths = found.toSet().toList()..sort();
      scanning = false;
    });
  }

  Future<void> savePath() async {
    final value = pathController.text.trim();
    if (value.isEmpty) {
      showSnack(context, 'Path masih kosong.');
      return;
    }
    await widget.store.setSdCardPath(value);
    if (!mounted) return;
    showSnack(context, 'Path SD Card disimpan.');
  }

  Future<void> clearPath() async {
    pathController.clear();
    await widget.store.setSdCardPath(null);
    if (!mounted) return;
    showSnack(context, 'Path SD Card dikosongkan.');
  }

  Future<void> importSdFolder() async {
    final path = pathController.text.trim().isNotEmpty ? pathController.text.trim() : (widget.store.sdCardPath ?? '');
    if (path.isEmpty) {
      showSnack(context, 'Path SD Card masih kosong.');
      return;
    }
    final dir = Directory(path);
    if (!await dir.exists()) {
      showSnack(context, 'Folder belum ketemu. Cek path SD Card-nya.');
      return;
    }
    setState(() {
      importing = true;
      importInfo = null;
    });
    await widget.store.setSdCardPath(path);
    final found = await findMediaFiles(path);
    final added = await widget.store.importFromFolder(path);
    if (!mounted) return;
    setState(() {
      importing = false;
      importInfo = 'Ketemu ${found.length} file media, $added item baru diimport.';
    });
    showSnack(context, added == 0 ? 'Tidak ada media baru di folder itu.' : '$added media berhasil diimport.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
            children: [
              Row(
                children: [
                  NeonIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Expanded(child: GradientText('SD Card Path', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: 16),
              GlassPanel(
                padding: const EdgeInsets.all(16),
                borderColor: kPurple.withOpacity(0.35),
                child: const Text(
                  'V9.3: final reference polish, hero lebih compact, quick access lebih tipis, waveform lebih penuh, dan DCM Waifu tetap aktif.',
                  style: TextStyle(color: kTextSoft, height: 1.35),
                ),
              ),
              const SizedBox(height: 14),
              GlassPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Path tersimpan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pathController,
                      decoration: InputDecoration(
                        hintText: kFixedSdImportPath,
                        prefixIcon: const Icon(Icons.sd_storage_rounded),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: savePath,
                            style: FilledButton.styleFrom(backgroundColor: kPink, foregroundColor: Colors.white),
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Simpan Path'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: clearPath,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: importing ? null : importSdFolder,
                        style: FilledButton.styleFrom(backgroundColor: kPurple, foregroundColor: Colors.white),
                        icon: importing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.drive_folder_upload_rounded),
                        label: Text(importing ? 'Import dari folder...' : 'Scan & Import Media dari Folder'),
                      ),
                    ),
                    if (importInfo != null) ...[
                      const SizedBox(height: 10),
                      Text(importInfo!, style: const TextStyle(color: kTextSoft)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Deteksi folder /storage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                        IconButton(onPressed: scanning ? null : scanStorageRoots, icon: const Icon(Icons.refresh_rounded)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (scanning)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Scan storage...')]),
                      )
                    else if (detectedPaths.isEmpty)
                      const Text('Belum kebaca otomatis. Isi manual path SD Card lu di atas.', style: TextStyle(color: kTextSoft))
                    else
                      for (final path in detectedPaths)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: GestureDetector(
                            onTap: () => setState(() => pathController.text = p.join(path, 'WaifuVault')),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.folder_rounded, color: kBlue),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(path, style: const TextStyle(color: kTextSoft))),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivatePinScreen extends StatefulWidget {
  const PrivatePinScreen({super.key});

  @override
  State<PrivatePinScreen> createState() => _PrivatePinScreenState();
}

class _PrivatePinScreenState extends State<PrivatePinScreen> {
  String pin = '';

  void press(String value) {
    if (pin.length >= 4) return;
    setState(() => pin += value);
    if (pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        if (pin == '1234') {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN salah. Demo PIN: 1234')));
          setState(() => pin = '');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: NeonIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context, false)),
                ),
              ),
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [kPurple, kBlue]),
                  boxShadow: const [BoxShadow(color: Color(0x559D5CFF), blurRadius: 42)],
                ),
                child: const Icon(Icons.lock_rounded, size: 60),
              ),
              const SizedBox(height: 26),
              GradientText('Mode Privat', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Masukkan PIN Anda', style: TextStyle(color: kTextSoft, fontSize: 18)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final active = i < pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? kPink : Colors.white10,
                      boxShadow: active ? const [BoxShadow(color: Color(0x88FF4FB8), blurRadius: 18)] : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 310,
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  childAspectRatio: 1.6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    for (final n in ['1', '2', '3', '4', '5', '6', '7', '8', '9']) PinButton(label: n, onTap: () => press(n)),
                    const SizedBox.shrink(),
                    PinButton(label: '0', onTap: () => press('0')),
                    PinButton(icon: Icons.backspace_rounded, onTap: () => setState(() => pin = pin.isEmpty ? '' : pin.substring(0, pin.length - 1))),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('Demo PIN: 1234', style: TextStyle(color: kTextSoft)),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}


class SelectionToolbar extends StatelessWidget {
  final int count;
  final int total;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  const SelectionToolbar({
    super.key,
    required this.count,
    required this.total,
    required this.onCancel,
    required this.onSelectAll,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: kPink.withOpacity(0.38),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [kPink, kPurple]),
              boxShadow: const [BoxShadow(color: Color(0x55FF4FB8), blurRadius: 16)],
            ),
            child: const Icon(Icons.check_rounded, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('$count dipilih', style: const TextStyle(fontWeight: FontWeight.w900))),
          TextButton(onPressed: onSelectAll, child: Text(count == total ? 'Semua' : 'Pilih semua')),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent)),
          IconButton(onPressed: onCancel, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }
}


class AnimatedMediaEntry extends StatelessWidget {
  final int index;
  final Widget child;
  const AnimatedMediaEntry({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: Transform.scale(
              scale: 0.97 + (0.03 * value),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class MediaTile extends StatelessWidget {
  final VaultMedia item;
  final VaultStore store;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectedTap;
  final VoidCallback? onLongPress;
  const MediaTile({
    super.key,
    required this.item,
    required this.store,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedTap,
    this.onLongPress,
  });

  void open(BuildContext context) {
    if (item.isImage) {
      Navigator.push(context, smoothPageRoute(ImagePreviewScreen(item: item, store: store)));
    } else {
      Navigator.push(context, smoothPageRoute(VideoPreviewScreen(item: item, store: store)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(item.path);
    final thumbFile = item.thumbnailPath == null ? null : File(item.thumbnailPath!);
    final hasThumb = thumbFile != null && thumbFile.existsSync();
    final accent = Color(item.accentColor ?? (item.isVideo ? kBlue.value : kPink.value));
    return GestureDetector(
      onTap: selectionMode ? onSelectedTap : () => open(context),
      onLongPress: onLongPress,
      child: Material(
        color: Colors.transparent,
        child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.0),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.isImage && file.existsSync())
                Image.file(file, fit: BoxFit.cover)
              else if (item.isVideo && hasThumb)
                Image.file(thumbFile!, fit: BoxFit.cover)
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent.withOpacity(0.9), kPanel, kBg],
                    ),
                  ),
                  child: Icon(item.isVideo ? Icons.play_circle_fill_rounded : Icons.broken_image_rounded, size: 42, color: Colors.white70),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                    ),
                  ),
                ),
              ),
              if (selectionMode)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: selected ? kPink : Colors.black.withOpacity(0.42),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(selected ? Icons.check_rounded : Icons.circle_outlined, color: Colors.white, size: 18),
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => store.toggleFavorite(item.id),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.36), borderRadius: BorderRadius.circular(99)),
                    child: Icon(item.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: item.favorite ? kPink : Colors.white, size: 18),
                  ),
                ),
              ),
              Positioned(
                left: 7,
                right: 7,
                bottom: item.isVideo ? 38 : 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayMediaTitle(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: accent.withOpacity(0.55), borderRadius: BorderRadius.circular(99)),
                      child: Text(
                        item.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.isVideo)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(99)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_rounded, size: 14),
                        SizedBox(width: 4),
                        Text('Video', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.none)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
          ),
        ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final VaultCategory category;
  final int count;
  final VoidCallback onTap;
  const CategoryCard({super.key, required this.category, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 78,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: category.colors),
                boxShadow: [BoxShadow(color: category.colors.first.withOpacity(0.25), blurRadius: 18)],
              ),
              child: Icon(category.icon, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text('$count item', style: const TextStyle(color: kTextSoft)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kTextSoft),
          ],
        ),
      ),
    );
  }
}

class PreviewActionPanel extends StatelessWidget {
  final Color accent;
  final String title;
  final String subtitle;
  final String indexText;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  const PreviewActionPanel({
    super.key,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.indexText,
    required this.favorite,
    required this.onFavorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      padding: const EdgeInsets.all(16),
      color: accent.withOpacity(0.18),
      borderColor: accent.withOpacity(0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
              Text(indexText, style: const TextStyle(color: kTextSoft, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: kTextSoft)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ActionPill(icon: Icons.info_outline_rounded, label: 'Info', onTap: () => showSnack(context, 'Info file ada di menu titik tiga atas.')),
              ActionPill(icon: Icons.folder_copy_rounded, label: 'Path', onTap: () => showSnack(context, 'Path file bisa dicek dari menu titik tiga.')),
              ActionPill(icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: 'Favorit', color: favorite ? kPink : null, onTap: onFavorite),
              ActionPill(icon: Icons.wallpaper_rounded, label: 'Preview', onTap: () => showSnack(context, 'Preview layar penuh sudah aktif di halaman ini.')), 
              ActionPill(icon: Icons.delete_outline_rounded, label: 'Hapus', color: Colors.redAccent, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class ImportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String button;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  const ImportCard({super.key, required this.title, required this.subtitle, required this.button, required this.icon, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderColor: colors.first.withOpacity(0.45),
      child: Row(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: colors),
            ),
            child: Icon(icon, size: 42),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: kTextSoft)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(backgroundColor: colors.first),
                    child: Text(button),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewMini extends StatelessWidget {
  final String path;
  final String type;
  const PreviewMini({super.key, required this.path, required this.type});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return Container(
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: type == 'image' && file.existsSync()
          ? Image.file(file, fit: BoxFit.cover, width: double.infinity)
          : Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [kBlue, kPurple])),
              child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 54)),
            ),
    );
  }
}

class AdaptiveMediaBackground extends StatelessWidget {
  final Color accent;
  final String? imagePath;
  const AdaptiveMediaBackground({super.key, required this.accent, this.imagePath});

  @override
  Widget build(BuildContext context) {
    final imageFile = imagePath == null ? null : File(imagePath!);
    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.2,
              colors: [accent.withOpacity(0.65), kBg, Colors.black],
            ),
          ),
        ),
        if (imageFile != null && imageFile.existsSync())
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 650),
              child: Opacity(
                key: ValueKey(imagePath),
                opacity: 0.28,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                  child: Image.file(imageFile, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.black.withOpacity(0.2), accent.withOpacity(0.2), kBg.withOpacity(0.95)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NeonBackground extends StatelessWidget {
  final Widget child;
  const NeonBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF07112A), Color(0xFF060B1B), Color(0xFF030712)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        const Positioned.fill(child: CustomPaint(painter: CosmicStarField())),
        Positioned(top: -90, left: -120, child: NeonOrb(color: kPurple.withOpacity(0.28), size: 300)),
        Positioned(top: 180, right: -120, child: NeonOrb(color: kBlue.withOpacity(0.20), size: 310)),
        Positioned(bottom: -150, left: 20, child: NeonOrb(color: kPink.withOpacity(0.23), size: 300)),
        Positioned(
          top: 68,
          left: -40,
          right: -40,
          child: IgnorePointer(
            child: Container(height: 120, decoration: BoxDecoration(border: Border(top: BorderSide(color: kPink.withOpacity(0.08))))),
          ),
        ),
        child,
      ],
    );
  }
}

class CosmicStarField extends CustomPainter {
  const CosmicStarField();

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..color = Colors.white.withOpacity(0.55);
    final bluePaint = Paint()..color = kBlue.withOpacity(0.35);
    final pinkPaint = Paint()..color = kPink.withOpacity(0.34);
    final stars = <Offset>[
      Offset(size.width * .10, size.height * .08), Offset(size.width * .23, size.height * .15), Offset(size.width * .42, size.height * .10), Offset(size.width * .71, size.height * .13),
      Offset(size.width * .87, size.height * .07), Offset(size.width * .18, size.height * .35), Offset(size.width * .76, size.height * .31), Offset(size.width * .91, size.height * .48),
      Offset(size.width * .34, size.height * .64), Offset(size.width * .62, size.height * .72), Offset(size.width * .15, size.height * .83), Offset(size.width * .82, size.height * .88),
    ];
    for (final point in stars) { canvas.drawCircle(point, 1.0, starPaint); }
    final orbit = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = kPink.withOpacity(0.12);
    canvas.drawOval(Rect.fromLTWH(-80, size.height * .05, size.width + 180, 170), orbit);
    orbit.color = kBlue.withOpacity(0.10);
    canvas.drawOval(Rect.fromLTWH(size.width * .35, size.height * .62, size.width * .75, 140), orbit);
    canvas.drawCircle(Offset(size.width * .08, size.height * .22), 1.7, pinkPaint);
    canvas.drawCircle(Offset(size.width * .90, size.height * .24), 1.7, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NeonOrb extends StatelessWidget {
  final Color color;
  final double size;
  const NeonOrb({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  const GlassPanel({super.key, required this.child, this.padding, this.margin, this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? const Color(0xC0111526),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: borderColor ?? Colors.white12),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GradientText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(colors: [Colors.white, Color(0xFFFFD7E5), kPink, kBlue]).createShader(bounds),
      child: Text(text, style: style.copyWith(decoration: TextDecoration.none)),
    );
  }
}

class VaultLogo extends StatelessWidget {
  final double size;
  const VaultLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const LinearGradient(colors: [Color(0xFF2C1648), Color(0xFF102C55)]),
        border: Border.all(color: kPurple.withOpacity(0.9), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x779D5CFF), blurRadius: 34), BoxShadow(color: Color(0x5500E5FF), blurRadius: 46)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.lock_rounded, size: size * 0.48, color: Colors.white.withOpacity(0.13)),
          Text('W', style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w900, color: Colors.white)),
          Positioned(bottom: size * 0.17, child: Icon(Icons.favorite_rounded, size: size * 0.16, color: kPink)),
        ],
      ),
    );
  }
}

class BottomNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const BottomNavButton({super.key, required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: active ? const LinearGradient(colors: [kPink, kPurple]) : null,
                color: active ? null : Colors.transparent,
                boxShadow: active ? const [BoxShadow(color: Color(0x66FF4FB8), blurRadius: 18)] : null,
              ),
              child: Icon(icon, color: active ? Colors.white : kTextSoft, size: 24),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11.5, color: active ? Colors.white : kTextSoft, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class VaultChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const VaultChip({super.key, required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active ? const LinearGradient(colors: [kPink, Color(0xFFFFA3BC)]) : null,
            color: active ? null : Colors.white.withOpacity(0.055),
            border: Border.all(color: active ? Colors.white.withOpacity(0.26) : Colors.white.withOpacity(0.10)),
            boxShadow: active ? [BoxShadow(color: kPink.withOpacity(0.28), blurRadius: 18, offset: const Offset(0, 8))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : kTextSoft),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.white : kTextSoft, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchBox({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: kTextSoft.withOpacity(0.76)),
        prefixIcon: const Icon(Icons.search_rounded, color: kTextSoft),
        suffixIcon: const Icon(Icons.tune_rounded, color: kTextSoft),
        filled: true,
        fillColor: Colors.white.withOpacity(0.055),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: kPink.withOpacity(0.45))),
      ),
    );
  }
}

class NeonIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const NeonIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.055),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [BoxShadow(color: kPink.withOpacity(0.13), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.88)),
      ),
    );
  }
}

class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback? onTap;
  const SettingsTile({super.key, required this.icon, required this.title, required this.subtitle, required this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: kPurple, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: kTextSoft)),
                  ],
                ),
              ),
              Icon(trailing, color: kTextSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.title, required this.subtitle, required this.icon, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [kPurple, kPink]),
                boxShadow: const [BoxShadow(color: Color(0x66FF4FB8), blurRadius: 34)],
              ),
              child: Icon(icon, size: 52),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
                decoration: TextDecoration.none,
              ),
            ),
            if (subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kTextSoft,
                  fontSize: 14,
                  height: 1.35,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add_rounded), label: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class PinButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  const PinButton({super.key, this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: kPurple.withOpacity(0.55)),
          boxShadow: const [BoxShadow(color: Color(0x229D5CFF), blurRadius: 18)],
        ),
        child: Center(
          child: icon != null ? Icon(icon, size: 28) : Text(label!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}


void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void showPreviewModeSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    backgroundColor: kPanel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Preview Mode', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const Text('Tombol ini sekarang sudah aktif. Mode cast/layar eksternal asli belum dipaksa, biar video player tetap stabil di HP.', style: TextStyle(color: kTextSoft)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: kPink, foregroundColor: Colors.white),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Oke'),
          ),
        ],
      ),
    ),
  );
}

void showMediaOptionsSheet(BuildContext context, VaultStore store, VaultMedia item, {Future<void> Function()? onRefreshVideoColors}) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    backgroundColor: kPanel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.isVideo ? 'Menu Video' : 'Menu Foto', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(item.title, style: const TextStyle(color: kTextSoft)),
          const SizedBox(height: 14),
          ListTile(
            leading: Icon(item.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: kPink),
            title: Text(item.favorite ? 'Hapus dari favorit' : 'Tambah ke favorit'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await store.toggleFavorite(item.id);
            },
          ),
          if (item.isVideo)
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded, color: kBlue),
              title: const Text('Refresh adaptive color'),
              subtitle: const Text('Generate ulang warna video', style: TextStyle(color: kTextSoft)),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (onRefreshVideoColors != null) await onRefreshVideoColors();
                if (context.mounted) showSnack(context, 'Adaptive color video dicek ulang.');
              },
            ),
          ListTile(
            leading: const Icon(Icons.edit_rounded, color: kPurple),
            title: const Text('Edit judul / kategori'),
            subtitle: const Text('Rename dan pindah kategori', style: TextStyle(color: kTextSoft)),
            onTap: () {
              Navigator.pop(sheetContext);
              showEditMediaSheet(context, store, item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_copy_rounded, color: kBlue),
            title: const Text('Lihat path file'),
            onTap: () {
              Navigator.pop(sheetContext);
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Path File'),
                  content: SelectableText(item.path),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            title: const Text('Hapus item'),
            onTap: () {
              Navigator.pop(sheetContext);
              confirmDelete(context, store, item);
            },
          ),
        ],
      ),
    ),
  );
}


Future<void> showEditMediaSheet(BuildContext context, VaultStore store, VaultMedia item) async {
  final titleController = TextEditingController(text: item.title);
  var selectedCategory = item.category;
  final categories = <String>{...defaultCategories.map((e) => e.name), item.category}.toList();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kPanel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Media', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul',
                    prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categories.contains(selectedCategory) ? selectedCategory : categories.first,
                  dropdownColor: kPanel2,
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: const Icon(Icons.category_rounded),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                  items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setSheetState(() => selectedCategory = v ?? selectedCategory),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await store.updateDetails(item.id, title: titleController.text, category: selectedCategory);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (context.mounted) showSnack(context, 'Info media disimpan.');
                    },
                    style: FilledButton.styleFrom(backgroundColor: kPink, foregroundColor: Colors.white),
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  titleController.dispose();
}

Future<bool?> confirmBulkDelete(BuildContext context, int count) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Hapus $count item?'),
      content: const Text('Semua item terpilih akan dihapus dari WaifuVault. Salinan file di folder aplikasi juga ikut dihapus.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
      ],
    ),
  );
}

Future<void> confirmDelete(BuildContext context, VaultStore store, VaultMedia item) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hapus dari WaifuVault?'),
      content: const Text('Item akan dihapus dari WaifuVault. Salinan file di folder aplikasi juga ikut dihapus.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
      ],
    ),
  );
  if (ok == true) {
    await store.delete(item.id);
    if (context.mounted) Navigator.pop(context);
  }
}

String formatDate(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}


class ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const ActionPill({super.key, required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 24),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class SmallInfoButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const SmallInfoButton({super.key, required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: kBlue),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kTextSoft)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
