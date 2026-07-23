# Supabase Integration Plan — "Updates" Tab (Friends & Shared Status)

> **Purpose of this doc:** a step-by-step, copy-paste plan to turn the **Updates**
> tab into a real friends-status page — like WhatsApp's *Updates* / Status and
> health-app social feeds (Strava, Whoop, Apple Fitness sharing) — backed by
> Supabase. Written so a coding model (or you) can execute it top-to-bottom.
>
> **You can freely edit this file.** It's yours. Sections are numbered and
> self-contained so you can change one part (e.g. add a column, tweak the layout)
> without breaking the rest. Places you're most likely to customise are marked
> with 🎨 (design) and 🗄️ (data) tags.

---

## 0. What we are building

Today the Updates tab shows 3 **hard-coded** fake people (`Aarav`, `Mira`, `Dev`)
from `lib/services/energy_health_service.dart`, plus your own stats panel.

We replace this with a real, app-like friends feed:

1. Real people live in a Supabase table called **`friends`**.
2. Each friend has: **name, photo, role, a status (emoji + text), physical &
   brain energy, current activity, daily progress, and when they last updated.**
3. **You** are one row in that table (flagged `is_me = true`), shown as a
   prominent **"My Status"** card at the top — like WhatsApp's "My status".
4. Friends appear as a **vertical feed, newest first**, each card showing their
   status and a **relative timestamp** ("2h ago") — the signal every real
   status/feed app has.
5. You **add / edit people by hand** in the Supabase dashboard (no in-app admin
   screen needed for v1).

**Two phases:**

- **Phase 1 (do first): READ ONLY.** App reads friends from Supabase and shows
  the feed. You add everyone (including yourself) in the dashboard.
- **Phase 2 (later): WRITE YOUR OWN.** The app pushes *your* status back to your
  row so friends see your live updates. Don't start until Phase 1 works.

---

## 1. Mental model (keep this in your head)

```
Supabase  ─►  friends table  ─►  FriendsService.fetchFriends()  ─►  List<Friend>
(cloud DB)    (one row/person)   (one class, one method)            (plain objects)
                                                                          │
                                                        OthersController (exists) reloads
                                                                          │
                                                                          ▼
                                        UPDATES TAB — three stacked, app-like sections:
                                        ┌──────────────────────────────────────────┐
                                        │  [My Status]  ← your row, big, "tap to     │
                                        │               update" (live in Phase 2)   │
                                        ├──────────────────────────────────────────┤
                                        │  RECENT  ○ ○ ○ ○  ← quick-glance avatars   │
                                        │          (ring = updated recently)         │
                                        ├──────────────────────────────────────────┤
                                        │  FEED (newest first, scrolls):             │
                                        │   ┌────────────────────────────────────┐  │
                                        │   │ 📷 Aarav · Training partner   2h ago │  │
                                        │   │ 💪 High readiness                    │  │
                                        │   │ Body ▓▓▓▓░ 81   Brain ▓▓▓░ 64        │  │
                                        │   │ Gym · 55% of today's goal            │  │
                                        │   └────────────────────────────────────┘  │
                                        │   ┌ Mira · Family · 5h ago … ┐             │
                                        └──────────────────────────────────────────┘
```

**One table. One model class. One read method.** That's the whole data layer.
We do NOT touch the energy-log / SQLite code, the planner, or `remote_sync.dart`.

---

# PHASE 1 — Read friends & build the feed

## 1.1 Create the Supabase project

1. <https://supabase.com> → sign in → **New project**.
2. Name it, set a DB password (save it), wait ~2 min for provisioning.
3. **Project Settings → API**, copy two values for later:
   - **Project URL** — `https://abcdxyz.supabase.co`
   - **anon public** key — long JWT starting `eyJ...`

> ⚠️ **Only the `anon` key ever goes in the app.** Never the `service_role` key —
> it bypasses all security and stays dashboard-only.

## 1.2 Create the `friends` table 🗄️

**SQL Editor → New query**, paste, **Run**:

