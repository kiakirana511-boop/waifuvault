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

void main() {
  runApp(const WaifuVaultApp());
}

const Color kBg = Color(0xFF080A14);
const Color kPanel = Color(0xFF111525);
const Color kPanel2 = Color(0xFF171B2E);
const Color kPink = Color(0xFFFF4FB8);
const Color kPurple = Color(0xFF9D5CFF);
const Color kBlue = Color(0xFF00E5FF);
const Color kTextSoft = Color(0xFFB8B7D3);

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
    );
  }
}

class VaultStore extends ChangeNotifier {
  static const String _itemsKey = 'waifuvault_items_v1';
  static const String _privateKey = 'waifuvault_private_mode_v1';

  final List<VaultMedia> _items = [];
  bool privateMode = false;
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
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_itemsKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
    await prefs.setBool(_privateKey, privateMode);
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
      if (!path.contains('waifuvault_media') && !path.contains('waifuvault_thumbs')) return;
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> setPrivateMode(bool value) async {
    privateMode = value;
    notifyListeners();
    await _save();
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
      title: 'WaifuVault',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
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
                'WaifuVault',
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text('Simpan. Koleksi. Nikmati.', style: TextStyle(color: kTextSoft)),
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

  void openAddMedia() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMediaScreen(store: widget.store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(store: widget.store),
      CategoryScreen(store: widget.store),
      FavoritesScreen(store: widget.store),
      ProfileScreen(store: widget.store),
    ];

    return Scaffold(
      extendBody: true,
      body: pages[index],
      floatingActionButton: FloatingActionButton.large(
        heroTag: 'add-media',
        onPressed: openAddMedia,
        backgroundColor: kPink,
        foregroundColor: Colors.white,
        elevation: 16,
        child: const Icon(Icons.add_rounded, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xD00D1020),
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Color(0x55FF4FB8), blurRadius: 24, offset: Offset(0, 12)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  BottomNavButton(
                    label: 'Beranda',
                    icon: Icons.home_rounded,
                    active: index == 0,
                    onTap: () => setState(() => index = 0),
                  ),
                  BottomNavButton(
                    label: 'Kategori',
                    icon: Icons.grid_view_rounded,
                    active: index == 1,
                    onTap: () => setState(() => index = 1),
                  ),
                  const SizedBox(width: 64),
                  BottomNavButton(
                    label: 'Koleksi',
                    icon: Icons.favorite_border_rounded,
                    active: index == 2,
                    onTap: () => setState(() => index = 2),
                  ),
                  BottomNavButton(
                    label: 'Profil',
                    icon: Icons.person_rounded,
                    active: index == 3,
                    onTap: () => setState(() => index = 3),
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
  String filter = 'all';
  String search = '';

  List<VaultMedia> get filteredItems {
    var list = widget.store.items;
    if (filter == 'image') list = list.where((e) => e.isImage).toList();
    if (filter == 'video') list = list.where((e) => e.isVideo).toList();
    if (filter == 'favorite') list = list.where((e) => e.favorite).toList();
    if (search.trim().isNotEmpty) {
      final q = search.toLowerCase().trim();
      list = list.where((e) => e.title.toLowerCase().contains(q) || e.category.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GradientText(
                                'WaifuVault',
                                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const ProBadge(),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SearchBox(
                          hint: 'Cari koleksi favoritmu...',
                          onChanged: (v) => setState(() => search = v),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              VaultChip(label: 'Semua', icon: Icons.grid_view_rounded, active: filter == 'all', onTap: () => setState(() => filter = 'all')),
                              VaultChip(label: 'Foto', icon: Icons.image_rounded, active: filter == 'image', onTap: () => setState(() => filter = 'image')),
                              VaultChip(label: 'Video', icon: Icons.play_circle_rounded, active: filter == 'video', onTap: () => setState(() => filter = 'video')),
                              VaultChip(label: 'Favorit', icon: Icons.favorite_rounded, active: filter == 'favorite', onTap: () => setState(() => filter = 'favorite')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
                if (filteredItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: 'Belum ada media',
                      subtitle: 'Tekan tombol + untuk menambahkan foto atau video ke WaifuVault.',
                      icon: Icons.add_photo_alternate_rounded,
                      actionLabel: 'Tambah Media',
                      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddMediaScreen(store: widget.store))),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => MediaTile(item: filteredItems[i], store: widget.store),
                        childCount: filteredItems.length,
                      ),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CategoryDetailScreen(store: store, category: cat.name)),
                      );
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
                        Expanded(child: GradientText(category, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900))),
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
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate((context, i) => MediaTile(item: items[i], store: store), childCount: items.length),
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
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate((context, i) => MediaTile(item: items[i], store: store), childCount: items.length),
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

  Future<void> togglePrivate(BuildContext context, bool value) async {
    if (!value) {
      await store.setPrivateMode(false);
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PrivatePinScreen()),
    );
    if (ok == true) {
      await store.setPrivateMode(true);
    }
  }

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
                GlassPanel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [kPink, kBlue]),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 38),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GradientText('WaifuLover', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                const Text('Premium Member', style: TextStyle(color: kPink, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const ProBadge(),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Penyimpanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (store.items.length / 200).clamp(0.02, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.white10,
                          color: kPink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${store.items.length} item tersimpan • ${store.imageCount} foto • ${store.videoCount} video', style: const TextStyle(color: kTextSoft)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SettingsTile(icon: Icons.palette_rounded, title: 'Tema', subtitle: 'Adaptive Dynamic', trailing: Icons.chevron_right_rounded),
                SettingsTile(icon: Icons.language_rounded, title: 'Bahasa', subtitle: 'Indonesia', trailing: Icons.chevron_right_rounded),
                SettingsTile(icon: Icons.storage_rounded, title: 'Penyimpanan', subtitle: 'Kelola file & cache', trailing: Icons.chevron_right_rounded),
                SettingsTile(icon: Icons.cloud_upload_rounded, title: 'Backup & Ekspor', subtitle: 'Cadangkan koleksi', trailing: Icons.chevron_right_rounded),
                GlassPanel(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: store.privateMode,
                    onChanged: (v) => togglePrivate(context, v),
                    activeColor: kPink,
                    title: const Text('Mode Privat', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Kunci aplikasi dengan PIN demo 1234', style: TextStyle(color: kTextSoft)),
                    secondary: const Icon(Icons.lock_rounded, color: kBlue),
                  ),
                ),
                SettingsTile(icon: Icons.info_rounded, title: 'Tentang WaifuVault', subtitle: 'v1.2.0', trailing: Icons.chevron_right_rounded),
              ],
            );
          },
        ),
      ),
    );
  }
}


