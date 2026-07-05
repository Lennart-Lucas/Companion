/// Cycles task workflow status for list interactions.
String nextTaskStatus(String current) => switch (current) {
      'pending' => 'in_progress',
      'in_progress' => 'completed',
      'completed' => 'cancelled',
      'cancelled' => 'pending',
      _ => 'pending',
    };