```sql
create table if not exists friends (
  id            uuid primary key default gen_random_uuid(),
  name          text        not null,
  photo_url     text,                     -- public image URL, or null
  role          text        default '',   -- 'Training partner', 'Family', ...
  status_emoji  text        default '',   -- '💪', '😴', '🧠'
  status_text   text        default '',   -- 'Crushing leg day'
  physical      int         not null default 50,   -- 0..100
  brain         int         not null default 50,   -- 0..100
  activity      text        default '',   -- what they're doing now
  progress      int         not null default 0,    -- 0..100 daily goal
  is_me         boolean     not null default false, -- exactly ONE row = you
  updated_at    timestamptz not null default now()  -- drives "2h ago"
);
```

🗄️ **To add your own fields** (e.g. `mood`, `steps`, `city`): add a column here,
add the matching field in the `Friend` model (§1.9), and show it in the card
(§1.12). That's the full path for any new piece of info.

## 1.3 Security — public read rule

No login yet, so anyone with the anon key may **read**, but the app **cannot
write** (you edit via the dashboard):

```sql
alter table friends enable row level security;

create policy "public read friends"
  on friends for select using (true);
-- No insert/update/delete policy = app can't write. Good for Phase 1.
```

> 🔒 **Privacy reality check:** anyone with your anon key can read every friend's
> status. Fine for a personal app with non-sensitive "energy" data. NOT fine for
> real strangers' private data — that needs Auth + per-user RLS (see Phase 2).

## 1.4 Add people manually (your "admin panel")

**Option A — SQL:**

```sql
insert into friends (name, role, status_emoji, status_text, physical, brain, activity, progress, is_me)
values
  ('You',   'Me',              '⚡', 'Feeling good',              72, 68, 'Deep work', 40, true),
  ('Aarav', 'Training partner','💪', 'High readiness',            81, 64, 'Gym',       55, false),
  ('Mira',  'Family',          '😴', 'Low sleep, taking it easy', 49, 52, 'Resting',   20, false),
  ('Dev',   'Team member',     '🧠', 'Good focus window',         67, 75, 'Coding',    80, false);
```

**Option B — GUI:** **Table Editor → `friends` → Insert row**, fill fields, Save.

To update someone later, edit their row and set `updated_at` to `now()` so the
"time ago" refreshes.

## 1.5 Add photos

`photo_url` is a **public URL**.
- **Easiest:** paste any public image URL.
- **Proper (Supabase Storage):** Storage → New bucket `avatars` (mark **Public**)
  → upload → open file → **Copy URL** → paste into `photo_url`.
- Leave it null → the app shows the first letter of the name.

---

## 1.6 Flutter — add the package

`pubspec.yaml` under `dependencies:`:

```yaml
  supabase_flutter: ^2.5.6
```

```bash
fvm flutter pub get
```

> If pub get fails on the Dart 3.4.3 SDK constraint, drop the minor (`^2.5.0`,
> then lower) until it resolves. Don't go to 3.x.

## 1.7 Flutter — keys in `.env`

Add to the project-root **`.env`** (same file `dotenv.load()` already reads):

```
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_ANON_KEY=eyJ...your-anon-key...
```

Confirm `.env` is in `.gitignore`, and bundled the same way the existing
OpenRouter key is (check `pubspec.yaml` `flutter: assets:`).

