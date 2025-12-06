import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:envisionfit/models/tryon_session.dart';

class ResultCard extends StatelessWidget {
  final TryOnSession session;
  final VoidCallback? onTap;

  const ResultCard({
    super.key,
    required this.session,
    this.onTap,
  });

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
              _buildPreviewImage(),
              const SizedBox(width: 16),
              Expanded(
                child: _buildContent(context),
              ),
              _buildStatusIndicator(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewImage() {
    // Prefer the generated result image once the session is completed;
    // fall back to the user's original photo otherwise.
    final previewPath = (session.status == TryOnStatus.completed &&
            session.result?.imagePath.isNotEmpty == true)
        ? session.result!.imagePath
        : session.userPhotoPath;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.withValues(alpha: 0.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Builder(
          builder: (context) {
            final path = previewPath;
            final isNetwork = path.startsWith('http') || path.startsWith('blob:') || path.startsWith('data:');
            if (isNetwork) {
              return Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              );
            }
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(
        Icons.image,
        color: Colors.grey,
        size: 24,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Try-On Session',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDateTime(session.createdAt),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (session.status == TryOnStatus.completed && session.result != null) ...[
          Text(
            session.result!.prompt.length > 100
                ? '${session.result!.prompt.substring(0, 100)}...'
                : session.result!.prompt,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ] else if (session.status == TryOnStatus.failed) ...[
          Text(
            session.errorMessage ?? 'Try-on failed',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ] else ...[
          Text(
            session.statusText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: session.status == TryOnStatus.processing
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    IconData icon;
    Color color;

    switch (session.status) {
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

    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          session.statusText,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}