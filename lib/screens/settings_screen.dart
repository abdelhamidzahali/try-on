import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:envisionfit/services/onboarding_service.dart';
import 'package:envisionfit/services/model_gallery_service.dart';
import 'package:envisionfit/services/fullbody_gallery_service.dart';
import 'package:envisionfit/services/photo_validation_service.dart';
import 'package:envisionfit/services/local_photo_validator.dart';
import 'package:envisionfit/services/image_service.dart' as imgsvc;
import 'package:envisionfit/services/image_service.dart';
import 'package:envisionfit/supabase/supabase_config.dart';
import 'package:envisionfit/screens/onboarding_welcome_screen.dart';
import 'package:envisionfit/widgets/title_text.dart';

class SettingsScreen extends StatefulWidget {
  final bool showAppBar;
  const SettingsScreen({super.key, this.showAppBar = true});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _validatingSelfie = false;
  bool _validatingFull = false;

  String? _name;
  String? _email;
  String? _gender; // 'gentleman' | 'lady'

  String? _selfiePath;
  String? _fullBodyPath;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    setState(() => _loading = true);
    try {
      final name = await OnboardingService.getName();
      final email = await OnboardingService.getEmail();
      final gender = await OnboardingService.getGender();
      // Prefer gallery defaults (they can change after onboarding)
      final selfie = await ModelGalleryService.getDefault();
      final full = await FullBodyGalleryService.getDefault();
      setState(() {
        _name = name;
        _email = email;
        _gender = gender;
        _selfiePath = selfie?.path ?? _selfiePath;
        _fullBodyPath = full?.path ?? _fullBodyPath;
      });
      // If galleries are empty, fallback to stored onboarding paths
      _selfiePath ??= await OnboardingService.getSelfiePath();
      _fullBodyPath ??= await OnboardingService.getFullBodyPath();
    } catch (e) {
      debugPrint('[Settings] hydrate error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _firstName {
    final n = (_name ?? '').trim();
    if (n.isEmpty) return 'My profile';
    final p = n.split(RegExp(r"\s+")).where((s) => s.isNotEmpty).toList();
    return p.isEmpty ? n : p.first;
  }

  Widget _buildImagePreview(String? path) {
    if (path == null || path.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Center(
          child: Icon(Icons.person_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    final isUrlLike = path.startsWith('http') || path.startsWith('blob:') || path.startsWith('data:');
    return kIsWeb && isUrlLike
        ? Image.network(path, fit: BoxFit.cover)
        : Image.file(File(path), fit: BoxFit.cover);
  }

  Future<void> _updateLocalProfilePaths({String? selfie, String? fullBody}) async {
    try {
      await OnboardingService.setCompleted(
        name: _name ?? '',
        email: _email ?? '',
        gender: _gender,
        selfiePath: selfie ?? _selfiePath,
        fullBodyPath: fullBody ?? _fullBodyPath,
      );
    } catch (e) {
      debugPrint('[Settings] update local profile paths failed: $e');
    }
  }

  Future<void> _upsertSupabasePhotoPaths() async {
    try {
      final uid = SupabaseConfig.auth.currentUser?.id;
      if (uid == null) return;
      await SupabaseConfig.client.from('users').update({
        if (_selfiePath != null) 'selfieImagePath': _selfiePath,
        if (_fullBodyPath != null) 'fullBodyImagePath': _fullBodyPath,
      }).eq('id', uid);
    } catch (e) {
      debugPrint('[Settings] Upsert Supabase photo paths failed: $e');
    }
  }

  bool _genderMatches(String detected) {
    final selected = (_gender ?? '').toLowerCase();
    if (selected.isEmpty) return true; // no selection to compare
    final det = detected.toLowerCase(); // 'man' | 'woman' | 'male' | 'female'
    final selectedIsMan = selected == 'gentleman' || selected == 'man' || selected == 'male';
    final detectedIsMan = det == 'man' || det == 'male';
    return selectedIsMan == detectedIsMan;
  }

  Future<void> _changeSelfie() async {
    final file = await _pickImage();
    if (file == null) return;
    try {
      setState(() => _validatingSelfie = true);
      final bytes = await imgsvc.ImageService.fileToBytes(file);
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't read the selected photo. Please try again.")),
          );
        }
        return;
      }

      // Remote validation first, fall back to local checks when unavailable.
      final remote = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.selfie);
      if (remote != null) {
        final validated = remote.gender.trim().toUpperCase();
        if (!remote.isOk) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(remote.reason?.isNotEmpty == true ? remote.reason! : 'Photo not accepted.')),
            );
          }
          return;
        }
        if (validated == 'NA') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Can't identify a person in the photo. Please upload a clear photo.")),
            );
          }
          return;
        }
        if (!_genderMatches(validated)) {
          final selectedIsMan = (_gender ?? '').toLowerCase() == 'gentleman' || (_gender ?? '').toLowerCase() == 'man' || (_gender ?? '').toLowerCase() == 'male';
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
        // Remote OK -> proceed
      } else {
        // Remote not available -> run local basic checks
        final local = await LocalPhotoValidator.basicChecks(bytes, PhotoType.selfie);
        if (!local.ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(local.reason ?? 'Photo not accepted.')),
            );
          }
          return;
        }
        // Local ok -> accept without gender enforcement (we don't have gender info locally)
      }

      // Passed validation → save to selfie gallery and keep single item
      final added = await ModelGalleryService.addFromFile(file);
      if (added != null) {
        await ModelGalleryService.setDefault(added.id);
        final all = await ModelGalleryService.getAll();
        for (final m in all) {
          if (m.id != added.id) {
            await ModelGalleryService.delete(m.id);
          }
        }
        setState(() => _selfiePath = added.path);
        await _updateLocalProfilePaths(selfie: added.path);
        await _upsertSupabasePhotoPaths();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Great! Your selfie looks good.')),
        );
      }
    } catch (e) {
      debugPrint('[Settings] changeSelfie error: $e');
    } finally {
      if (mounted) setState(() => _validatingSelfie = false);
    }
  }

  Future<void> _changeFullBody() async {
    final file = await _pickImage();
    if (file == null) return;
    try {
      setState(() => _validatingFull = true);
      final bytes = await imgsvc.ImageService.fileToBytes(file);
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't read the selected photo. Please try again.")),
          );
        }
        return;
      }
      // Remote validation first, with local fallback
      final remote = await PhotoValidationService.validateBytes(bytes: bytes, type: PhotoType.fullbody);
      if (remote != null) {
        final validated = remote.gender.trim().toUpperCase();
        if (!remote.isOk) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(remote.reason?.isNotEmpty == true ? remote.reason! : 'Photo not accepted.')),
            );
          }
          return;
        }
        if (validated == 'NA') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Can't identify a person in the photo. Please upload a clear photo.")),
            );
          }
          return;
        }
        if (!_genderMatches(validated)) {
          final selectedIsMan = (_gender ?? '').toLowerCase() == 'gentleman' || (_gender ?? '').toLowerCase() == 'man' || (_gender ?? '').toLowerCase() == 'male';
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
        // Remote OK -> proceed
      } else {
        final local = await LocalPhotoValidator.basicChecks(bytes, PhotoType.fullbody);
        if (!local.ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(local.reason ?? 'Photo not accepted.')),
            );
          }
          return;
        }
        // Local ok -> accept
      }

      // Passed validation → save to full-body gallery and keep single item. Also mark as default for try-on.
      final added = await FullBodyGalleryService.addFromFile(file);
      if (added != null) {
        await FullBodyGalleryService.setDefault(added.id);
        final all = await FullBodyGalleryService.getAll();
        for (final m in all) {
          if (m.id != added.id) {
            await FullBodyGalleryService.delete(m.id);
          }
        }
        setState(() => _fullBodyPath = added.path);
        await _updateLocalProfilePaths(fullBody: added.path);
        await _upsertSupabasePhotoPaths();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Great! Your full-body photo looks good.')),
        );
      }
    } catch (e) {
      debugPrint('[Settings] changeFullBody error: $e');
    } finally {
      if (mounted) setState(() => _validatingFull = false);
    }
  }

  Future<File?> _pickImage() async {
    // Simple chooser between camera and gallery
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, 0),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, 1),
              ),
            ],
          ),
        );
      },
    );
    if (choice == null) return null;
    return choice == 0 ? await ImageService.pickImageFromCamera() : await ImageService.pickImageFromGallery();
  }

  Future<void> _logout() async {
    try {
      await SupabaseConfig.auth.signOut();
    } catch (e) {
      debugPrint('[Settings] logout error: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingWelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final onSurfaceVar = colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Stack(
                children: [
                  // Background typographic texture to match Try-On
                  Positioned(
                    top: -24,
                    right: -36,
                    child: IgnorePointer(
                      ignoring: true,
                      child: Opacity(
                        opacity: theme.brightness == Brightness.light ? 0.06 : 0.04,
                        child: Text(
                          'Profile',
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
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                               const SizedBox(height: 16),
                              _buildProfileSection(context),
                              const SizedBox(height: 12),
                              _buildConnector(context),
                              const SizedBox(height: 12),
                              _buildSelfieSection(context),
                              const SizedBox(height: 12),
                              _buildConnector(context),
                              const SizedBox(height: 12),
                              _buildFullBodySection(context),
                              const SizedBox(height: 20),
                              _buildLogoutCta(context),
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
          if (widget.showAppBar)
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.arrow_back, size: 16, color: colorScheme.onSurface),
              ),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              alignment: Alignment.center,
              // Changed top Settings icon to Home icon per request
              child: Icon(Icons.home, size: 16, color: colorScheme.onSurface),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('01', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.35), fontStyle: FontStyle.italic)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
              child: Text('THE PROFILE', style: textTheme.labelSmall?.copyWith(color: Colors.white, letterSpacing: 2.2, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container
            (
            height: 128,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surfaceContainerHighest,
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _firstName,
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((_gender ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        _gender!.substring(0, 1).toUpperCase() + _gender!.substring(1),
                        style: textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).brightness == Brightness.light
                              ? colorScheme.onSurface.withValues(alpha: 0.7)
                              : colorScheme.onSurfaceVariant,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
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

  Widget _buildSelfieSection(BuildContext context) {
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
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Text('SELFIE', style: textTheme.labelSmall?.copyWith(color: Colors.white, letterSpacing: 2.2, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Text('02', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.35), fontStyle: FontStyle.italic)),
          ],
        ),
        const SizedBox(height: 8),
        // Flatter card (shadow layer removed)
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          height: 140,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                child: SizedBox(width: 140, height: double.infinity, child: _buildImagePreview(_selfiePath)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This photo will be used as a reference for your faciale features', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7))),
                      const Spacer(),
                      Row(
                        children: [
                          if (_validatingSelfie) ...[
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Analyzing photo...', style: textTheme.labelMedium?.copyWith(color: colorScheme.primary), overflow: TextOverflow.ellipsis),
                            ),
                          ] else ...[
                            TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: Colors.black)),
                              ),
                              onPressed: _changeSelfie,
                              child: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullBodySection(BuildContext context) {
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
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Text('FULL BODY', style: textTheme.labelSmall?.copyWith(color: Colors.white, letterSpacing: 2.2, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Text('03', style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.35), fontStyle: FontStyle.italic)),
          ],
        ),
        const SizedBox(height: 8),
        // Flatter card (shadow layer removed)
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light ? Colors.white : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          height: 168,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                child: SizedBox(width: 120, height: double.infinity, child: _buildImagePreview(_fullBodyPath)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This photo will be used as a reference for your body shape, build and proportions', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7))),
                      const Spacer(),
                      Row(
                        children: [
                          if (_validatingFull) ...[
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Analyzing photo...', style: textTheme.labelMedium?.copyWith(color: colorScheme.primary), overflow: TextOverflow.ellipsis),
                            ),
                          ] else ...[
                            TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: Colors.black)),
                              ),
                              onPressed: _changeFullBody,
                              child: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutCta(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: InkWell(
        onTap: _logout,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Log out',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, letterSpacing: 2.2),
              ),
              Icon(Icons.logout, color: Colors.black, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
