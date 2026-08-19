import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/route_controller.dart';
import '../controllers/stop_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/session.dart';
import '../models/transit_route.dart';
import '../models/transit_provider.dart';
import '../services/auth_service.dart';
import '../services/app_metadata.dart';
import '../services/favourite_service.dart';
import '../services/provider_repository.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/stops/provider_switcher.dart';
import 'route_detail_screen.dart';
import 'stop_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.themeController,
    required this.authService,
    required this.favouriteService,
  });

  final ThemeController themeController;
  final AuthService authService;
  final FavouriteService favouriteService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const int _sessionsPerPage = 3;

  String? _openingFavouriteId;
  Future<List<AccountSession>>? _sessionsFuture;
  int _sessionPage = 0;

  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_onAuthChanged);
    if (widget.authService.isLoggedIn) {
      _sessionsFuture = widget.authService.fetchSessions();
      widget.favouriteService.loadFavourites();
    }
  }

  @override
  void dispose() {
    widget.authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    setState(() {
      _sessionPage = 0;
      _sessionsFuture = widget.authService.isLoggedIn
          ? widget.authService.fetchSessions()
          : null;
    });
    if (widget.authService.isLoggedIn) {
      widget.favouriteService.loadFavourites();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = widget.authService;
    final isLoggedIn = authService.isLoggedIn;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Header
        _buildHeader(context),
        const SizedBox(height: 24),

        // Account section
        if (!isLoggedIn) ...[
          _buildSignInCard(context),
        ] else ...[
          _buildAccountCard(context),
          const SizedBox(height: 20),
          _buildSessionsSection(context),
        ],

        const SizedBox(height: 20),
        const _SectionHeader('Favourites'),
        if (isLoggedIn)
          _buildFavouritesSection(context)
        else
          _buildFavouritesSignedOut(context),

        const SizedBox(height: 20),
        const _SectionHeader('Appearance'),
        _buildThemeCard(context),

        const SizedBox(height: 20),
        const _SectionHeader('About'),
        _buildAboutCard(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final account = widget.authService.account;

    return Row(
      children: [
        if (account?.profilePictureUrl != null ||
            account?.googlePictureUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              account!.profilePictureUrl ?? account.googlePictureUrl!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.person_rounded,
                    size: 24, color: scheme.onPrimary),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.directions_bus_rounded,
                size: 28, color: scheme.onPrimary),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account?.fullName ?? 'RapidTransit KL',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                account?.email ?? 'Your transit companion',
                style: textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignInCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLoading = widget.authService.isLoading;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.login_rounded, size: 36, color: scheme.primary),
            const SizedBox(height: 12),
            Text('Sign in to sync your data', style: textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'Save favourites, access from multiple devices, and more.',
              textAlign: TextAlign.center,
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isLoading
                    ? null
                    : () => widget.authService.signInWithGoogle(),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login_rounded, size: 18),
                label: Text(
                    isLoading ? 'Opening browser...' : 'Sign in with Google'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            if (widget.authService.error != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.authService.error!,
                style: textTheme.bodySmall?.copyWith(color: scheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final account = widget.authService.account!;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle_rounded,
                    size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Text('Account', style: textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(context, 'Name', account.fullName),
            _infoRow(context, 'Email', account.email),
            if (account.dateOfBirth != null && account.dateOfBirth!.isNotEmpty)
              _infoRow(context, 'Birthday', account.dateOfBirth!),
            if (account.lastLoginAt != null)
              _infoRow(
                  context, 'Last login', _formatDate(account.lastLoginAt!)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _editProfile(context),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit profile'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: FutureBuilder(
        future: _sessionsFuture ??= widget.authService.fetchSessions(),
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final pageCount = sessions.isEmpty
              ? 1
              : (sessions.length / _sessionsPerPage).ceil();
          final currentPage = _sessionPage.clamp(0, pageCount - 1);
          final pageStart = currentPage * _sessionsPerPage;
          final pageSessions = sessions
              .skip(pageStart)
              .take(_sessionsPerPage)
              .toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.devices_rounded,
                        size: 20, color: scheme.primary),
                    const SizedBox(width: 10),
                    Text('Sessions', style: textTheme.titleSmall),
                    const Spacer(),
                    Text('${sessions.length}', style: textTheme.labelMedium),
                  ],
                ),
              ),
              for (final session in pageSessions) ...[
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        session.isCurrent
                            ? Icons.phone_android_rounded
                            : Icons.phone_iphone_rounded,
                        size: 20,
                        color: session.isRevoked
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    session.device?.deviceModel.isNotEmpty ==
                                            true
                                        ? session.device!.deviceModel
                                        : session.name,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (session.isCurrent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.emeraldDark,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Current',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: Colors.white,
                                          fontSize: 10,
                                        )),
                                  ),
                                ],
                                if (session.isRevoked) ...[
                                  const SizedBox(width: 8),
                                  Text('Revoked',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: scheme.error,
                                      )),
                                ],
                              ],
                            ),
                            if (session.lastUsedAt != null)
                              Text(
                                'Last used: ${_formatDate(session.lastUsedAt!)}',
                                style: textTheme.bodySmall,
                              ),
                            if (session.device != null)
                              Text(
                                '${session.device!.platform} ${session.device!.appVersion}',
                                style: textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      if (!session.isCurrent && !session.isRevoked)
                        IconButton(
                          icon: Icon(Icons.block_rounded,
                              size: 18, color: scheme.error),
                          tooltip: 'Revoke',
                          onPressed: () => _revokeSession(context, session.id),
                        ),
                    ],
                  ),
                ),
              ],
              if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child:
                        Text('No active sessions', style: textTheme.bodySmall),
                  ),
                ),
              if (sessions.length > _sessionsPerPage) ...[
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: currentPage > 0
                            ? () => setState(() => _sessionPage--)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'Previous page',
                      ),
                      Text('${currentPage + 1} / $pageCount',
                          style: textTheme.labelMedium),
                      IconButton(
                        onPressed: currentPage < pageCount - 1
                            ? () => setState(() => _sessionPage++)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Next page',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildFavouritesSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: widget.favouriteService,
      builder: (context, _) {
        final favs = widget.favouriteService.favourites;
        if (widget.favouriteService.isLoading) {
          return const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
        if (favs.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.bookmark_border_rounded,
                      size: 28, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text('No favourites yet', style: textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Star a stop or route to save it here.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < favs.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildFavouriteItem(context, favs[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavouriteItem(BuildContext context, dynamic fav) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final f = fav as Map<String, dynamic>;
    final type = f['type'] as String? ?? '';
    final label = f['label'] as String? ?? '';
    final entity = f['entity'] as Map<String, dynamic>?;
    final routeInfo = entity?['route'] as Map<String, dynamic>?;
    final stopInfo = entity?['stop'] as Map<String, dynamic>?;

    final displayName = routeInfo?['route_short_name'] as String? ??
        stopInfo?['stop_name'] as String? ??
        label;
    final subtitle = routeInfo?['route_long_name'] as String? ??
        stopInfo?['stop_code'] as String? ??
        '';
    final favouriteId = f['id'] as String? ?? '';
    final isOpening = _openingFavouriteId == favouriteId;

    return ListTile(
      onTap: isOpening ? null : () => _openFavourite(context, f),
      leading: Icon(
        type == 'route'
            ? Icons.directions_bus_rounded
            : Icons.location_on_rounded,
        color: scheme.primary,
      ),
      title: Text(label.isNotEmpty ? label : displayName,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          )),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle,
              style: textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOpening)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.chevron_right_rounded,
                size: 22, color: scheme.onSurfaceVariant),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                size: 20, color: scheme.error),
            tooltip: 'Delete',
            onPressed:
                isOpening ? null : () => _deleteFavourite(context, favouriteId),
          ),
        ],
      ),
    );
  }

  Future<void> _openFavourite(
      BuildContext context, Map<String, dynamic> favourite) async {
    final favouriteId = favourite['id'] as String? ?? '';
    if (favouriteId.isEmpty) return;
    setState(() => _openingFavouriteId = favouriteId);

    try {
      final providerId = _parseInt(favourite['provider_id']);
      if (providerId == null) {
        throw StateError('Favourite has no provider');
      }
      final provider = await ProviderRepository().getProviderById(providerId);
      if (!context.mounted) return;

      final type = (favourite['type'] as String? ?? '').toLowerCase();
      if (type == 'route') {
        final route = _routeFromFavourite(favourite);
        if (route == null) throw StateError('Favourite has no route');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RouteDetailScreen(
              route: route,
              providerId: providerId,
              providerKey: provider?.providerKey,
            ),
          ),
        );
      } else if (type == 'stop') {
        await _openStopFavourite(
          context,
          favourite,
          providerId: providerId,
          provider: provider,
        );
      } else {
        throw StateError('Unsupported favourite type');
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this favourite.')),
      );
    } finally {
      if (mounted) setState(() => _openingFavouriteId = null);
    }
  }

  Future<void> _openStopFavourite(
    BuildContext context,
    Map<String, dynamic> favourite, {
    required int providerId,
    required TransitProvider? provider,
  }) async {
    final entity = favourite['entity'] as Map<String, dynamic>?;
    final stopInfo = entity?['stop'] as Map<String, dynamic>?;
    final stopId = favourite['stop_id'] as String? ??
        stopInfo?['stop_id'] as String? ??
        '';
    if (stopId.isEmpty) throw StateError('Favourite has no stop');

    final stopController = StopController();
    final routeController = RouteController();
    try {
      final routes = await stopController.loadRoutesForStop(
        providerId: providerId,
        stopId: stopId,
      );
      final route = routes.isEmpty ? null : routes.first;
      var latitude = _parseDouble(stopInfo?['stop_lat']);
      var longitude = _parseDouble(stopInfo?['stop_lon']);

      // Favourite payloads may omit coordinates. Resolve them from the first
      // serving route so the detail screen always opens at the real stop.
      if (route != null && (latitude == null || longitude == null)) {
        await routeController.loadRouteStops(
          providerId: providerId,
          routeId: route.routeId,
        );
        final routeStop = routeController.stops.firstWhere(
          (stop) => stop.stopId == stopId,
          orElse: () => throw StateError('Stop was not found on route'),
        );
        latitude = routeStop.stopLat;
        longitude = routeStop.stopLon;
      }

      if (latitude == null || longitude == null) {
        throw StateError('Favourite has no stop coordinates');
      }

      if (!context.mounted) return;
      final stopName = stopInfo?['stop_name'] as String? ??
          favourite['label'] as String? ??
          'Stop';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StopDetailScreen(
            stopName: stopName,
            stopLine: provider == null
                ? 'Provider $providerId'
                : providerShortLabel(provider),
            latitude: latitude!,
            longitude: longitude!,
            stopId: stopId,
            providerId: providerId,
            providerKey: provider?.providerKey,
            route: route,
          ),
        ),
      );
    } finally {
      stopController.dispose();
      routeController.dispose();
    }
  }

  TransitRoute? _routeFromFavourite(Map<String, dynamic> favourite) {
    final entity = favourite['entity'] as Map<String, dynamic>?;
    final routeInfo = entity?['route'] as Map<String, dynamic>?;
    final routeId = favourite['route_id'] as String? ??
        routeInfo?['route_id'] as String? ??
        '';
    if (routeId.isEmpty) return null;
    return TransitRoute(
      routeId: routeId,
      routeShortName: routeInfo?['route_short_name'] as String? ??
          favourite['label'] as String? ??
          routeId,
      routeLongName: routeInfo?['route_long_name'] as String? ?? '',
      routeType: routeInfo?['route_type'] as String? ?? '',
    );
  }

  static int? _parseInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value as String? ?? '');
  }

  static double? _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value as String? ?? '');
  }

  Widget _buildFavouritesSignedOut(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.bookmark_border_rounded,
                size: 28, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text('Sign in to save favourites', style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Star stops and routes to quickly access them later.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.brightness_auto_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Theme', style: textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Changes apply instantly and reset to System on restart.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: widget.themeController,
              builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {mode},
                onSelectionChanged: (selection) =>
                    widget.themeController.setMode(selection.first),
                showSelectedIcon: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: scheme.primary),
            title: const Text('Version'),
            trailing:
                Text(AppMetadata.appVersion, style: textTheme.labelMedium),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.hub_outlined, color: scheme.primary),
            title: const Text('Transit data'),
            subtitle: const Text('data.gov.my GTFS & real-time feeds'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => formatLocalDateTime(date);

  Future<void> _editProfile(BuildContext context) async {
    final account = widget.authService.account;
    if (account == null) return;
    final result = await showDialog<_EditProfileResult>(
      context: context,
      builder: (_) => _EditProfileDialog(
        initialFullName: account.fullName,
        initialDateOfBirth: account.dateOfBirth ?? '',
      ),
    );
    if (result == null || !context.mounted) return;
    final ok = await widget.authService.updateProfile(
      fullName: result.fullName,
      dateOfBirth:
          result.dateOfBirth.isEmpty ? null : result.dateOfBirth,
      profileImage: result.profileImage,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profile updated.' : 'Could not update profile.'),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You will need to sign in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.authService.logout();
    }
  }

  Future<void> _revokeSession(BuildContext context, String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke session?'),
        content: const Text('This device will be signed out immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.authService.revokeSession(sessionId);
      setState(() {
        _sessionsFuture = widget.authService.fetchSessions();
      });
    }
  }

  Future<void> _deleteFavourite(BuildContext context, String favId) async {
    await widget.favouriteService.deleteFavourite(favId);
  }
}

class _EditProfileResult {
  const _EditProfileResult({
    required this.fullName,
    required this.dateOfBirth,
    required this.profileImage,
  });

  final String fullName;
  final String dateOfBirth;
  final XFile? profileImage;
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.initialFullName,
    required this.initialDateOfBirth,
  });

  final String initialFullName;
  final String initialDateOfBirth;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _dobController;
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialFullName);
    _dobController = TextEditingController(text: widget.initialDateOfBirth);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final initial =
        DateTime.tryParse(_dobController.text) ?? DateTime(2000, 1, 1);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    _dobController.text = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;
    setState(() => _pickedImage = image);
  }

  void _save() {
    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) return;
    Navigator.of(context).pop(
      _EditProfileResult(
        fullName: fullName,
        dateOfBirth: _dobController.text.trim(),
        profileImage: _pickedImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dobController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date of birth',
                hintText: 'YYYY-MM-DD',
                suffixIcon: Icon(Icons.calendar_month_rounded),
              ),
              onTap: _selectDate,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _selectImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _pickedImage == null
                    ? 'Choose profile picture'
                    : 'Picture selected',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: textTheme.labelMedium?.copyWith(letterSpacing: 0.8),
      ),
    );
  }
}
