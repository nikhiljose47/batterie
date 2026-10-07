import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../config/routes/app_routes.dart';
import '../../constants/app_colors.dart';
import '../../pages/home_tab/data/mode_advice.dart';
import '../../pages/profile/profile_store.dart';
import '../../pages/services/tools/toolkit.dart';
import '../../services/google_calendar_service.dart';
import '../../services/sleep_schedule_store.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _bodyFormKey = GlobalKey<FormState>();
  String _modeId = 'student';
  TimeOfDay _wakeTime = SleepScheduleStore.instance.wakeTime.value;
  int _pageIndex = 0;
  bool _connectCalendar = false;
  bool _saving = false;
  bool _showOutro = false;

  static const String _bodyMetricsKey = 'svc.body.metrics';

  static const List<_FriendlyMode> _friendlyModes = <_FriendlyMode>[
    _FriendlyMode(
      id: 'student',
      title: 'I need to Prepare for Exam',
      icon: Icons.school_rounded,
      color: Color(0xFF6A1B9A),
    ),
    _FriendlyMode(
      id: 'office',
      title: 'I need to Focus More Time today',
      icon: Icons.center_focus_strong_rounded,
      color: Color(0xFF1565C0),
    ),
    _FriendlyMode(
      id: 'gym',
      title: 'Track and get me muscles',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFE65100),
    ),
    _FriendlyMode(
      id: 'nicotine_free',
      title: 'Reduce my Nicotine / Cigarettes',
      icon: Icons.smoke_free_rounded,
      color: Color(0xFF2F855A),
    ),
    _FriendlyMode(
      id: 'language',
      title: 'Learn a new Language',
      icon: Icons.translate_rounded,
      color: Color(0xFF4F46E5),
    ),
    _FriendlyMode(
      id: 'healthy',
      title: 'Stay Balanced and Move More',
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
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_pageIndex == 0 && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_pageIndex == 1 && !(_bodyFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_pageIndex >= 2) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _goBack() {
    if (_pageIndex == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    if (_saving || name.isEmpty || age == null || age < 10 || age > 120) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (!_hasValidBodyMetrics()) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() => _saving = true);

    try {
      if (_connectCalendar) {
        await GoogleCalendarService.instance.signIn();
      }
      await ProfileStore.instance.completeOnboarding(
        displayName: name,
        userAge: age,
        modeId: _modeId,
      );
      await SleepScheduleStore.instance.setWake(_wakeTime);
      await _saveBodyMetrics();
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

  bool _hasValidBodyMetrics() {
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    return height != null &&
        height >= 120 &&
        height <= 230 &&
        weight != null &&
        weight >= 30 &&
        weight <= 220;
  }

  Future<void> _saveBodyMetrics() async {
    final height = double.parse(_heightController.text.trim());
    final weight = double.parse(_weightController.text.trim());
    final existing = await ServiceStore.loadMap(_bodyMetricsKey);
    await ServiceStore.saveMap(_bodyMetricsKey, <String, dynamic>{
      ...existing,
      'heightCm': height,
      'weightKg': weight,
    });
  }

  Widget _buildInlineNav(int pageIndex) {
    return Column(
      children: <Widget>[
        _IntroDots(index: pageIndex, count: 3),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            if (pageIndex > 0)
              TextButton(
                onPressed: _saving ? null : _goBack,
                child: const Text('Back'),
              )
            else
              const SizedBox(width: 64),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : _goNext,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        pageIndex == 2
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(
                  _saving
                      ? 'Setting up'
                      : pageIndex == 2
                          ? 'Start my day'
                          : 'Next',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.scaffoldBackground,
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
                    child: PageView(
                      controller: _pageController,
                      physics: _saving
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      onPageChanged: (index) =>
                          setState(() => _pageIndex = index),
                      children: <Widget>[
                        _IntroProfilePage(
                          formKey: _formKey,
                          nameController: _nameController,
                          ageController: _ageController,
                          wakeTime: _wakeTime,
                          onWakeTimeChanged: (time) =>
                              setState(() => _wakeTime = time),
                          navigation: _buildInlineNav(0),
                        ),
                        _IntroBodyPage(
                          formKey: _bodyFormKey,
                          heightController: _heightController,
                          weightController: _weightController,
                          navigation: _buildInlineNav(1),
                        ),
                        _IntroGoalPage(
                          modes: _friendlyModes,
                          modeId: _modeId,
                          connectCalendar: _connectCalendar,
                          saving: _saving,
                          navigation: _buildInlineNav(2),
                          onModeChanged: (modeId) =>
                              setState(() => _modeId = modeId),
                          onCalendarChanged: (value) => setState(
                            () => _connectCalendar = value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _IntroProfilePage extends StatelessWidget {
  const _IntroProfilePage({
    required this.formKey,
    required this.nameController,
    required this.ageController,
    required this.wakeTime,
    required this.onWakeTimeChanged,
    required this.navigation,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TimeOfDay wakeTime;
  final ValueChanged<TimeOfDay> onWakeTimeChanged;
  final Widget navigation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 22),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _OnboardingHeader(),
            const SizedBox(height: 24),
            _SetupCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Let\'s start with you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 26,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _IntroQuestionField(
                    question: 'What\'s your name?',
                    child: TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Enter your name',
                        prefixIcon: Icon(Icons.person_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Enter your name';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _IntroQuestionField(
                    question: 'How old are you?',
                    child: TextFormField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Enter your age',
                        prefixIcon: Icon(Icons.cake_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final age = int.tryParse(value?.trim() ?? '');
                        if (age == null) return 'Enter your age';
                        if (age < 10 || age > 120) {
                          return 'Use an age from 10 to 120';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _IntroQuestionField(
                    question: 'What time do you usually wake up?',
                    child: _IntroWakeTimePicker(
                      time: wakeTime,
                      onChanged: onWakeTimeChanged,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            navigation,
          ],
        ),
      ),
    );
  }
}

class _IntroBodyPage extends StatelessWidget {
  const _IntroBodyPage({
    required this.formKey,
    required this.heightController,
    required this.weightController,
    required this.navigation,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final Widget navigation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 22),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Your body details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 30,
                height: 1.08,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            _SetupCard(
              child: Column(
                children: <Widget>[
                  _IntroQuestionField(
                    question: 'How tall are you?',
                    child: TextFormField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Height in cm',
                        prefixIcon: Icon(Icons.height_rounded),
                        suffixText: 'cm',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final height = double.tryParse(value?.trim() ?? '');
                        if (height == null) return 'Enter your height';
                        if (height < 120 || height > 230) {
                          return 'Use a height from 120 to 230 cm';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _IntroQuestionField(
                    question: 'What\'s your weight?',
                    child: TextFormField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Weight in kg',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                        suffixText: 'kg',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final weight = double.tryParse(value?.trim() ?? '');
                        if (weight == null) return 'Enter your weight';
                        if (weight < 30 || weight > 220) {
                          return 'Use a weight from 30 to 220 kg';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            navigation,
          ],
        ),
      ),
    );
  }
}

class _IntroGoalPage extends StatelessWidget {
  const _IntroGoalPage({
    required this.modes,
    required this.modeId,
    required this.connectCalendar,
    required this.saving,
    required this.navigation,
    required this.onModeChanged,
    required this.onCalendarChanged,
  });

  final List<_FriendlyMode> modes;
  final String modeId;
  final bool connectCalendar;
  final bool saving;
  final Widget navigation;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<bool> onCalendarChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'What\'s your target?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 31,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us understand your needs better',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface.withOpacity(0.62),
              fontSize: 15,
              height: 1.28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          _CustomPlanNote(colors: colors),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 128,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: modes.length,
            itemBuilder: (context, index) {
              final mode = modes[index];
              return _ModeChoiceTile(
                mode: mode,
                selected: modeId == mode.id,
                onTap: () => onModeChanged(mode.id),
              );
            },
          ),
          const SizedBox(height: 18),
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: saving ? null : () => onCalendarChanged(!connectCalendar),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: connectCalendar
                        ? AppColors.primary.withOpacity(0.65)
                        : AppColors.outline.withOpacity(0.7),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.login_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Want your calendar here too?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: connectCalendar,
                      onChanged: saving ? null : onCalendarChanged,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          navigation,
        ],
      ),
    );
  }
}

class _IntroWakeTimePicker extends StatelessWidget {
  const _IntroWakeTimePicker({
    required this.time,
    required this.onChanged,
  });

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (picked != null) onChanged(picked);
        },
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.wb_twilight_rounded),
            border: OutlineInputBorder(),
          ),
          child: Text(
            time.format(context),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroQuestionField extends StatelessWidget {
  const _IntroQuestionField({
    required this.question,
    required this.child,
  });

  final String question;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          question,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 15.5,
            height: 1.15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        child,
      ],
    );
  }
}

class _IntroDots extends StatelessWidget {
  const _IntroDots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (dotIndex) {
        final active = dotIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 58 : 52,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.outline,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _CustomPlanNote extends StatelessWidget {
  const _CustomPlanNote({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.18)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.edit_note_rounded,
            size: 20,
            color: AppColors.info,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'You can also create your own custom plan inside the app.',
              style: TextStyle(
                color: colors.onSurface.withOpacity(0.72),
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
        SizedBox(
          height: 132,
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
            color: AppColors.textStrong,
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w900,
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.outline.withOpacity(0.78)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 28,
            offset: const Offset(0, 14),
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
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? AppColors.primary : colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    mode.icon,
                    color: selected ? colors.onPrimary : mode.color,
                    size: 28,
                  ),
                  const Spacer(),
                  if (selected)
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.primary,
                        size: 19,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                mode.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : AppColors.textStrong,
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
  final IconData icon;
  final Color color;

  DayMode get dayMode => allDayModes.firstWhere((mode) => mode.id == id);
}
