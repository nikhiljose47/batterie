import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════
//  SERVICE CATALOG — the single source of truth for the Services hub.
//
//  HOW TO EDIT
//  ───────────
//  • Add a service: copy any AppService(...) block, give it a unique `id`,
//    pick a category, done. It appears in the hub automatically.
//  • Remove a service: delete its block.
//  • Rename / re-describe: edit `name`, `tagline`, `description`, `features`.
//  • `keywords` feed the search bar — add every word a user might type.
//  • To make a service "real", build its page and register it in
//    `services_page.dart` → `_openService()` (see the BMI example there).
// ═══════════════════════════════════════════════════════════════════════

/// Filter tags shown as scrollable chips under the search bar.
enum ServiceCategory {
  health('Health', '❤️'),
  women('Women', '🌸'),
  mind('Mind', '🧘'),
  food('Food', '🥗'),
  finance('Money', '💰'),
  productivity('Plan', '🗓️'),
  lifestyle('Track', '📊');

  const ServiceCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

class AppService {
  const AppService({
    required this.id,
    required this.emoji,
    required this.name,
    required this.tagline,
    required this.category,
    required this.keywords,
    required this.features,
  });

  /// Stable unique key — used for routing to a real page once built.
  final String id;
  final String emoji;
  final String name;

  /// One line shown on the tile.
  final String tagline;
  final ServiceCategory category;

  /// Lower-case search terms (name is matched automatically).
  final List<String> keywords;

