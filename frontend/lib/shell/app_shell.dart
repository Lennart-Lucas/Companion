import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/inputs/pages/movies_tv_page.dart';
import 'package:frontend/features/productivity/pages/events_page.dart';
import 'package:frontend/features/productivity/pages/goals_page.dart';
import 'package:frontend/features/productivity/pages/productivity_overview_page.dart';
import 'package:frontend/features/productivity/pages/projects_page.dart';
import 'package:frontend/features/productivity/pages/tasks_page.dart';
import 'package:frontend/features/productivity/pages/trackers_page.dart';
import 'package:frontend/features/settings/pages/settings_ui_page.dart';
import 'package:frontend/shell/shell_app_bar_actions.dart';

/// Root shell: overlay sidebar toggled from the app bar hamburger.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      hideRailWhenClosed: true,
      showAppBar: true,
      appBarActionsListenable: ShellAppBarActions.actions,
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
              content: const ProductivityOverviewPage(),
            ),
            MenuLink(
              key: 'events',
              label: 'Events',
              iconName: 'Calendar',
              content: const EventsPage(),
            ),
            MenuLink(
              key: 'goals',
              label: 'Goals',
              iconName: 'Bullseye',
              content: const GoalsPage(),
            ),
            MenuLink(
              key: 'trackers',
              label: 'Trackers',
              iconName: 'Chart Line',
              content: const TrackersPage(),
            ),
            MenuLink(
              key: 'projects',
              label: 'Projects',
              iconName: 'Person Digging',
              content: const ProjectsPage(),
            ),
            MenuLink(
              key: 'tasks',
              label: 'Tasks',
              iconName: 'Check Double',
              content: const TasksPage(),
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
              content: const MoviesTvPage(),
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
              content: const SettingsUiPage(),
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
