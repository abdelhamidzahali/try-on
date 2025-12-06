import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:envisionfit/supabase/supabase_config.dart';
import 'package:envisionfit/screens/onboarding_photos_screen.dart';

class GenderSelectionScreen extends StatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen> {
  // Hover states for subtle web animations
  bool _hoverLady = false;
  bool _hoverGent = false;

  String _deriveFirstName(Map<String, dynamic>? meta, String? email) {
    try {
      final m = meta ?? const {};
      final given = (m['given_name'] ?? m['given'] ?? '').toString().trim();
      if (given.isNotEmpty) return given;
      final full = (m['full_name'] ?? m['name'] ?? '').toString().trim();
      if (full.isNotEmpty) {
        final parts = full.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) return parts.first;
      }
      final e = (email ?? '').trim();
      if (e.contains('@')) return e.split('@').first;
      return 'Friend';
    } catch (_) {
      return 'Friend';
    }
  }

  String _deriveName(Map<String, dynamic>? meta, String? email) {
    try {
      final m = meta ?? const {};
      final full = (m['full_name'] ?? m['name'] ?? '').toString().trim();
      if (full.isNotEmpty) return full;
      final given = (m['given_name'] ?? '').toString().trim();
      final family = (m['family_name'] ?? '').toString().trim();
      final combined = [given, family].where((e) => e.isNotEmpty).join(' ');
      if (combined.isNotEmpty) return combined;
      return email ?? 'User';
    } catch (_) {
      return email ?? 'User';
    }
  }

  void _onSelect(String gender) {
    final user = SupabaseConfig.auth.currentUser;
    final name = _deriveName(user?.userMetadata as Map<String, dynamic>?, user?.email);
    final email = user?.email ?? '';
    debugPrint('[GenderSelection] selected=$gender name=$name email=$email');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingPhotosScreen(
          name: name,
          email: email,
          gender: gender,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = SupabaseConfig.auth.currentUser;
    final firstName = _deriveFirstName(user?.userMetadata as Map<String, dynamic>?, user?.email);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background: two split images (same assets as sign-in)
          Positioned.fill(
            child: Row(
              children: const [
                Expanded(child: _BackgroundAssetImage(assetPath: 'assets/images/lady_onbaording_screen_1.png')),
                Expanded(child: _BackgroundAssetImage(assetPath: 'assets/images/Gentleman_onbaording_screen_1.png')),
              ],
            ),
          ),

          // Gradient overlay to keep faces subtle and text readable
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.90),
                    Colors.black.withValues(alpha: 0.30),
                    Colors.black.withValues(alpha: 0.40),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
                    child: Column(
                      children: [
                        Text(
                          'Welcome',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Whom should we style today${firstName.isNotEmpty ? ', ' + firstName : ''}?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Interactive split options
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _SelectOverlay(
                            label: 'Lady',
                            hovered: _hoverLady,
                            onHover: (v) => setState(() => _hoverLady = v),
                            onTap: () => _onSelect('lady'),
                          ),
                        ),
                        Expanded(
                          child: _SelectOverlay(
                            label: 'Gentleman',
                            hovered: _hoverGent,
                            onHover: (v) => setState(() => _hoverGent = v),
                            onTap: () => _onSelect('gentleman'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer step indicator
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 8),
                    child: Text(
                      'Step 2 of 2',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.40),
                        letterSpacing: 2.0,
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
  }
}

/// Invisible interactive layer for each half that animates hover/press and shows label.
class _SelectOverlay extends StatefulWidget {
  final String label;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  const _SelectOverlay({
    required this.label,
    required this.hovered,
    required this.onHover,
    required this.onTap,
  });

  @override
  State<_SelectOverlay> createState() => _SelectOverlayState();
}

class _SelectOverlayState extends State<_SelectOverlay> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => widget.onHover(true),
      onExit: (_) => widget.onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          scale: (widget.hovered || _pressed) ? 1.02 : 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Localized subtle gradient for each side
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: widget.hovered ? 0.70 : 0.90),
                      Colors.black.withValues(alpha: widget.hovered ? 0.10 : 0.30),
                      Colors.black.withValues(alpha: widget.hovered ? 0.20 : 0.40),
                    ],
                  ),
                  border: Border(
                    right: BorderSide(color: Colors.white.withValues(alpha: 0.10), width: 0.6),
                  ),
                ),
              ),
              Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: theme.textTheme.titleLarge!.copyWith(
                    color: Colors.white,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(widget.label.toUpperCase()),
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

class _BackgroundAssetImage extends StatelessWidget {
  final String assetPath;
  const _BackgroundAssetImage({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.85,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          return const ColoredBox(color: Colors.black);
        },
      ),
    );
  }
}
