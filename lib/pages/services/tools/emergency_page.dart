import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

/// Emergency Info — a medical ID card (blood group, allergies,
/// conditions, contacts) stored on-device, plus local emergency numbers.
class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  static const String key = 'svc.emergency.info';
  static const List<String> _bloodGroups = <String>[
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  String? _blood;
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  final _meds = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  bool _loaded = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    ServiceStore.loadMap(key).then((map) {
      if (!mounted) return;
      setState(() {
        _blood = map['blood'] as String?;
        _allergies.text = map['allergies'] as String? ?? '';
        _conditions.text = map['conditions'] as String? ?? '';
        _meds.text = map['meds'] as String? ?? '';
        _contactName.text = map['contactName'] as String? ?? '';
        _contactPhone.text = map['contactPhone'] as String? ?? '';
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _allergies.dispose();
    _conditions.dispose();
    _meds.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ServiceStore.saveMap(key, <String, dynamic>{
      if (_blood != null) 'blood': _blood,
      'allergies': _allergies.text.trim(),
      'conditions': _conditions.text.trim(),
      'meds': _meds.text.trim(),
      'contactName': _contactName.text.trim(),
      'contactPhone': _contactPhone.text.trim(),
    });
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Emergency info saved on this device.'),
          duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: svcAppBar('🆘 Emergency Info'),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                // Emergency numbers (India)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            const Color(0xFFC62828).withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('EMERGENCY NUMBERS (INDIA)',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFFC62828))),
                      SizedBox(height: 6),
                      Text(
                        '🚨 112 — all emergencies\n'
                        '🚑 108 — ambulance\n'
                        '👮 100 — police  ·  🔥 101 — fire\n'
                        '🧠 14416 — mental health (Tele-MANAS)',
                        style: TextStyle(fontSize: 12, height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const SectionLabel('My medical ID'),
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Blood group',
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final bg in _bloodGroups)
                            SvcChip(
                              label: bg,
                              selected: _blood == bg,
                              onTap: () => setState(() {
                                _blood = bg;
                                _dirty = true;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _field(_allergies, 'Allergies — "penicillin, peanuts"'),
                      _field(_conditions, 'Conditions — "asthma, diabetes"'),
                      _field(_meds, 'Regular medicines'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const SectionLabel('Emergency contact'),
                WhiteCard(
                  child: Column(
                    children: <Widget>[
                      _field(_contactName, 'Name'),
                      _field(_contactPhone, 'Phone number', phone: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _dirty
                          ? const Color(0xFFC62828)
                          : AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_dirty ? 'Save changes' : 'Save',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Stored only on this phone. Tip: also add it to your '
                  'phone\'s lock-screen medical ID so responders can see '
                  'it without unlocking.',
                  style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMuted),
                ),
              ],
            ),
    );
  }

  Widget _field(TextEditingController controller, String hint,
      {bool phone = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: controller,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        onChanged: (_) {
          if (!_dirty) setState(() => _dirty = true);
        },
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted.withValues(alpha: 0.8)),
          filled: true,
          fillColor: AppColors.scaffoldBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: AppColors.outline.withValues(alpha: 0.8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}
