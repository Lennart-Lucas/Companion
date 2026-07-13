import 'package:flutter/material.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/core/routing/companion_routes.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_card_carousel.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_project_card.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_section.dart';
import 'package:go_router/go_router.dart';

class WeeklySummaryProjectsSection extends StatelessWidget {
  const WeeklySummaryProjectsSection({super.key, required this.projects});

  final List<WeeklyProjectSummary> projects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return WeeklySummarySection(
      title: 'Projects',
      onViewAll: () => context.go(CompanionRoutes.productivityProjects),
      child: projects.isEmpty
          ? Text(
              'No active projects this week',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : WeeklySummaryCardCarousel(
              itemCount: projects.length,
              cardWidth: 320,
              cardHeight: 280,
              itemBuilder: (context, index) {
                final item = projects[index];
                return WeeklySummaryProjectCard(
                  summary: item,
                  onTap: () => CompanionNavigation.openProjectDetail(
                    context,
                    projectId: item.project.id,
                    project: item.project,
                  ),
                  onTaskTap: (entry) => CompanionNavigation.openTaskEdit(
                    context,
                    taskId: entry.task.id,
                  ),
                );
              },
            ),
    );
  }
}
