import 'package:flutter/material.dart';

/// A lightweight, dependency-free animated widget to indicate background work.
/// Used during try-on image generation.
class AnimatedPreparing extends StatefulWidget {
  final String title;
  final String subtitle;
  // When true, appends animated trailing dots to the title (default).
  // When false, the title is rendered as-is.
  final bool animateDots;

  const AnimatedPreparing({
    super.key,
    required this.title,
    required this.subtitle,
    this.animateDots = true,
  });

  @override
  State<AnimatedPreparing> createState() => _AnimatedPreparingState();
}

class _AnimatedPreparingState extends State<AnimatedPreparing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _rotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _shimmer = Tween<double>(begin: -0.4, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceVariant.withValues(alpha: 0.5);
    final accent = theme.colorScheme.primary;
    final accentContainer = theme.colorScheme.primaryContainer.withValues(alpha: 0.3);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accentContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Rotating icon badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.18),
                          accent.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: _rotation.value * 6.283185307179586, // 2π
                        child: Icon(
                          Icons.auto_awesome,
                          color: accent,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title (optionally with animated trailing dots)
                        if (widget.animateDots)
                          _AnimatedDotsText(
                            baseText: widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            progress: _controller.value,
                          )
                        else
                          Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Shimmer progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: surface),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.28,
                        child: Transform.translate(
                          offset: Offset(_shimmer.value * MediaQuery.of(context).size.width, 0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  accent.withValues(alpha: 0.0),
                                  accent.withValues(alpha: 0.35),
                                  accent.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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

class _AnimatedDotsText extends StatelessWidget {
  final String baseText;
  final TextStyle? style;
  final double progress; // 0..1 loop

  const _AnimatedDotsText({
    required this.baseText,
    required this.style,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final dotCount = 1 + ((progress * 3).floor() % 3);
    final dots = '.' * dotCount;
    return Text('$baseText$dots', style: style);
  }
}