Future<Directory> getVaultDirectory(String folderName) async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(base.path, folderName));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
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
      if (titleController.text.trim().isEmpty) titleController.text = 'Video JJ Baru';
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
                      NeonIconButton(icon: Icons.more_vert_rounded, onTap: () {}),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: file.existsSync()
                          ? InteractiveViewer(child: Image.file(file, fit: BoxFit.contain, width: double.infinity))
                          : const Center(child: Text('File tidak ditemukan')),
                    ),
                  ),
                ),
                PreviewActionPanel(
                  accent: accent,
                  title: item.title,
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
                      NeonIconButton(icon: Icons.cast_rounded, onTap: () {}),
                      const SizedBox(width: 8),
                      NeonIconButton(icon: Icons.more_vert_rounded, onTap: () {}),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(widget.item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
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

class MediaTile extends StatelessWidget {
  final VaultMedia item;
  final VaultStore store;
  const MediaTile({super.key, required this.item, required this.store});

  void open(BuildContext context) {
    if (item.isImage) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ImagePreviewScreen(item: item, store: store)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPreviewScreen(item: item, store: store)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(item.path);
    final thumbFile = item.thumbnailPath == null ? null : File(item.thumbnailPath!);
    final hasThumb = thumbFile != null && thumbFile.existsSync();
    final accent = Color(item.accentColor ?? (item.isVideo ? kBlue.value : kPink.value));
    return GestureDetector(
      onTap: () => open(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.55), width: 1.1),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.18), blurRadius: 14)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
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
                        Text('Video', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
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
              ActionPill(icon: Icons.share_rounded, label: 'Bagikan', onTap: () {}),
              ActionPill(icon: Icons.download_rounded, label: 'Unduh', onTap: () {}),
              ActionPill(icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: 'Favorit', color: favorite ? kPink : null, onTap: onFavorite),
              ActionPill(icon: Icons.wallpaper_rounded, label: 'Wallpaper', onTap: () {}),
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
        Container(color: kBg),
        Positioned(
          top: -90,
          left: -80,
          child: NeonOrb(color: kPurple.withOpacity(0.42), size: 260),
        ),
        Positioned(
          top: 120,
          right: -100,
          child: NeonOrb(color: kBlue.withOpacity(0.22), size: 280),
        ),
        Positioned(
          bottom: -130,
          left: 40,
          child: NeonOrb(color: kPink.withOpacity(0.28), size: 260),
        ),
        child,
      ],
    );
  }
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
      shaderCallback: (bounds) => const LinearGradient(colors: [Colors.white, kPurple, kPink, kBlue]).createShader(bounds),
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
            Icon(icon, color: active ? kPink : kTextSoft, size: 26),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: active ? kPink : kTextSoft, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
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
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active ? const LinearGradient(colors: [kPink, kPurple]) : null,
            color: active ? null : Colors.white.withOpacity(0.06),
            border: Border.all(color: active ? Colors.white24 : Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
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
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: const Icon(Icons.tune_rounded),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.6)),
        color: Colors.orange.withOpacity(0.09),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, color: Colors.orangeAccent, size: 17),
          SizedBox(width: 5),
          Text('Pro', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
        ],
      ),
    );
  }
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
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: c, size: 24),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: c.withOpacity(0.9), fontSize: 11)),
        ],
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
        children: [
          Icon(icon, size: 20, color: kBlue),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: kTextSoft)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  const SettingsTile({super.key, required this.icon, required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 10),
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
            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: kTextSoft)),
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
