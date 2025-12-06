import 'package:flutter/material.dart';
import 'package:envisionfit/models/tryon_session.dart';
import 'package:envisionfit/services/tryon_service.dart';
import 'package:envisionfit/screens/tryon_screen.dart';
import 'package:envisionfit/screens/history_screen.dart';
import 'package:envisionfit/widgets/result_card.dart';
import 'package:envisionfit/screens/settings_screen.dart';
import 'package:envisionfit/navigation/app_navigator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TryOnSession> _recentSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentSessions();
  }

  Future<void> _loadRecentSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await TryOnService.getRecentSessions(limit: 3);
      setState(() {
        _recentSessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recent sessions: $e')),
        );
      }
    }
  }

  void _navigateToTryOn() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const TryOnScreen()),
    ).then((_) => _loadRecentSessions());
  }

  void _navigateToHistory() {
    // Switch to the History tab
    AppNavigator.goHistory();
  }

  void _navigateToSettings() {
    // Switch to the Settings tab
    AppNavigator.goSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildQuickActions(),
              const SizedBox(height: 32),
              _buildRecentSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '👗 EnvisionFit',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Try on any outfit with AI magic',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.camera_alt,
                title: 'Try On Outfit',
                subtitle: 'Start virtual try-on',
                color: Theme.of(context).colorScheme.primary,
                onTap: _navigateToTryOn,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionCard(
                icon: Icons.history,
                title: 'View History',
                subtitle: 'Past try-ons',
                color: Theme.of(context).colorScheme.secondary,
                onTap: _navigateToHistory,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionCard(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'Model images',
                color: Theme.of(context).colorScheme.tertiary,
                onTap: _navigateToSettings,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Try-Ons',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_recentSessions.isNotEmpty)
              TextButton(
                    onPressed: _navigateToHistory,
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_recentSessions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.photo_camera,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No try-ons yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start your first virtual try-on session!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _navigateToTryOn,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Start Try-On'),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _recentSessions.map((session) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ResultCard(
                  session: session,
                  onTap: () {
                    // Handle tap - could navigate to details
                  },
                ),
              ),
            ).toList(),
          ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
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