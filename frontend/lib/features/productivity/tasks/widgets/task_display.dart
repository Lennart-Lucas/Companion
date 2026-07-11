import 'package:flutter/material.dart';

import 'package:frontend/core/ui/outcome_colors.dart';

export 'package:frontend/core/formatting/date_formatting.dart';
export 'package:frontend/core/formatting/week_calendar.dart';

const String taskCompletedStatusLabel = 'Done';

IconData taskCompletedStatusChipIcon() => Icons.check_circle_outline;

Color taskCompletedStatusColor() => trackerStrengthHighColor;

String taskStatusLabel(String value) => switch (value) {
      'pending' => 'Pending',
      'in_progress' => 'In progress',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => value,
    };

String taskPriorityLabel(String value) => switch (value) {
      'low' => 'Low',
      'medium' => 'Medium',
      'high' => 'High',
      'urgent' => 'Urgent',
      _ => value,
    };