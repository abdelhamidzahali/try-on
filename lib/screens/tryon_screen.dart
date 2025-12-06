import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:envisionfit/services/tryon_service.dart';
import 'package:envisionfit/services/image_service.dart';
import 'package:envisionfit/screens/results_screen.dart';
import 'package:envisionfit/services/model_gallery_service.dart';
// import 'package:envisionfit/services/fullbody_gallery_service.dart';
import 'package:envisionfit/models/model_image.dart';
import 'package:envisionfit/screens/settings_screen.dart';
import 'package:envisionfit/services/clothing_description_service.dart';
import 'package:envisionfit/widgets/animated_preparing.dart';
import 'package:envisionfit/widgets/title_text.dart';
import 'package:envisionfit/services/onboarding_service.dart';

class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  File? _userPhoto;
  File? _clothingPhoto;
  bool _isProcessing = false;
  bool _isDescribing = false;
  ClothingDescription? _clothingDescription;
  ModelImage? _defaultModel;
  String? _gender; // 'gentleman' | 'lady'


  @override
  void initState() {
    super.initState();
    _loadDefaultModel();
    _loadGender();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadGender() async {
    try {
      final g = await OnboardingService.getGender();
      if (!mounted) return;
      setState(() => _gender = g);
    } catch (e) {
      debugPrint('[_TryOn] load gender error: $e');
    }
  }

  bool get _canStartTryOn => _userPhoto != null && _clothingPhoto != null && _clothingDescription != null && _clothingDescription!.genderMatches;

  Future<void> _startTryOn() async {
    if (!_canStartTryOn) return;

    setState(() => _isProcessing = true);

    dynamic navResult;
    try {
      // Capture start time as close as possible to the user's tap
      final startedAt = DateTime.now();
      // Clothing source: only uploaded photo is supported for now
      if (_clothingPhoto == null) {
        throw Exception('Please upload a clothing photo');
      }
      final clothingFile = _clothingPhoto!;
      final clothingId = 'custom_${DateTime.now().millisecondsSinceEpoch}';

      // Validate that we have a description with matching gender
      if (_clothingDescription == null || !_clothingDescription!.genderMatches) {
        throw Exception('Please describe the clothing first and ensure gender matches');
      }

      final session = await TryOnService.createSession(
        userId: 'default_user', // In a real app, this would be the current user ID
        userPhoto: _userPhoto!,
        clothingId: clothingId,
        clothingPhoto: clothingFile,
        clothingCategory: _clothingDescription!.category,
        clothingName: _clothingDescription!.name,
        clothingGender: _clothingDescription!.gender,
      );

      // Navigate to results screen and start processing
      if (mounted) {
        // Push ResultsScreen on top so RootTabs remains in the stack
        // This allows the Home/Try another outfit actions to pop back correctly
        navResult = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              sessionId: session.id,
              startedAt: startedAt,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting try-on: $e')),
        );
      }
      return;
    }

    // Ensure the button state resets when returning from ResultsScreen
    if (mounted) {
      setState(() {
        _isProcessing = false;
        // If user tapped "Try another outfit" on Results, clear the clothing placeholder
        try {
          if (navResult is Map && navResult['tryAnother'] == true) {
            _clothingPhoto = null;
            _clothingDescription = null; // also clear previous garment description
            _isDescribing = false; // ensure loading state is reset
            debugPrint('Cleared clothing photo and garment description after Try another outfit');
          }
        } catch (_) {
          // ignore malformed result
        }
      });
    }
  }

  Future<void> _describeClothing() async {
    if (_clothingPhoto == null) return;

    setState(() {
      _isDescribing = true;
      _clothingDescription = null;
    });

    try {
      final startedAt = DateTime.now();
      final description = await ClothingDescriptionService.describeClothing(_clothingPhoto!);
      // Ensure the loading indicator is visible for a minimum duration
      const minVisible = Duration(milliseconds: 900);
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minVisible) {
        await Future.delayed(minVisible - elapsed);
      }
      
      if (mounted) {
        // Check if the description is "Unknown" (photo not identified as clothing)
        if (description.name.trim().toLowerCase() == 'unknown') {
          setState(() => _isDescribing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("the photo doesn't seem a piece of clothing !"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        setState(() {
          _clothingDescription = description;
          _isDescribing = false;
        });

        // Show error if gender doesn't match
        if (!description.genderMatches && description.mismatchMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(description.mismatchMessage!),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error describing clothing: $e');
      if (mounted) {
        setState(() => _isDescribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('photo not identified as a clothing !'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Background typographic texture "Fit"
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
                _buildHeader(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMuseSection(context),
                        const SizedBox(height: 8),
                        _buildConnector(context),
                        const SizedBox(height: 8),
                        _buildFitSection(context),
                        if (_isDescribing) ...[
                          const SizedBox(height: 16),
                          const AnimatedPreparing(
                            title: 'Analysing...',
                            subtitle: '',
                            animateDots: false,
                          ),
                        ],
                        // Move the Generate Look button slightly upward
                        const SizedBox(height: 24),
                        _buildGenerateCta(context),
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

  Future<void> _loadDefaultModel() async {
    // Use selfie photo as the default source for try-on
    final def = await ModelGalleryService.getDefault();
    if (!mounted) return;
    setState(() {
      _defaultModel = def;
      if (def != null) {
        _userPhoto = File(def.path);
      }
    });
  }

  // New visual sections
  Widget _buildHeader(BuildContext context) {
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
          GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              await _loadDefaultModel();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.person, size: 16, color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuseSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelfie = _defaultModel != null;
    final String? path = hasSelfie ? _defaultModel!.path : null;
    final bool isUrlLike = (path ?? '').startsWith('http') || (path ?? '').startsWith('blob:') || (path ?? '').startsWith('data:');

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
              child: Text('THE MUSE', style: textTheme.labelSmall?.copyWith(color: Colors.white, letterSpacing: 2.2, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            // Increased to better showcase user's face in the selfie
            height: 240,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surfaceContainerHighest,
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Stack(
              children: [
                if (hasSelfie)
                  Positioned.fill(
                    child: kIsWeb && isUrlLike
                        ? Image.network(path!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                        : Image.file(File(path!), fit: BoxFit.cover, alignment: Alignment.topCenter),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Add a selfie in My profile',
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
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
                // Bottom bar: keep only the action button (text removed per request)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                          ),
                          onPressed: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                            await _loadDefaultModel();
                          },
                          child: const Text('Change', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Transform.scale(
        scale: 0.9,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.add, color: colorScheme.onSurface.withValues(alpha: 0.6), size: 18),
        ),
      ),
    );
  }

  Widget _buildFitSection(BuildContext context) {
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
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'THE FIT',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('02', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.35), fontStyle: FontStyle.italic)),
          ],
        ),
        const SizedBox(height: 8),

        // Upload card (shadow removed per request)
        Stack(
          children: [
            // Main card only
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 1),
              ),
              // Increased height for a larger garment selection area
              height: 168,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showGarmentSourceSheet(context),
                child: Stack(
                  children: [
                    // Selected garment preview
                    if (_clothingPhoto != null)
                      Positioned.fill(
                        child: _buildSelectedGarmentPreview(context),
                      ),
                    // Inner dashed/secondary border removed to avoid a double border effect
                    // Content
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(_genderIcon, size: 18, color: colorScheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          // Removed the 'Select Garment' text per request
                          const SizedBox(height: 2),
                          Text(
                            'Upload or Snap',
                            style: textTheme.labelSmall?.copyWith(letterSpacing: 2, color: colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _pickFromGallery(context),
                                child: const Text('Gallery'),
                              ),
                              Text(' | ', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.3))),
                              TextButton(
                                onPressed: () => _pickFromCamera(context),
                                child: const Text('Camera'),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (_clothingDescription != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      TitleText(
                        'Garment Description',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_clothingDescription!.name, style: Theme.of(context).textTheme.bodyMedium),
                  if (!_clothingDescription!.genderMatches) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _clothingDescription!.mismatchMessage ?? 'Gender mismatch',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedGarmentPreview(BuildContext context) {
    final p = _clothingPhoto!.path;
    final isUrlLike = p.startsWith('http') || p.startsWith('blob:') || p.startsWith('data:');
    if (kIsWeb && isUrlLike) {
      return Image.network(p, fit: BoxFit.cover);
    }
    return Image.file(_clothingPhoto!, fit: BoxFit.cover);
  }

  Widget _buildGenerateCta(BuildContext context) {
    final canTap = _canStartTryOn && !_isProcessing;
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: InkWell(
        onTap: canTap ? _startTryOn : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isProcessing ? 'Preparing Try-On...' : 'Generate Look',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: canTap ? 1.0 : 0.5),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: canTap ? 0.25 : 0.18)),
                ),
                alignment: Alignment.center,
                child: _isProcessing
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: canTap ? 1.0 : 0.5)))
                    : Icon(Icons.auto_awesome, color: Colors.white.withValues(alpha: canTap ? 1.0 : 0.5), size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Garment source helpers mirroring PhotoCaptureCard logic
  Future<void> _showGarmentSourceSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outline, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.camera_alt,
                      title: 'Camera',
                      subtitle: 'Take a new photo',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromCamera(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.photo_library,
                      title: 'Gallery',
                      subtitle: 'Choose existing',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromGallery(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    try {
      final image = await ImageService.pickImageFromCamera();
      if (image != null) {
        final cropped = await ImageService.cropImage(image);
        setState(() {
          _clothingPhoto = cropped ?? image;
          _clothingDescription = null;
        });
        await _describeClothing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final image = await ImageService.pickImageFromGallery();
      if (image != null) {
        final cropped = await ImageService.cropImage(image);
        setState(() {
          _clothingPhoto = cropped ?? image;
          _clothingDescription = null;
        });
        await _describeClothing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error selecting photo: $e')));
      }
    }
  }

  
  IconData get _genderIcon {
    final g = (_gender ?? '').toLowerCase().trim();
    final isLady = g == 'lady' || g == 'woman' || g == 'female';
    // Use available Material icons: dress-like for Lady, hanger for Gentleman
    return isLady ? Icons.dry_cleaning : Icons.checkroom;
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}