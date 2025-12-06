import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:envisionfit/navigation/root_tabs.dart';
import 'package:envisionfit/services/onboarding_service.dart';
import 'package:envisionfit/services/model_gallery_service.dart';
import 'package:envisionfit/services/image_service.dart';
import 'package:envisionfit/widgets/photo_capture_card.dart';
import 'package:envisionfit/models/model_image.dart';
import 'package:envisionfit/screens/onboarding_fullbody_screen.dart';
import 'package:envisionfit/services/photo_validation_service.dart';
import 'package:envisionfit/supabase/supabase_config.dart';
import 'package:envisionfit/services/image_service.dart' as imgsvc;
import 'package:envisionfit/services/local_photo_validator.dart';

class OnboardingPhotosScreen extends StatefulWidget {
  final String name;
  final String email;
  final String? gender; // 'gentleman' | 'lady'
  const OnboardingPhotosScreen({super.key, required this.name, required this.email, this.gender});

  @override
  State<OnboardingPhotosScreen> createState() => _OnboardingPhotosScreenState();
}

class _OnboardingPhotosScreenState extends State<OnboardingPhotosScreen> {
  bool _submitting = false;
  List<ModelImage> _images = [];
  File? _selectedFile; // For PhotoCaptureCard preview
  ModelImage? _selectedModelImage; // Reference to saved gallery item
  bool _validating = false; // shows "Analyzing photo..." while validating
  bool _photoAccepted = false; // hide examples and guidance once uploaded successfully

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final list = await ModelGalleryService.getAll();
    if (!mounted) return;
    ModelImage? current;
    try {
      current = list.firstWhere((m) => m.isDefault);
    } catch (_) {
      current = list.isNotEmpty ? list.first : null;
    }
    setState(() {
      _images = list;
      _selectedModelImage = current;
      if (current != null) {
        // Represent the saved image as a File with its path; on Web this is a data/blob/http URL
        _selectedFile = File(current!.path);
      } else {
        _selectedFile = null;
      }
    });
  }

  Future<void> _addFromGallery() async {
    final file = await ImageService.pickImageFromGallery();
    if (file == null) return;
    final saved = await ModelGalleryService.addFromFile(file);
    if (saved != null) {
      await _loadExisting();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model photo added')),
        );
      }
    }
  }

  Future<void> _addFromCamera() async {
    final file = await ImageService.pickImageFromCamera();
    if (file == null) return;
    final saved = await ModelGalleryService.addFromFile(file);
    if (saved != null) {
      await _loadExisting();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model photo captured')),
        );
      }
    }
  }

  Future<bool> _validateSelfieBlocking() async {
    try {
      setState(() => _validating = true);
      final current = _selectedModelImage;
      if (current == null) return false;
      final file = File(current.path);
      final bytes = await imgsvc.ImageService.fileToBytes(file);
      if (bytes == null) return false;
      final result = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.selfie);
      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't validate your photo. Please try another.")),
          );
        }
        return false;
      }
      if (!result.isOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.reason?.isNotEmpty == true ? result.reason! : 'Photo not accepted.')),
          );
        }
        return false;
      }
      // Safeguard: check if no person identified (gender == 'NA')
      final validated = result.gender.trim().toUpperCase();
      if (validated == 'NA') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Can't identify a person in the photo. Please upload a clear photo.")),
          );
        }
        return false;
      }
      // Safeguard: gender mismatch check
      final selectedGender = (widget.gender ?? '').toLowerCase();
      if (selectedGender.isNotEmpty) {
        final validatedLower = validated.toLowerCase();
        final selectedIsMan = selectedGender == 'gentleman' || selectedGender == 'man' || selectedGender == 'male';
        final detectedIsMan = validatedLower == 'man' || validatedLower == 'male';
        if (selectedIsMan != detectedIsMan) {
          final mismatchMsg = selectedIsMan
              ? 'Selected gender is Gentleman, but the photo appears to be a Woman.'
              : 'Selected gender is Lady, but the photo appears to be a Man.';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$mismatchMsg Please upload a photo matching the selected gender.')),
            );
          }
          return false;
        }
      }
      // Optional info toast when OK
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Great! Your selfie looks good.')),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Selfie validation error: $e');
      return false;
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _finish() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one model photo')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // Skip validation on Continue as requested and proceed directly
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OnboardingFullBodyScreen(
            name: widget.name,
            email: widget.email,
            gender: widget.gender,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Onboarding navigate to full-body error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVar = theme.colorScheme.onSurfaceVariant;

    Widget selfieCaptureCard() {
      return PhotoCaptureCard(
        title: 'Upload Your Photo',
        subtitle: 'Take a new photo or choose from gallery',
        icon: Icons.person,
        selectedImage: _selectedFile,
        allowCrop: !kIsWeb,
        onImageSelected: (file) async {
          // When user picks a new image or clears existing
          if (file == null) {
            // Remove current selection and delete from gallery
            final prev = _selectedModelImage;
            if (prev != null) {
              await ModelGalleryService.delete(prev.id);
            }
            await _loadExisting();
            if (mounted) setState(() => _photoAccepted = false);
            return;
          }

          // Validate BEFORE saving to gallery. Abort on failure or mismatch.
          try {
            if (mounted) setState(() => _validating = true);
            final bytes = await imgsvc.ImageService.fileToBytes(file);
            if (bytes == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Couldn't read the selected photo. Please try again.")),
                );
              }
              return;
            }

            final isGuest = SupabaseConfig.auth.currentUser == null;
            final result = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.selfie);

            bool accept = false;
            if (result != null) {
              // Remote result available
              if (!result.isOk) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.reason?.isNotEmpty == true ? result.reason! : 'Photo not accepted.')),
                  );
                }
                return;
              }
              final validated = result.gender.trim().toUpperCase();
              if (validated == 'NA') {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Can't identify a person in the photo. Please upload a clear photo.")),
                  );
                }
                return;
              }
              // Gender mismatch when a gender is selected
              final selectedGender = (widget.gender ?? '').toLowerCase();
              if (selectedGender.isNotEmpty) {
                final validatedLower = validated.toLowerCase();
                final selectedIsMan = selectedGender == 'gentleman' || selectedGender == 'man' || selectedGender == 'male';
                final detectedIsMan = validatedLower == 'man' || validatedLower == 'male';
                if (selectedIsMan != detectedIsMan) {
                  final mismatchMsg = selectedIsMan
                      ? 'Selected gender is Gentleman, but the photo appears to be a Woman.'
                      : 'Selected gender is Lady, but the photo appears to be a Man.';
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$mismatchMsg Please upload a photo matching the selected gender.')),
                    );
                  }
                  return;
                }
              }
              accept = true;
            } else {
              // Fallback: local checks (works for guest and offline)
              final local = await LocalPhotoValidator.basicChecks(bytes, PhotoType.selfie);
              if (!local.ok) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(local.reason ?? 'Photo not accepted.')),
                  );
                }
                return;
              }
              accept = true;
              if (mounted && isGuest) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selfie looks good (basic checks).')),
                );
              }
            }

            if (!accept) return;

            // Passed validation → save to gallery and mark as default
            final added = await ModelGalleryService.addFromFile(file);
            if (added != null) {
              await ModelGalleryService.setDefault(added.id);
              final prev = _selectedModelImage;
              if (prev != null && prev.id != added.id) {
                await ModelGalleryService.delete(prev.id);
              }
            }
            await _loadExisting();
            if (mounted) setState(() => _photoAccepted = true);
            if (mounted && !isGuest) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Great! Your selfie looks good.')),
              );
            }
          } catch (e) {
            debugPrint('Selfie pre-save validation failed: $e');
          } finally {
            if (mounted) setState(() => _validating = false);
          }
        },
      );
    }

    // Old camera/gallery button row is replaced by PhotoCaptureCard's bottom sheet options

    Widget examplesCard() {
      // Determine gender for examples (default to gentleman for preview when null)
      final g = (widget.gender ?? 'gentleman').toLowerCase();
      final key = g == 'lady' ? 'Lady' : 'Gentleman';
      // Use gender-specific assets for all examples
      final goodAsset = 'assets/images/selfie_${key}_example_good.jpg';
      final badDark = 'assets/images/selfie_${key}_example_bad_dark.jpg';
      final badProfile = 'assets/images/selfie_${key}_example_bad_profile.jpg';
      final badSunglasses = 'assets/images/selfie_${key}_example_bad_sun_glasses.jpg';
      Widget example({
        required bool good,
        required Color badgeColor,
        String? assetPath, // optional asset to display instead of placeholder icon
      }) {
        return Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(good ? Icons.check_circle_outline : Icons.cancel_outlined,
                          size: 16, color: badgeColor),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: assetPath != null
                        ? Image.asset(
                            assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.person_outline, size: 48, color: onSurfaceVar),
                            ),
                          )
                        : Center(child: Icon(Icons.person_outline, size: 48, color: onSurfaceVar)),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.collections_bookmark_outlined, color: onSurfaceVar),
                const SizedBox(width: 8),
                Text('Photo Examples', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                example(
                  good: true,
                  badgeColor: Colors.green,
                  assetPath: goodAsset,
                ),
                const SizedBox(width: 12),
                example(
                  good: false,
                  badgeColor: Colors.red,
                  assetPath: badDark,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                example(
                  good: false,
                  badgeColor: Colors.red,
                  assetPath: badProfile,
                ),
                const SizedBox(width: 12),
                example(
                  good: false,
                  badgeColor: Colors.red,
                  assetPath: badSunglasses,
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget infoNote() {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: onSurfaceVar),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your photo will be used to virtually try on clothing. Make sure your face is clearly visible and well-lit.',
                style: theme.textTheme.bodyMedium?.copyWith(color: onSurfaceVar),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload your selfie', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Take or upload a clear photo of yourself',
                      style: theme.textTheme.bodyLarge?.copyWith(color: onSurfaceVar)),
                  const SizedBox(height: 16),
                  selfieCaptureCard(),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _validating
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Text('Analyzing photo...',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  if (!_photoAccepted) ...[
                    examplesCard(),
                    const SizedBox(height: 16),
                    infoNote(),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting || _images.isEmpty ? null : _finish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.onSurface,
                        foregroundColor: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Continue'),
                    ),
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

class _PreviewGrid extends StatelessWidget {
  final List<ModelImage> images;
  const _PreviewGrid({required this.images});

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.of(context).size.width > 700 ? 4 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 3 / 4,
      ),
      itemBuilder: (_, idx) {
        final item = images[idx];
        Widget preview;
        if (kIsWeb) {
          final p = item.path;
          if (p.startsWith('http') || p.startsWith('blob:') || p.startsWith('data:')) {
            preview = Image.network(p, fit: BoxFit.cover);
          } else {
            preview = Container(color: Theme.of(context).colorScheme.surfaceVariant);
          }
        } else {
          preview = Image.file(File(item.path), fit: BoxFit.cover);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Positioned.fill(child: preview),
              if (item.isDefault)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        const SizedBox(width: 6),
                        Text('Default', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SelfiePreview extends StatelessWidget {
  final ModelImage image;
  const _SelfiePreview({required this.image});

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (kIsWeb) {
      final p = image.path;
      if (p.startsWith('http') || p.startsWith('blob:') || p.startsWith('data:')) {
        preview = Image.network(p, fit: BoxFit.cover);
      } else {
        preview = Container(color: Theme.of(context).colorScheme.surfaceVariant);
      }
    } else {
      preview = Image.file(File(image.path), fit: BoxFit.cover);
    }
    return Stack(
      children: [
        Positioned.fill(child: preview),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined, size: 14, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 6),
                Text('Selected',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        )
      ],
    );
  }
}
