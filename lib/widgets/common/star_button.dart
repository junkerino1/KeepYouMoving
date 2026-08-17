import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/favourite_service.dart';

/// A star icon button that toggles favourite state for a stop or route.
///
/// Shows filled star when favourited, outline when not. Tapping prompts
/// for a label (defaulting to [defaultLabel]) and creates/deletes the
/// favourite via [FavouriteService].
class StarButton extends StatelessWidget {
  final AuthService authService;
  final FavouriteService favouriteService;
  final int providerId;
  final String type; // 'stop' or 'route'
  final String? routeId;
  final String? stopId;
  final String defaultLabel;

  const StarButton({
    super.key,
    required this.authService,
    required this.favouriteService,
    required this.providerId,
    required this.type,
    this.routeId,
    this.stopId,
    required this.defaultLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: favouriteService,
      builder: (context, _) {
        final isFav = favouriteService.isFavourited(
          routeId: routeId,
          stopId: stopId,
        );
        return IconButton(
          icon: Icon(
            isFav ? Icons.star_rounded : Icons.star_border_rounded,
            color: isFav ? Colors.amber : null,
          ),
          tooltip: isFav ? 'Remove from favourites' : 'Add to favourites',
          onPressed: () => _toggle(context, isFav),
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context, bool isFav) async {
    if (!authService.isLoggedIn) {
      _showSignInPrompt(context);
      return;
    }
    if (isFav) {
      final favId = favouriteService.favouriteIdFor(
        routeId: routeId,
        stopId: stopId,
      );
      if (favId != null) {
        await favouriteService.deleteFavourite(favId);
      }
    } else {
      final label = await _promptLabel(context);
      if (label == null) return;
      await favouriteService.createFavourite(
        providerId: providerId,
        type: type,
        routeId: routeId,
        stopId: stopId,
        label: label.isEmpty ? defaultLabel : label,
      );
    }
  }

  Future<String?> _promptLabel(BuildContext context) async {
    final controller = TextEditingController(text: defaultLabel);
    return showDialog<String>(
      context: context,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return AlertDialog(
          title: Text('Save to favourites',
              style: textTheme.titleMedium),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Label',
              hintText: defaultLabel,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showSignInPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.login_rounded,
                    size: 40, color: scheme.primary),
                const SizedBox(height: 16),
                Text('Sign in required',
                    style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Sign in with Google to save favourites and access advanced features.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      authService.signInWithGoogle();
                    },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Sign in with Google'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