## 1.8 Flutter — init Supabase in `lib/main.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';   // NEW

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await dotenv.load();

  await Supabase.initialize(                                // NEW
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await ProfileStore.instance.init();
  await SleepScheduleStore.instance.init();
  runApp(const EnergyHealthApp());
}
```

## 1.9 Flutter — the `Friend` model + `timeAgo`

Create **`lib/models/friend.dart`**. One flat class mirroring the table, plus a
tiny relative-time helper the feed uses:

```dart
/// One person shown in the Updates tab. Maps 1:1 to a `friends` row.
class Friend {
  const Friend({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.role,
    required this.statusEmoji,
    required this.statusText,
    required this.physical,
    required this.brain,
    required this.activity,
    required this.progress,
    required this.isMe,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final String role;
  final String statusEmoji;
  final String statusText;
  final int physical; // 0..100
  final int brain;    // 0..100
  final String activity;
  final int progress; // 0..100
  final bool isMe;
  final DateTime updatedAt;

  double get physicalPercent => (physical / 100).clamp(0.0, 1.0);
  double get brainPercent => (brain / 100).clamp(0.0, 1.0);

  /// True if updated within the last 6 hours → show a "fresh" ring.
  bool get isFresh => DateTime.now().difference(updatedAt).inHours < 6;

  factory Friend.fromMap(Map<String, dynamic> m) {
    return Friend(
      id: m['id'] as String,
      name: (m['name'] ?? '') as String,
      photoUrl: m['photo_url'] as String?,
      role: (m['role'] ?? '') as String,
      statusEmoji: (m['status_emoji'] ?? '') as String,
      statusText: (m['status_text'] ?? '') as String,
      physical: (m['physical'] ?? 0) as int,
      brain: (m['brain'] ?? 0) as int,
      activity: (m['activity'] ?? '') as String,
      progress: (m['progress'] ?? 0) as int,
      isMe: (m['is_me'] ?? false) as bool,
      updatedAt: DateTime.tryParse((m['updated_at'] ?? '') as String) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// "just now" / "12m ago" / "2h ago" / "3d ago" / "2w ago".
String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${d.inDays ~/ 7}w ago';
}
```

## 1.10 Flutter — the `FriendsService`

Create **`lib/services/friends_service.dart`**. One read method:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend.dart';

/// Reads people from the Supabase `friends` table for the Updates tab.
class FriendsService {
  const FriendsService();

  SupabaseClient get _db => Supabase.instance.client;

  /// All friends, most recently updated first.
  Future<List<Friend>> fetchFriends() async {
    final rows = await _db
        .from('friends')
        .select()
        .order('updated_at', ascending: false);

    return (rows as List)
        .map((r) => Friend.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
```

## 1.11 Flutter — feed the controller

The Updates tab is `lib/pages/others/`. Swap its data source.

**`lib/pages/others/others_state.dart`** — change the list to `List<Friend>`
(keep the field name `people` or rename to `friends`), import `friend.dart`.

**`lib/pages/others/others_controller.dart`**:

```dart
import 'package:flutter/foundation.dart';

import '../../constants/app_strings.dart';
import '../../models/friend.dart';
import '../../services/friends_service.dart';
import '../../state/async_view_state.dart';
import 'others_state.dart';

class OthersController extends ChangeNotifier {
  OthersController({this.service = const FriendsService()});

  final FriendsService service;

  OthersState _state = const OthersState();
  OthersState get state => _state;

  Future<void> load() async {
    _state = _state.copyWith(status: AsyncStatus.loading);
    notifyListeners();
    try {
      final friends = await service.fetchFriends();
      _state = _state.copyWith(
        status: friends.isEmpty ? AsyncStatus.empty : AsyncStatus.success,
        people: friends,
      );
    } catch (_) {
      _state = _state.copyWith(
        status: AsyncStatus.error,
        errorMessage: AppStrings.genericError,
      );
    }
    notifyListeners();
  }
}
```

---

## 1.12 Flutter — the app-like layout 🎨 (the part that makes it feel real)

Rebuild `lib/pages/others/others_page.dart`'s `success` branch to stack three
sections in one scroll view. Split "me" from friends first:

```dart
final me = state.people.where((f) => f.isMe).firstOrNull;      // your row
final friends = state.people.where((f) => !f.isMe).toList();   // everyone else

return ListView(
  padding: const EdgeInsets.only(bottom: AppSpacing.xLarge),
  children: <Widget>[
    if (me != null) MyStatusCard(me: me),          // §A
    _sectionHeader('RECENT'),
    SizedBox(height: 100, child: RecentRail(friends: friends)), // §B (optional)
    _sectionHeader('UPDATES'),
    for (final f in friends) FriendUpdateCard(friend: f),        // §C
  ],
);
```

> 🎨 **Simplest app-like version:** if the horizontal rail feels redundant with
> the feed, drop §B entirely and keep just **My Status + the vertical feed** —
> that alone is exactly the Strava/Whoop pattern. The rail is quick-glance polish
> à la WhatsApp; keep it only if you like the double view.

### §A — `MyStatusCard` (WhatsApp "My status" style)
New widget `lib/pages/others/widgets/my_status_card.dart`. A prominent card:
big avatar (photo/letter), "Your status", `me.statusEmoji + me.statusText`, two
energy rings/bars, and a "Tap to update" hint. In Phase 1 the tap can open a
"coming soon" note or your existing `DailyStatsPanel`; in Phase 2 it opens an
editor that writes back (§Phase 2). Use `AppColors.primary` tint so it stands
apart from friend cards.

### §B — `RecentRail` (optional quick-glance)
This is your existing `PersonStatusRail`, restricted to `friends` (not you), with
two upgrades:
- **Fresh ring:** colour the `CircularProgressIndicator`/border with
  `AppColors.primary` when `friend.isFresh`, else grey — mimics WhatsApp's
  seen/unseen ring.
- **Photo avatar:** show `NetworkImage(friend.photoUrl!)` when non-null, else the
  first letter (see snippet in §C).

### §C — `FriendUpdateCard` (the feed item — the core of the page)
New widget `lib/pages/others/widgets/friend_update_card.dart`. One per friend,
newest first. This is what makes it read like a real feed:

```dart
import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../models/friend.dart';

class FriendUpdateCard extends StatelessWidget {
  const FriendUpdateCard({super.key, required this.friend, this.onTap});

  final Friend friend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = friend.photoUrl != null && friend.photoUrl!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.large, 6, AppSpacing.large, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header: avatar · name/role · timestamp
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceTint,
                  foregroundColor: AppColors.primary,
                  backgroundImage:
                      hasPhoto ? NetworkImage(friend.photoUrl!) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          friend.name.isEmpty ? '?' : friend.name[0],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(friend.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      if (friend.role.isNotEmpty)
                        Text(friend.role,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Text(timeAgo(friend.updatedAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 10),
            // Status line: emoji + text (the "post")
            if (friend.statusText.isNotEmpty)
              Text('${friend.statusEmoji} ${friend.statusText}'.trim(),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            // Energy bars
            _bar('Body', friend.physicalPercent, AppColors.bodyEnergy),
            const SizedBox(height: 6),
            _bar('Brain', friend.brainPercent, AppColors.brainEnergy),
            // Footer: activity · progress
            if (friend.activity.isNotEmpty || friend.progress > 0) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                [
                  if (friend.activity.isNotEmpty) friend.activity,
                  if (friend.progress > 0)
                    '${friend.progress}% of today’s goal',
                ].join('  ·  '),
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(String label, double value, Color color) => Row(
        children: <Widget>[
          SizedBox(width: 42, child: Text(label, style: const TextStyle(fontSize: 11))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: color,
                backgroundColor: AppColors.outline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(value * 100).round()}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      );
}
```

Tapping a card can still open the existing detail sheet (`PersonStatusCard`,
updated to take a `Friend`) if you want a bigger view.

### §D — old widgets
- `person_status_rail.dart` / `person_status_card.dart`: either upgrade to take
  `Friend` (for §B and the detail sheet) or delete if you drop the rail.
- Your own detailed stats (`DailyStatsPanel`) can move behind the **My Status**
  card's tap, or stay as a section — your call. 🎨

### §E — empty / where's `firstOrNull`
`firstOrNull` needs `import 'package:collection/collection.dart';` (already a
transitive dep) or replace with `state.people.where((f) => f.isMe).isEmpty ? null : ...`.

## 1.13 Clean up the dead mock (optional)
Remove `fetchPeopleStatuses()` (`energy_health_service.dart`) and
`getPeopleStatuses()` (`energy_health_repository.dart`); delete
`lib/models/person_status.dart` once unused. `fvm flutter analyze` finds strays.

## 1.14 Verify Phase 1

```bash
fvm flutter analyze     # no issues
fvm flutter run
```

- [ ] No fake Aarav/Mira/Dev unless you inserted them.
- [ ] **My Status** card shows your `is_me` row at top.
- [ ] Friends appear as a **vertical feed, newest first**.
- [ ] Each card shows **"Xh ago"** from `updated_at`.
- [ ] Rows with `photo_url` show the photo; others show the first letter.
- [ ] Editing a row in Supabase + reopening the tab shows the change (controller
      reloads in `initState`).

Nothing loads? Check `.env` URL/key, table name is exactly `friends`, and the
"public read" RLS policy exists.

---

# PHASE 2 — Share YOUR own status (write) — later, optional

Goal: the app updates *your* row (`is_me = true`) so friends see live updates,
and the **My Status** card's "tap to update" opens an editor.

**Two decisions when you get here:**

1. **Which row is you.** Store your row's `id` in `SharedPreferences` (add
   `friends.my_id` to `ProfileStore`), or query `is_me = true` once and cache it.

2. **How writes are allowed:**
   - **Dev-only quick:** add an update policy `using (true)` — ⚠️ anyone with the
     key can edit any row. Closed test only.
   - **Proper:** add Supabase **Auth** (email magic link), a `user_id` column on
     `friends` referencing `auth.users`, and RLS so a user updates only their own
     row. The real answer for multiple real users.

**Write method for `FriendsService`:**

```dart
Future<void> updateMyStatus({
  required String myId,
  required int physical,
  required int brain,
  String? statusEmoji,
  String? statusText,
  String? activity,
  int? progress,
}) async {
  await _db.from('friends').update({
    'physical': physical,
    'brain': brain,
    if (statusEmoji != null) 'status_emoji': statusEmoji,
    if (statusText != null) 'status_text': statusText,
    if (activity != null) 'activity': activity,
    if (progress != null) 'progress': progress,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', myId);
}
```

Call it after your energy/status changes; wrap in try/catch so a network failure
never blocks local UI.

---

## 2. Security & privacy — read before shipping

- ✅ **anon key in app; service_role key NEVER in app.**
- ✅ **`.env` out of git.**
- ⚠️ **Phase 1 public-read** = anyone with the anon key reads all friends. Fine for
  a personal app; not for real strangers' private data (needs Auth + RLS).
- ⚠️ **Phase 2 open-write** lets anyone edit any row. Closed test only; real use
  needs Auth + per-row RLS.
- Public Storage bucket photos are readable by anyone with the URL.

---

## 3. File change checklist (Phase 1)

| File | Change |
|---|---|
| Supabase dashboard | Create project, `friends` table, RLS read policy, insert rows, photos |
| `.env` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
| `pubspec.yaml` | Add `supabase_flutter`; ensure `.env` bundled |
| `lib/main.dart` | `Supabase.initialize(...)` after `dotenv.load()` |
| `lib/models/friend.dart` | **NEW** — `Friend` model + `timeAgo()` |
| `lib/services/friends_service.dart` | **NEW** — `FriendsService.fetchFriends()` |
| `lib/pages/others/others_state.dart` | List type → `List<Friend>` |
| `lib/pages/others/others_controller.dart` | Use `FriendsService` |
| `lib/pages/others/others_page.dart` | 3-section layout (My Status + rail + feed) |
| `lib/pages/others/widgets/my_status_card.dart` | **NEW** — §A |
| `lib/pages/others/widgets/friend_update_card.dart` | **NEW** — §C (feed item) |
| `person_status_rail.dart` / `person_status_card.dart` | Upgrade to `Friend` or remove |
| `energy_health_service.dart` / `..._repository.dart` / `person_status.dart` | Remove dead mock (optional) |

---

## 4. Glossary

- **anon key** — public API key, safe to ship, gated by RLS.
- **service_role key** — god-mode key, dashboard only, never in the app.
- **RLS** — per-row access rules; no matching policy = query returns nothing.
- **`is_me`** — flag for the single row that is the app's own user (no login in P1).
- **`fromMap`** — turns a DB row (`Map`) into a Dart object; same style as
  `EnergyLogRecord`.
- **`timeAgo` / `isFresh`** — relative-time helpers that make the feed feel live.
