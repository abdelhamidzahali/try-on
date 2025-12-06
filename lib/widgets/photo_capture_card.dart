import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:envisionfit/services/image_service.dart';

class PhotoCaptureCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final File? selectedImage;
  final Function(File?) onImageSelected;
  final bool allowCrop;
  // When true, renders the subtitle with a larger typographic style
  final bool largeSubtitle;

  const PhotoCaptureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedImage,
    required this.onImageSelected,
    this.allowCrop = true,
    this.largeSubtitle = false,
  });

  @override
  State<PhotoCaptureCard> createState() => _PhotoCaptureCardState();
}

class _PhotoCaptureCardState extends State<PhotoCaptureCard> {
  bool _isLoading = false;

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Choose Photo Source',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _SourceOptionCard(
                        icon: Icons.camera_alt,
                        title: 'Camera',
                        subtitle: 'Take a new photo',
                        onTap: () {
                          Navigator.pop(context);
                          _captureFromCamera();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SourceOptionCard(
                        icon: Icons.photo_library,
                        title: 'Gallery',
                        subtitle: 'Choose existing',
                        onTap: () {
                          Navigator.pop(context);
                          _pickFromGallery();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _captureFromCamera() async {
    setState(() => _isLoading = true);
    
    try {
      final image = await ImageService.pickImageFromCamera();
      if (image != null && widget.allowCrop) {
        final croppedImage = await ImageService.cropImage(image);
        widget.onImageSelected(croppedImage ?? image);
      } else {
        widget.onImageSelected(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isLoading = true);
    
    try {
      final image = await ImageService.pickImageFromGallery();
      if (image != null && widget.allowCrop) {
        final croppedImage = await ImageService.cropImage(image);
        widget.onImageSelected(croppedImage ?? image);
      } else {
        widget.onImageSelected(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting photo: $e')),
        );
      }
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: _isLoading ? null : _showImageSourceDialog,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.selectedImage != null)
                Builder(
                  builder: (context) {
                    if (kIsWeb) {
                      final p = widget.selectedImage!.path;
                      final isUrlLike = p.startsWith('http') || p.startsWith('blob:') || p.startsWith('data:');
                      if (isUrlLike) {
                        return Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(p),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }
                      // Fallback placeholder on web if path is not displayable
                      return Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        ),
                        child: const Center(child: Icon(Icons.image_not_supported)),
                      );
                    }
                    // Mobile/desktop path
                    return Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(widget.selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.icon,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            if (widget.title.trim().isNotEmpty) ...[
                              Text(
                                widget.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              widget.subtitle,
                              style: (widget.largeSubtitle
                                      ? Theme.of(context).textTheme.titleMedium
                                      : Theme.of(context).textTheme.bodyMedium)
                                  ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),
              if (widget.selectedImage != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _showImageSourceDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('Change'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => widget.onImageSelected(null),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceOptionCard({
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
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
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