  /// "What it will include" — shown on the detail page.
  final List<String> features;
}

const List<AppService> serviceCatalog = <AppService>[
  // ── HEALTH ────────────────────────────────────────────────────────────
  AppService(
    id: 'bmi',
    emoji: '⚖️',
    name: 'BMI Calculator',
    tagline: 'Body mass index in two sliders',
    category: ServiceCategory.health,
    keywords: <String>['bmi', 'body', 'mass', 'weight', 'height'],
    features: <String>[
      'Height & weight sliders',
      'Instant BMI with category',
      'Healthy weight range for your height',
    ],
  ),
  AppService(
    id: 'sleep_tracker',
    emoji: '😴',
    name: 'Sleep Tracker',
    tagline: 'Log bed & wake times, see debt',
    category: ServiceCategory.health,
    keywords: <String>['sleep', 'bed', 'wake', 'rest', 'insomnia'],
    features: <String>[
      'Nightly bed / wake log',
      'Sleep debt vs 8 h target',
      'Weekly consistency chart',
    ],
  ),
  AppService(
    id: 'water',
    emoji: '💧',
    name: 'Water Tracker',
    tagline: 'Glasses per day with reminders',
    category: ServiceCategory.health,
    keywords: <String>['water', 'hydration', 'drink', 'glass'],
    features: <String>[
      'One-tap glass logging',
      'Daily goal ring',
      'Hourly nudge reminders',
    ],
  ),
  AppService(
    id: 'symptoms',
    emoji: '🤒',
    name: 'Symptom Tracker',
    tagline: 'Log symptoms, spot patterns',
    category: ServiceCategory.health,
    keywords: <String>['symptom', 'sick', 'pain', 'headache', 'illness'],
    features: <String>[
      'Body-area symptom log with severity',
      'Timeline to show your doctor',
      'Pattern hints (time of day, weather)',
    ],
  ),
  AppService(
    id: 'medication',
    emoji: '💊',
    name: 'Medication Reminder',
    tagline: 'Never miss a dose',
    category: ServiceCategory.health,
    keywords: <String>['medicine', 'medication', 'pill', 'dose', 'tablet'],
    features: <String>[
      'Med list with dose & schedule',
      'Exact-time notifications',
      'Taken / skipped history',
    ],
  ),
  AppService(
    id: 'nicotine',
    emoji: '🚭',
    name: 'Nicotine Tracker',
    tagline: 'Cravings, streaks, money saved',
    category: ServiceCategory.health,
    keywords: <String>['nicotine', 'smoking', 'cigarette', 'quit', 'vape'],
    features: <String>[
      'Smoke-free streak counter',
      'Craving log with triggers',
      'Money & health milestones',
    ],
  ),
  AppService(
    id: 'air_quality',
    emoji: '🌫️',
    name: 'Air Quality',
    tagline: 'AQI at your location, hourly',
    category: ServiceCategory.health,
    keywords: <String>['air', 'aqi', 'pollution', 'pm2.5', 'smog'],
    features: <String>[
      'Live AQI from your weather location',
      'PM2.5 / PM10 / ozone breakdown',
      '"Okay to run outside?" verdict',
    ],
  ),
  AppService(
    id: 'emergency',
    emoji: '🆘',
    name: 'Emergency Info',
    tagline: 'Blood group, allergies, contacts',
    category: ServiceCategory.health,
    keywords: <String>['emergency', 'ice', 'blood', 'allergy', 'contact'],
    features: <String>[
      'Medical ID card (blood group, allergies)',
      'Emergency contacts, one-tap call',
      'Local emergency numbers',
    ],
  ),

  // ── WOMEN ─────────────────────────────────────────────────────────────
  AppService(
    id: 'period',
    emoji: '🌸',
    name: "Women's Health",
    tagline: 'Period & ovulation tracker',
    category: ServiceCategory.women,
    keywords: <String>['period', 'cycle', 'ovulation', 'menstrual', 'pms'],
    features: <String>[
      'Cycle calendar with predictions',
      'Fertile window & ovulation estimate',
      'Symptom + flow logging',
    ],
  ),
  AppService(
    id: 'pregnancy',
    emoji: '🤰',
    name: 'Pregnancy Tracker',
    tagline: 'Week-by-week journey',
    category: ServiceCategory.women,
    keywords: <String>['pregnancy', 'pregnant', 'baby', 'trimester', 'due'],
    features: <String>[
      'Due-date countdown & week number',
      'Weekly baby-size milestones',
      'Appointment & kick log',
    ],
  ),

  // ── MIND ──────────────────────────────────────────────────────────────
  AppService(
    id: 'mood',
    emoji: '🙂',
    name: 'Mood Tracker',
    tagline: 'One tap a day, trends over time',
    category: ServiceCategory.mind,
    keywords: <String>['mood', 'feeling', 'emotion', 'happy', 'sad'],
    features: <String>[
      '5-point daily mood check-in',
      'Month heat-map',
      'Mood vs sleep/energy overlay',
    ],
  ),
  AppService(
    id: 'journal',
    emoji: '📓',
    name: 'Journal',
    tagline: 'Private daily writing',
    category: ServiceCategory.mind,
    keywords: <String>['journal', 'diary', 'write', 'gratitude'],
    features: <String>[
      'Dated entries with prompts',
      'Gratitude quick-add',
      'On-device only, searchable',
    ],
  ),
  AppService(
    id: 'meditation',
    emoji: '🧘',
    name: 'Meditation',
    tagline: 'Guided & unguided timers',
    category: ServiceCategory.mind,
    keywords: <String>['meditation', 'calm', 'mindfulness', 'zen'],
    features: <String>[
      'Timer with interval bells',
      'Guided audio sessions',
      'Streak & minutes stats',
    ],
  ),
  AppService(
    id: 'breathing',
    emoji: '🌬️',
    name: 'Breathing Exercises',
    tagline: 'Box, 4-7-8, calm-down',
    category: ServiceCategory.mind,
    keywords: <String>['breathing', 'breath', 'box', '478', 'anxiety'],
    features: <String>[
      'Animated breathe-along circle',
      'Box / 4-7-8 / custom patterns',
      'One-minute panic reset',
    ],
  ),
  AppService(
    id: 'mental_health',
    emoji: '🫶',
    name: 'Mental Health',
    tagline: 'Check-ins & coping toolkit',
    category: ServiceCategory.mind,
    keywords: <String>['mental', 'anxiety', 'stress', 'therapy', 'help'],
    features: <String>[
      'Weekly wellbeing check-in',
      'Coping technique library',
      'Helpline shortcuts',
    ],
  ),
  AppService(
    id: 'sleep_sounds',
    emoji: '🎵',
    name: 'Sleep Sounds',
    tagline: 'Rain, waves, white noise',
    category: ServiceCategory.mind,
    keywords: <String>['sleep', 'sounds', 'rain', 'noise', 'relax'],
    features: <String>[
      'Looping ambient soundscapes',
      'Sleep timer with fade-out',
      'Mix your own blend',
    ],
  ),

  // ── FOOD ──────────────────────────────────────────────────────────────
  AppService(
    id: 'calorie_calc',
    emoji: '🔢',
    name: 'Calorie Calculator',
    tagline: 'Your daily target (TDEE)',
    category: ServiceCategory.food,
    keywords: <String>['calorie', 'tdee', 'bmr', 'deficit', 'target'],
    features: <String>[
      'BMR + activity level → daily target',
      'Cut / maintain / bulk presets',
      'Macro split suggestion',
    ],
  ),
  AppService(
    id: 'calorie_counter',
    emoji: '🍽️',
    name: 'Calorie Counter',
    tagline: 'Log what you eat',
    category: ServiceCategory.food,
    keywords: <String>['calorie', 'food', 'log', 'eat', 'diet'],
    features: <String>[
      'Meal-by-meal calorie log',
      'Daily budget bar',
      'Frequent-foods quick add',
    ],
  ),
  AppService(
    id: 'food_db',
    emoji: '🔍',
    name: 'Food Calorie Check',
    tagline: 'Look up any food',
    category: ServiceCategory.food,
    keywords: <String>['food', 'database', 'nutrition', 'lookup', 'barcode'],
    features: <String>[
      'Search a foods database',
      'Per-100 g and per-serving values',
      'Barcode scan (later)',
    ],
  ),
  AppService(
    id: 'nutrition',
    emoji: '🥦',
    name: 'Nutrition Tracker',
    tagline: 'Protein, carbs, fat, fiber',
    category: ServiceCategory.food,
    keywords: <String>['nutrition', 'macro', 'protein', 'carbs', 'fat'],
    features: <String>[
      'Macro rings per day',
      'Micronutrient watch-list',
      'Weekly balance report',
    ],
  ),
  AppService(
    id: 'meal_planner',
    emoji: '📋',
    name: 'Meal Planner',
    tagline: 'Plan the week, shop once',
    category: ServiceCategory.food,
    keywords: <String>['meal', 'plan', 'week', 'menu', 'grocery'],
    features: <String>[
      'Drag meals onto a week grid',
      'Auto grocery list',
      'Uses your recipe box',
    ],
  ),
  AppService(
    id: 'recipes',
    emoji: '🍳',
    name: 'Recipe Manager',
    tagline: 'Your recipe box',
    category: ServiceCategory.food,
    keywords: <String>['recipe', 'cook', 'ingredients', 'dish'],
    features: <String>[
      'Save recipes with photos',
      'Ingredient scaling',
      'Send to meal planner',
    ],
  ),
  AppService(
    id: 'fasting',
    emoji: '⏳',
    name: 'Fasting Tracker',
    tagline: '16:8 and friends',
    category: ServiceCategory.food,
    keywords: <String>['fasting', 'intermittent', '168', 'eat window'],
    features: <String>[
      'Live fasting timer with stages',
      '16:8 / 18:6 / custom windows',
      'Streaks and history',
    ],
  ),

  // ── MONEY ─────────────────────────────────────────────────────────────
  AppService(
    id: 'expenses',
    emoji: '🧾',
    name: 'Expense Tracker',
    tagline: 'Where the money went',
    category: ServiceCategory.finance,
    keywords: <String>['expense', 'spend', 'money', 'transaction'],
    features: <String>[
      'Fast expense entry with categories',
      'Month summary & category pie',
      'Export to CSV',
    ],
  ),
  AppService(
    id: 'budget',
    emoji: '🎯',
    name: 'Budget Planner',
    tagline: 'Plan the month ahead',
    category: ServiceCategory.finance,
    keywords: <String>['budget', 'plan', 'saving', 'limit'],
    features: <String>[
      'Category budgets with progress bars',
      'Safe-to-spend today number',
      'Rollover rules',
    ],
  ),
  AppService(
    id: 'subscriptions',
    emoji: '🔁',
    name: 'Subscription Tracker',
    tagline: 'All your recurring charges',
    category: ServiceCategory.finance,
    keywords: <String>['subscription', 'netflix', 'recurring', 'renewal'],
    features: <String>[
      'Subscription list with renewal dates',
      'Monthly total & yearly projection',
      'Renewal-soon alerts',
    ],
  ),
  AppService(
    id: 'bills',
    emoji: '📅',
    name: 'Bill Reminders',
    tagline: 'Due dates, never late',
    category: ServiceCategory.finance,
    keywords: <String>['bill', 'due', 'rent', 'electricity', 'pay'],
    features: <String>[
      'Bill calendar with amounts',
      'Remind N days before due',
      'Paid / unpaid tick-off',
    ],
  ),

  // ── PLAN ──────────────────────────────────────────────────────────────
  AppService(
    id: 'todo',
    emoji: '✅',
    name: 'To-Do List',
    tagline: 'Simple, fast tasks',
    category: ServiceCategory.productivity,
    keywords: <String>['todo', 'task', 'list', 'check'],
    features: <String>[
      'Tasks with due dates & priority',
      'Today / upcoming views',
      'Swipe to complete',
    ],
  ),
  AppService(
    id: 'daily_planner',
    emoji: '🗓️',
    name: 'Daily Planner',
    tagline: 'Time-block your day',
    category: ServiceCategory.productivity,
    keywords: <String>['planner', 'schedule', 'time block', 'agenda'],
    features: <String>[
      'Hour-by-hour blocks',
      'Pulls tasks from To-Do',
      'Links to your energy planner',
    ],
  ),
  AppService(
    id: 'reminders',
    emoji: '⏰',
    name: 'Reminders',
    tagline: 'Anything, any time',
    category: ServiceCategory.productivity,
    keywords: <String>['reminder', 'alert', 'notify', 'alarm'],
    features: <String>[
      'One-off & repeating reminders',
      'Exact-time notifications',
      'Snooze support',
    ],
  ),
  AppService(
    id: 'notes',
    emoji: '📝',
    name: 'Notes',
    tagline: 'Quick capture, searchable',
    category: ServiceCategory.productivity,
    keywords: <String>['note', 'memo', 'text', 'idea'],
    features: <String>[
      'Instant note capture',
      'Pin & color labels',
      'Full-text search',
    ],
  ),
  AppService(
    id: 'focus',
    emoji: '🎯',
    name: 'Focus & Reading',
    tagline: 'Pomodoro + reading log',
    category: ServiceCategory.productivity,
    keywords: <String>['focus', 'pomodoro', 'reading', 'book', 'study'],
    features: <String>[
      'Pomodoro timer with breaks',
      'Reading sessions per book',
      'Focus minutes per day chart',
    ],
  ),

  // ── TRACK ─────────────────────────────────────────────────────────────
  AppService(
    id: 'habits',
    emoji: '🔥',
    name: 'Habit Tracker',
    tagline: 'Streaks that stick',
    category: ServiceCategory.lifestyle,
    keywords: <String>['habit', 'streak', 'daily', 'routine'],
    features: <String>[
      'Daily habit grid',
      'Streaks & completion rate',
      'Best time-of-day hints',
    ],
  ),
  AppService(
    id: 'hobby',
    emoji: '🎨',
    name: 'Hobby Tracker',
    tagline: 'Time on what you love',
    category: ServiceCategory.lifestyle,
    keywords: <String>['hobby', 'guitar', 'paint', 'craft', 'practice'],
    features: <String>[
      'Log sessions per hobby',
      'Weekly time split',
      'Milestone notes & photos',
    ],
  ),
  AppService(
    id: 'screen_time',
    emoji: '📱',
    name: 'Screen Time',
    tagline: 'Phone usage insight',
    category: ServiceCategory.lifestyle,
    keywords: <String>['screen', 'usage', 'phone', 'digital', 'detox'],
    features: <String>[
      'Daily screen-time total',
      'Top apps breakdown',
      'Down-time goals',
    ],
  ),
  AppService(
    id: 'holidays',
    emoji: '🎉',
    name: 'Holiday Calendar',
    tagline: 'Only the days off',
    category: ServiceCategory.lifestyle,
    keywords: <String>['holiday', 'calendar', 'festival', 'long weekend'],
    features: <String>[
      'Public holidays for your country',
      'Long-weekend spotter',
      'Countdown to the next one',
    ],
  ),
];

/// Tile accent per category — keeps the grid colorful but consistent.
Color categoryTint(ServiceCategory c) => switch (c) {
      ServiceCategory.health => const Color(0xFFE8F5E9),
      ServiceCategory.women => const Color(0xFFFCE4EC),
      ServiceCategory.mind => const Color(0xFFEDE7F6),
      ServiceCategory.food => const Color(0xFFFFF3E0),
      ServiceCategory.finance => const Color(0xFFE3F2FD),
      ServiceCategory.productivity => const Color(0xFFE0F2F1),
      ServiceCategory.lifestyle => const Color(0xFFFFF8E1),
    };

Color categoryAccent(ServiceCategory c) => switch (c) {
      ServiceCategory.health => const Color(0xFF2E7D32),
      ServiceCategory.women => const Color(0xFFC2185B),
      ServiceCategory.mind => const Color(0xFF5E35B1),
      ServiceCategory.food => const Color(0xFFEF6C00),
      ServiceCategory.finance => const Color(0xFF1565C0),
      ServiceCategory.productivity => const Color(0xFF00695C),
      ServiceCategory.lifestyle => const Color(0xFFF9A825),
    };
