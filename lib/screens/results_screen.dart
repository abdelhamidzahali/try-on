import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:envisionfit/models/tryon_session.dart';
import 'package:envisionfit/services/tryon_service.dart';
import 'package:envisionfit/services/download_saver.dart';
// Removed prompt preview imports to streamline direct generation flow
import 'package:envisionfit/navigation/app_navigator.dart';
import 'package:envisionfit/services/tryon_favorites_service.dart';
import 'package:envisionfit/services/save_result.dart';
import 'package:envisionfit/widgets/animated_preparing.dart';
import 'package:envisionfit/widgets/title_text.dart';
// import 'package:envisionfit/services/retail_search_service.dart';

class ResultsScreen extends StatefulWidget {
  final String sessionId;
  final DateTime? startedAt; // When user tapped "View Try-On"

  const ResultsScreen({
    super.key,
    required this.sessionId,
    this.startedAt,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  TryOnSession? _session;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _isFavorite = false;
  bool _favBusy = false;
  // bool _isFindingSimilar = false; // Removed with SHEIN button
  String? _elapsedSecondsText; // Shown next to "Try-On Complete!"

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);
    
    try {
      final session = await TryOnService.getSessionById(widget.sessionId);
      setState(() {
        _session = session;
        _isLoading = false;
      });
      // Load favorite state
      if (session != null) {
        try {
          final fav = await TryOnFavoritesService.isFavorite(session.id);
          if (mounted) setState(() => _isFavorite = fav);
        } catch (e) {
          debugPrint('Favorite check failed: $e');
        }
      }
      // Favorites feature removed per request
      
      // If pending, immediately start processing to generate the AI image
      if (session != null && session.status == TryOnStatus.pending) {
        await _processSession();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading session: $e')),
        );
      }
    }
  }

  Future<void> _processSession() async {
    setState(() => _isProcessing = true);
    
    try {
      final updatedSession = await TryOnService.processSession(widget.sessionId);
      setState(() {
        _session = updatedSession;
        _isProcessing = false;
      });

      // Diagnostics: log paths to verify which image is displayed
      if (updatedSession != null) {
        try {
          final up = updatedSession.userPhotoPath;
          final cp = updatedSession.clothingPhotoPath;
          final rp = updatedSession.result?.imagePath ?? '';
          debugPrint('[Results] userPhotoPath: ${up.length > 120 ? up.substring(0, 120) + '…' : up}');
          debugPrint('[Results] clothingPhotoPath: ${cp.length > 120 ? cp.substring(0, 120) + '…' : cp}');
          debugPrint('[Results] result.imagePath: ${rp.length > 120 ? rp.substring(0, 120) + '…' : rp}');
          debugPrint('[Results] result equals user photo? ${rp.isNotEmpty && rp == up}');
          debugPrint('[Results] result equals clothing photo? ${rp.isNotEmpty && rp == cp}');
        } catch (e) {
          debugPrint('[Results] path logging failed: $e');
        }
      }

      // If generation completed, show elapsed time since the user tapped the button
      if (mounted && updatedSession != null && updatedSession.status == TryOnStatus.completed) {
        if (widget.startedAt != null) {
          final elapsedMs = DateTime.now().difference(widget.startedAt!).inMilliseconds;
          final seconds = (elapsedMs / 1000.0);
          final secondsText = seconds.toStringAsFixed(seconds < 10 ? 2 : 1);
          debugPrint('Try-on generated successfully in ${secondsText}s');
          setState(() {
            _elapsedSecondsText = secondsText;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('try-on generated successfully in $secondsText seconds')),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing session: $e')),
        );
      }
    }
  }

  void _goHome() {
    // Switch bottom tabs to Home (Try-On) and pop back to Try-On,
    // returning a signal so the Try-On screen can clear the clothing photo.
    AppNavigator.goHome();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop({'tryAnother': true});
    } else {
      // Fallback: if nothing to pop (shouldn't happen in normal flow), do nothing
      // The Try-On screen won't receive a result in this edge case.
    }
  }

  void _retryTryOn() {
    if (_session != null) {
      _processSession();
    }
  }

  Future<void> _generateNewTryOn() async {
    if (_session == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final current = _session!;
      final newSession = await TryOnService.createSession(
        userId: current.userId,
        userPhoto: File(current.userPhotoPath),
        clothingId: current.clothingId,
        clothingPhoto: File(current.clothingPhotoPath),
        clothingCategory: current.clothingCategory,
        clothingName: current.clothingName,
        clothingGender: current.clothingGender,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            sessionId: newSession.id,
            startedAt: DateTime.now(),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating new try-on: $e')),
        );
      }
    }
  }

  // Removed prompt review and analysis-specific flow; we now directly process the session

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _session == null
                ? _buildErrorState()
                : Stack(
                    children: [
                      // Background typographic texture "Fit" to match TryOnScreen
                      Positioned(
                        top: -24,
                        right: -36,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Opacity(
                            opacity: Theme.of(context).brightness == Brightness.light ? 0.06 : 0.04,
                            child: Text(
                              'Fit',
                              style: textTheme.displayLarge?.copyWith(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                letterSpacing: -2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Foreground content
                      Column(
                        children: [
                          _buildModernHeader(context),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildResultSection(context),
                                  const SizedBox(height: 12),
                                  _buildSourceSection(context),
                                  if (_session!.status != TryOnStatus.completed) ...[
                                    const SizedBox(height: 16),
                                    _buildStatusSection(),
                                  ],
                                  const SizedBox(height: 24),
                                  _buildModernActions(context),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }

  // Modern header to mirror TryOnScreen
  Widget _buildModernHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Removed "Collection 01" label per request
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Magic', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Fit', style: textTheme.headlineMedium?.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400)),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_session != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _buildFavoriteIconChip(context),
                ),
              GestureDetector(
                onTap: _goHome,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.home, size: 16, color: colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteIconChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: IconButton(
        tooltip: _isFavorite ? 'Remove from favorites' : 'Save to favorites',
        onPressed: _favBusy ? null : _toggleFavorite,
        icon: _favBusy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : colorScheme.onSurface),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildResultSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasResult = _session!.status == TryOnStatus.completed && (_session!.result?.imagePath.isNotEmpty == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('01', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.35), fontStyle: FontStyle.italic)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('THE RESULT', style: textTheme.labelSmall?.copyWith(color: Colors.white, letterSpacing: 2.2, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surfaceContainerHighest,
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: AspectRatio(
              aspectRatio: 3/4,
              child: Stack(
                children: [
                  // Image or placeholder
                  Positioned.fill(
                    child: hasResult
                        ? _buildAdaptiveImage(_session!.result!.imagePath)
                        : Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: _buildStatusSection(),
                          ),
                  ),
                  // Gradient overlay bottom
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Top-right favorite quick toggle on image
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: IconButton(
                        onPressed: _favBusy ? null : _toggleFavorite,
                        icon: _favBusy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : colorScheme.onSurface),
                        tooltip: _isFavorite ? 'Remove from favorites' : 'Save to favorites',
                      ),
                    ),
                  ),
                  // Bottom info bar
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hasResult ? 'Try-On Complete' : _getStatusTitle(),
                                  style: textTheme.titleMedium?.copyWith(color: Colors.white, fontStyle: FontStyle.italic),
                                ),
                                if (hasResult && _elapsedSecondsText != null)
                                  Text(
                                    'in ${_elapsedSecondsText}s',
                                    style: textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.7), letterSpacing: 2),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Container(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Text('INGREDIENTS', style: textTheme.labelSmall?.copyWith(letterSpacing: 2.2, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Text('02', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.35), fontStyle: FontStyle.italic)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildSourceCard(context, title: 'YOUR PHOTO', imagePath: _session!.userPhotoPath)),
            const SizedBox(width: 12),
            Expanded(child: _buildSourceCard(context, title: 'CLOTHING', imagePath: _session!.clothingPhotoPath)),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceCard(BuildContext context, {required String title, required String imagePath}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isNetwork = imagePath.startsWith('http') || imagePath.startsWith('blob:') || imagePath.startsWith('data:');
    final imageWidget = isNetwork
        ? Image.network(imagePath, fit: BoxFit.cover)
        : Image.file(File(imagePath), fit: BoxFit.cover);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: imageWidget),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Text(title, style: textTheme.labelSmall?.copyWith(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildModernActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary CTA: Try again (regenerate)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: InkWell(
            onTap: (_session!.status == TryOnStatus.completed && !_isProcessing) ? _generateNewTryOn : null,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: (_session!.status == TryOnStatus.completed && !_isProcessing)
                    ? Colors.black
                    : colorScheme.outlineVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isProcessing ? 'Generating…' : 'Try again',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    alignment: Alignment.center,
                    child: _isProcessing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh, color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary: Try another outfit
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _goHome,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Try another outfit'),
          ),
        ),
        const SizedBox(height: 12),
        // Tertiary: Download
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _saveResultImage,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            label: Text(_isSaving ? 'Downloading…' : 'Download try-on photo'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Session Not Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The try-on session could not be loaded.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _goHome,
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(
          'Photos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildImageCard(
                title: 'Your Photo',
                imagePath: _session!.userPhotoPath,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildImageCard(
                title: 'Clothing',
                imagePath: _session!.clothingPhotoPath,
              ),
            ),
          ],
        ),
        if (_session!.status == TryOnStatus.completed && _session!.result?.imagePath.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildImageCard(
                  // Remove caption for generated try-on image per request
                  title: null,
                  imagePath: _session!.result!.imagePath,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImageCard({String? title, required String imagePath}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title.isNotEmpty) ...[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
            ],
            FutureBuilder<double?>(
              future: _fetchImageAspectRatio(imagePath),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: 280,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                }

                final ratio = snapshot.data;
                if (ratio == null || ratio.isNaN || ratio.isInfinite) {
                  // Fallback height when ratio cannot be determined
                  return SizedBox(
                    height: 280,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildAdaptiveImage(imagePath),
                    ),
                  );
                }

                return AspectRatio(
                  aspectRatio: ratio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
                      ),
                      child: _buildAdaptiveImage(imagePath),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveImage(String imagePath) {
    final isNetwork = imagePath.startsWith('http') || imagePath.startsWith('blob:') || imagePath.startsWith('data:');
    if (isNetwork) {
      return Image.network(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
          child: Center(
            child: Icon(
              Icons.image,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Image.file(
      File(imagePath),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
        child: Center(
          child: Icon(
            Icons.image,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<double?> _fetchImageAspectRatio(String imagePath) async {
    try {
      final isNetwork = imagePath.startsWith('http') || imagePath.startsWith('blob:') || imagePath.startsWith('data:');
      final ImageProvider provider = isNetwork
          ? NetworkImage(imagePath)
          : FileImage(File(imagePath));

      final completer = Completer<ImageInfo>();
      final stream = provider.resolve(const ImageConfiguration());
      late final ImageStreamListener listener;
      listener = ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(info);
      }, onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      });
      stream.addListener(listener);

      final info = await completer.future;
      stream.removeListener(listener);
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      if (width <= 0 || height <= 0) return null;
      return width / height;
    } catch (e, st) {
      debugPrint('Failed to get image aspect ratio for $imagePath: $e');
      debugPrint('$st');
      return null;
    }
  }

  Widget _buildStatusSection() {
    final showHeader = _session!.status != TryOnStatus.completed; // Hide "Try-On Complete!" header entirely
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Row(
                children: [
                  _buildStatusIcon(),
                  const SizedBox(width: 12),
                  Text(
                    _getStatusTitle(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _buildStatusContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (_session!.status) {
      case TryOnStatus.pending:
        icon = Icons.schedule;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case TryOnStatus.processing:
        icon = Icons.sync;
        color = Theme.of(context).colorScheme.primary;
        break;
      case TryOnStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case TryOnStatus.failed:
        icon = Icons.error;
        color = Theme.of(context).colorScheme.error;
        break;
    }

    return Icon(icon, color: color, size: 24);
  }

  String _getStatusTitle() {
    switch (_session!.status) {
      case TryOnStatus.pending:
        return 'Preparing...';
      case TryOnStatus.processing:
        return 'AI is Working Magic';
      case TryOnStatus.completed:
        return _elapsedSecondsText == null
            ? 'Try-On Complete!'
            : 'Try-On Complete! • ${_elapsedSecondsText}s';
      case TryOnStatus.failed:
        return 'Try-On Failed';
    }
  }

  Widget _buildStatusContent() {
    switch (_session!.status) {
      case TryOnStatus.pending:
        return const AnimatedPreparing(
          title: 'Preparing',
          subtitle: 'wait a second, magic is happening...',
        );
      case TryOnStatus.processing:
        return const AnimatedPreparing(
          title: 'AI is working magic',
          subtitle: 'Analyzing and composing your try-on — hang tight!',
        );
      case TryOnStatus.completed:
        // Remove AI Style Analysis widget and prompt text per request
        return const SizedBox.shrink();
      case TryOnStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _session!.errorMessage ?? 'An error occurred during the try-on process.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _retryTryOn,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        );
    }
  }

  Widget _buildActionsSection() {
    return Column(
      children: [
        if (_session != null &&
            _session!.status == TryOnStatus.completed &&
            (_session!.result?.imagePath.isNotEmpty == true)) ...[
          // Try again (regenerate with same clothing & user photo) — FIRST
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _generateNewTryOn,
              icon: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(_isProcessing ? 'Generating…' : 'Try again'),
            ),
          ),
          const SizedBox(height: 12),
          // Try another outfit — SECOND
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goHome,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Try another outfit'),
            ),
          ),
          const SizedBox(height: 12),
          // Download try-on photo — THIRD
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveResultImage,
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: Text(_isSaving ? 'Downloading…' : 'Download try-on photo'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _saveResultImage() async {
    final path = _session?.result?.imagePath;
    if (path == null || path.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final filename = 'tryon_${_session!.id}';
      final result = await DownloadSaver.saveImageFromPath(path, filename: filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Removed _findSimilarOnShein and related SHEIN search logic

  // Favorites feature removed
  Future<void> _toggleFavorite() async {
    final s = _session;
    if (s == null) return;
    setState(() => _favBusy = true);
    SaveResult result;
    try {
      if (_isFavorite) {
        result = await TryOnFavoritesService.removeFavoriteSession(s.id);
        if (mounted) setState(() => _isFavorite = false);
      } else {
        result = await TryOnFavoritesService.addFavoriteSession(s.id);
        if (mounted) setState(() => _isFavorite = true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } catch (e, st) {
      debugPrint('Favorite toggle failed: $e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorites: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _favBusy = false);
    }
  }
}