import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/core/routing/companion_routes.dart';
import 'package:frontend/shell/shell_app_bar_actions.dart';

const _placeholderContent = SizedBox.shrink();

/// Root shell: overlay sidebar toggled from the app bar hamburger.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedMenuKey =
        CompanionRoutes.menuKeyForLocation(location) ?? 'overview';

    return CollapsibleDrawer(
      hideRailWhenClosed: true,
      showAppBar: true,
      appBarActionsListenable: ShellAppBarActions.actions,
      shellChild: navigationShell,
      selectedMenuKey: selectedMenuKey,
      onMenuLinkSelected: (menuKey) {
        CompanionNavigation.goShellMenuKey(context, menuKey);
      },
      menuItems: [
        MenuGroup(
          key: 'productivity',
          label: 'Productivity',
          iconName: 'Hammer',
          children: [
            MenuLink(
              key: 'overview',
              label: 'Overview',
              iconName: 'House',
              content: _placeholderContent,
            ),
            MenuLink(
              key: 'events',
              label: 'Events',
              iconName: 'Calendar',
              content: _placeholderContent,
            ),
            MenuLink(
              key: 'goals',
              label: 'Goals',
              iconName: 'Bullseye',
              content: _placeholderContent,
            ),
            MenuLink(
              key: 'trackers',
              label: 'Trackers',
              iconName: 'Chart Line',
              content: _placeholderContent,
            ),
            MenuLink(
              key: 'projects',
              label: 'Projects',
              iconName: 'Person Digging',
              content: _placeholderContent,
            ),
            MenuLink(
              key: 'tasks',
              label: 'Tasks',
              iconName: 'Check Double',
              content: _placeholderContent,
            ),
          ],
        ),
        MenuGroup(
          key: 'inputs',
          label: 'Inputs',
          iconName: 'Inbox',
          children: [
            MenuLink(
              key: 'movies-tv',
              label: 'Movies & TV',
              iconName: 'Clapperboard',
              content: _placeholderContent,
            ),
          ],
        ),
        MenuGroup(
          key: 'settings',
          label: 'Settings',
          iconName: 'Gear',
          children: [
            MenuLink(
              key: 'settings-ui',
              label: 'UI',
              iconName: 'Gear',
              content: _placeholderContent,
            ),
          ],
        ),
        MenuAction(
          key: 'logout',
          label: 'Log out',
          iconName: 'Logout',
          action: () {
            context.read<AuthBloc>().add(const LogoutRequested());
          },
        ),
      ],
    );
  }
}
