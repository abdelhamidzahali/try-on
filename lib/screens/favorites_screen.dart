import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:envisionfit/models/tryon_session.dart';
import 'package:envisionfit/screens/results_screen.dart';
import 'package:envisionfit/services/tryon_service.dart';
import 'package:envisionfit/services/tryon_favorites_service.dart';
import 'package:envisionfit/widgets/title_text.dart';

class FavoritesScreen extends StatefulWidget {
  final bool showAppBar;
  const FavoritesScreen({super.key, this.showAppBar = true});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoading = true;
  final List<TryOnSession> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final ids = await TryOnFavoritesService.getFavoriteSessionIds();
      debugPrint('[Favorites] ids loaded: ${ids.length}');

      // Fetch sessions in parallel
      final futures = ids.map((id) async {
        final s = await TryOnService.getSessionById(id);
        return MapEntry(id, s);
      }).toList();

      final results = await Future.wait(futures);
      final sessions = <TryOnSession>[];

      for (final entry in results) {
        final session = entry.value;
        if (session != null) {
          sessions.add(session);
        } else {
          // Clean up orphaned favorite ids silently
          unawaited(TryOnFavoritesService.removeFavoriteSession(entry.key));
        }
      }

      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _favorites
          ..clear()
          ..addAll(sessions);
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to load favorites: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading favorites: $e')),
      );
    }
  }

  void _openResult(TryOnSession session) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ResultsScreen(sessionId: session.id)))
        .then((_) => _loadFavorites());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const TitleText('Favorites'),
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _favorites.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final session = _favorites[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FavoriteItem(
                          session: session,
                          onTap: () => _openResult(session),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 96,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'No favorites yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Save outfits from your results to find them here and try again anytime.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteItem extends StatelessWidget {
  final TryOnSession session;
  final VoidCallback? onTap;

  const _FavoriteItem({required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildClothingPreview(context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.clothingName?.isNotEmpty == true
                          ? session.clothingName!
                          : 'Saved outfit',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(session.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClothingPreview(BuildContext context) {
    final path = session.clothingPhotoPath;
    final isNetwork = path.startsWith('http') || path.startsWith('blob:') || path.startsWith('data:');
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isNetwork
            ? Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context),
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Center(
        child: Icon(
          Icons.image,
          size: 24,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
