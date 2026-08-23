import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../config/routes/app_routes.dart';
import '../../constants/app_colors.dart';
import '../../pages/home_tab/data/mode_advice.dart';
import '../../pages/profile/profile_store.dart';
import '../../services/google_calendar_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _modeId = 'student';
  bool _connectCalendar = false;
  bool _saving = false;
  bool _showOutro = false;

  static const List<_FriendlyMode> _friendlyModes = <_FriendlyMode>[
    _FriendlyMode(
      id: 'student',
      title: 'I need to Prepare for Exam',
      subtitle: 'Study, revise, test, and recover.',
      icon: Icons.school_rounded,
      color: Color(0xFF6A1B9A),
    ),
    _FriendlyMode(
      id: 'office',
      title: 'I need to Focus More Time today',
      subtitle: 'Protect deep work and reduce drift.',
      icon: Icons.center_focus_strong_rounded,
      color: Color(0xFF1565C0),
    ),
    _FriendlyMode(
      id: 'gym',
      title: 'Track and get me muscles',
      subtitle: 'Train, eat, rest, and repeat.',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFE65100),
    ),
    _FriendlyMode(
      id: 'nicotine_free',
      title: 'Reduce my Nicotine / Cigarettes',
      subtitle: 'Track urges and build cleaner routines.',
      icon: Icons.smoke_free_rounded,
      color: Color(0xFF2F855A),
    ),
    _FriendlyMode(
      id: 'language',
      title: 'Learn a new Language',
      subtitle: 'Practice, recall, listen, and review.',
      icon: Icons.translate_rounded,
      color: Color(0xFF4F46E5),
    ),
    _FriendlyMode(
      id: 'healthy',
      title: 'Stay Balanced',
      subtitle: 'Start steady, then tune your own plan.',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF7B61FF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      if (_connectCalendar) {
        await GoogleCalendarService.instance.signIn();
      }
      await ProfileStore.instance.completeOnboarding(
        displayName: _nameController.text,
        userAge: int.parse(_ageController.text),
        modeId: _modeId,
      );
      if (!mounted) return;
      setState(() => _showOutro = true);
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Calendar sign-in failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _showOutro
              ? const _OutroView()
              : FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _introController,
                    curve: Curves.easeOut,
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _introController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const _OnboardingHeader(),
                            const SizedBox(height: 18),
                            _SetupCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Tell Batterie who is starting today.',
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _nameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                      prefixIcon: Icon(Icons.person_rounded),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      final text = value?.trim() ?? '';
                                      if (text.isEmpty) {
                                        return 'Enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _ageController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(3),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Age',
                                      prefixIcon: Icon(Icons.cake_rounded),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      final age =
                                          int.tryParse(value?.trim() ?? '');
                                      if (age == null) return 'Enter your age';
                                      if (age < 10 || age > 120) {
                                        return 'Use an age from 10 to 120';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SetupCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'What do you want to achieve?',
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisExtent: 112,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemCount: _friendlyModes.length,
                                    itemBuilder: (context, index) {
                                      final mode = _friendlyModes[index];
                                      return _ModeChoiceTile(
                                        mode: mode,
                                        selected: _modeId == mode.id,
                                        onTap: () =>
                                            setState(() => _modeId = mode.id),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SetupCard(
                              child: Material(
                                color: Colors.transparent,
                                child: SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: _connectCalendar,
                                  onChanged: _saving
                                      ? null
                                      : (value) => setState(
                                            () => _connectCalendar = value,
                                          ),
                                  secondary: const Icon(
                                    Icons.calendar_month_rounded,
                                    color: AppColors.primary,
                                  ),
                                  title: const Text(
                                    'Connect Google Calendar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Optional. This lets the day calendar show and add Google events.',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _saving ? null : _finish,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                _saving ? 'Setting up' : 'Start my day',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      setState(() => _connectCalendar = false);
                                      _finish();
                                    },
                              child: const Text('Skip calendar for now'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _AppLogoMark(),
        const SizedBox(height: 12),
        SizedBox(
          height: 112,
          child: Lottie.asset(
            'assets/lottie/panda_sleeping.json',
            repeat: true,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Welcome to Batterie',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF182033),
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'A small setup so your day card feels like yours.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AppLogoMark extends StatelessWidget {
  const _AppLogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 36,
            height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.4),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          Positioned(
            right: 11,
            child: Container(
              width: 4,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            left: 19,
            child: Container(
              width: 17,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withOpacity(0.7)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ModeChoiceTile extends StatelessWidget {
  const _ModeChoiceTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final _FriendlyMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? mode.color.withOpacity(0.1) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? mode.color : AppColors.outline.withOpacity(0.65),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(mode.icon, color: mode.color, size: 20),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: mode.color,
                      size: 18,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                mode.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.08,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202638),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mode.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutroView extends StatelessWidget {
  const _OutroView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _AppLogoMark(),
          SizedBox(height: 18),
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: 42,
          ),
          SizedBox(height: 10),
          Text(
            'Your day is ready',
            style: TextStyle(
              color: Color(0xFF182033),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendlyMode {
  const _FriendlyMode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  }) : assert(id == 'healthy' ||
            id == 'office' ||
            id == 'student' ||
            id == 'gym' ||
            id == 'nicotine_free' ||
            id == 'language');

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  DayMode get dayMode => allDayModes.firstWhere((mode) => mode.id == id);
}
