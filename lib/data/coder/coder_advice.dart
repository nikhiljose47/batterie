
/// Practical coding planner advice.
///
/// Each card represents a realistic stage of a productive development day.
/// The advice focuses on completing, testing, merging, and releasing work.
const List<Map<String, Object>> coderProAdvice = <Map<String, Object>>[
  <String, Object>{
    'tip': 'Choose one task you can finish today',
    'recommendation':
        'Start with a bug, feature, or improvement that can reach a clear completed state.',
    'descriptions': <String>[
      'Confirm the expected result before coding.',
      'Create or update the task in your tracker.',
      'Finish the smallest working version first.',
    ],
  },
  <String, Object>{
    'tip': 'Implement the main feature',
    'recommendation':
        'Build the important user flow before spending time on minor improvements.',
    'descriptions': <String>[
      'Complete the main logic and interface.',
      'Handle the normal success case first.',
      'Run the feature locally from start to finish.',
    ],
  },
  <String, Object>{
    'tip': 'Complete one clean checkpoint',
    'recommendation':
        'Save a working version before moving into debugging or additional changes.',
    'descriptions': <String>[
      'Check that the app still builds.',
      'Commit the completed working section.',
      'Write a clear message describing what was implemented.',
    ],
  },
  <String, Object>{
    'tip': 'Fix the issues found during testing',
    'recommendation':
        'Test the completed flow and resolve the problems that block real usage.',
    'descriptions': <String>[
      'Reproduce each issue before changing code.',
      'Fix the root cause instead of hiding the error.',
      'Verify that the issue no longer appears.',
    ],
  },
  <String, Object>{
    'tip': 'Finish the details users will notice',
    'recommendation':
        'Complete loading, empty, error, validation, and responsive states.',
    'descriptions': <String>[
      'Check labels, spacing, and button feedback.',
      'Test with missing or incorrect data.',
      'Confirm the screen works on a small device.',
    ],
  },
  <String, Object>{
    'tip': 'Prepare the change for review',
    'recommendation':
        'Turn the completed implementation into a change another developer can safely review.',
    'descriptions': <String>[
      'Run formatting, analysis, and focused tests.',
      'Remove logs, temporary code, and unused files.',
      'Open or update the pull request with clear notes.',
    ],
  },
  <String, Object>{
    'tip': 'Close the day with something shipped',
    'recommendation':
        'Merge, release, hand off, or clearly prepare the work for the next deployment.',
    'descriptions': <String>[
      'Confirm the pull request or build status.',
      'Update the task as completed or ready for review.',
      'Write the exact next action for tomorrow.',
    ],
  },
];

/// Advanced production-focused coding planner advice.
///
/// Designed for experienced developers handling larger features, releases,
/// production stability, architecture, and team delivery.
const List<Map<String, Object>> coderSuperPlusAdvice =
    <Map<String, Object>>[
  <String, Object>{
    'tip': 'Define what will be delivered today',
    'recommendation':
        'Choose one measurable engineering outcome that can be implemented, reviewed, or released.',
    'descriptions': <String>[
      'Write the expected user or system improvement.',
      'Confirm dependencies and affected services.',
      'Define the proof required before calling it done.',
    ],
  },
  <String, Object>{
    'tip': 'Implement the production path',
    'recommendation':
        'Build the complete path that real users, data, or services will depend on.',
    'descriptions': <String>[
      'Complete the contract between components.',
      'Handle validation and failure responses.',
      'Verify the feature with realistic data.',
    ],
  },
  <String, Object>{
    'tip': 'Create a reviewable milestone',
    'recommendation':
        'Finish and commit one stable section that can be reviewed independently.',
    'descriptions': <String>[
      'Keep the change focused on one purpose.',
      'Add tests for the completed behavior.',
      'Document any important technical decision.',
    ],
  },
  <String, Object>{
    'tip': 'Remove release-blocking risks',
    'recommendation':
        'Test migrations, permissions, concurrency, offline behavior, and recovery paths.',
    'descriptions': <String>[
      'Confirm existing users are not affected.',
      'Test rollback or backward compatibility.',
      'Add useful logs for production diagnosis.',
    ],
  },
  <String, Object>{
    'tip': 'Complete the product experience',
    'recommendation':
        'Make the released feature understandable, reliable, and ready for real-world use.',
    'descriptions': <String>[
      'Verify loading, success, empty, and error states.',
      'Check performance on slower devices or networks.',
      'Remove unnecessary steps from the user flow.',
    ],
  },
  <String, Object>{
    'tip': 'Approve the change for release',
    'recommendation':
        'Review the implementation as if you will own every production issue it creates.',
    'descriptions': <String>[
      'Confirm tests cover the highest-risk behavior.',
      'Review data contracts and configuration changes.',
      'Check that monitoring and rollback are ready.',
    ],
  },
  <String, Object>{
    'tip': 'Release and verify the result',
    'recommendation':
        'Deploy, merge, or hand off the completed work and confirm that it behaves correctly.',
    'descriptions': <String>[
      'Check the build and deployment status.',
      'Verify the released feature in the target environment.',
      'Record what shipped, remaining risks, and the next task.',
    ],
  },
];
