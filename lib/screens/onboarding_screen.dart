import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/health_store.dart';
import '../theme/app_theme.dart';
import '../widgets/questionnaire_widgets.dart';

/// First-launch welcome and profile. Also used to edit the profile later ([editing] = true).
class OnboardingScreen extends StatefulWidget {
  final bool editing;

  const OnboardingScreen({super.key, this.editing = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late Set<String> _concerns;
  late String _language;
  late bool _personalize;

  static const _concernOptions = <(String id, String label, IconData icon)>[
    ('pcos', 'PCOS or irregular periods', Icons.bubble_chart_outlined),
    ('cycle', 'Tracking my cycle', Icons.calendar_month_outlined),
    ('pregnancy', 'Pregnancy', Icons.child_friendly_outlined),
    ('breast', 'Breast health', Icons.favorite_border_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final p = context.read<HealthStore>().profile;
    _name = TextEditingController(text: p.name);
    _age = TextEditingController(text: p.age?.toString() ?? '');
    _height = TextEditingController(text: p.heightCm == null ? '' : formatNumber(p.heightCm!));
    _weight = TextEditingController(text: p.weightKg == null ? '' : formatNumber(p.weightKg!));
    _concerns = {...p.concerns};
    _language = p.language;
    _personalize = p.personalize;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save({bool skip = false}) async {
    final store = context.read<HealthStore>();
    if (!skip && !(_formKey.currentState?.validate() ?? false)) return;
    final profile = skip
        ? HealthProfile(language: _language, personalize: _personalize, onboarded: true)
        : HealthProfile(
            name: _name.text.trim(),
            age: int.tryParse(_age.text),
            heightCm: double.tryParse(_height.text),
            weightKg: double.tryParse(_weight.text),
            concerns: _concerns,
            language: _language,
            personalize: _personalize,
            onboarded: true,
          );
    await store.saveProfile(profile);
    if (mounted && widget.editing) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.editing
          ? AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              foregroundColor: AppColors.textDark,
              title: const Text('My profile', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              if (!widget.editing) ...[
                const SizedBox(height: 8),
                const Text('femora', style: TextStyle(fontFamily: 'Inter', fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primaryBerry, letterSpacing: -1)),
                const SizedBox(height: 6),
                const Text(
                  'Your personal women\'s health companion. Tell us a little about you so Femora can personalise what it shows and says.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14.5, color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
              ],
              QuestionSection(
                icon: Icons.person_outline_rounded,
                title: 'About you',
                subtitle: 'All optional. This stays on your phone.',
                children: [
                  TextFormField(
                    key: const Key('onboarding_name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Name (shown on your report)',
                      filled: true,
                      fillColor: AppColors.lightGrayBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: NumberField(controller: _age, label: 'Age', unit: 'years', min: 12, max: 100, integer: true, required: false)),
                      const SizedBox(width: 12),
                      Expanded(child: NumberField(controller: _height, label: 'Height', unit: 'cm', min: 120, max: 210, required: false)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  NumberField(controller: _weight, label: 'Weight', unit: 'kg', min: 25, max: 200, required: false),
                ],
              ),
              const SizedBox(height: 16),
              QuestionSection(
                icon: Icons.favorite_outline_rounded,
                title: 'What matters to you?',
                subtitle: 'Choose any that apply.',
                children: [
                  for (final (id, label, icon) in _concernOptions) ...[
                    SelectTile(
                      label: label,
                      icon: icon,
                      selected: _concerns.contains(id),
                      onTap: () => setState(() => _concerns.contains(id) ? _concerns.remove(id) : _concerns.add(id)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              QuestionSection(
                icon: Icons.translate_rounded,
                title: 'Language',
                subtitle: 'The companion also understands Urdu and Roman Urdu, whatever you choose here.',
                children: [
                  ChoiceRow(options: const ['English', 'اردو'], selectedIndex: _language == 'ur' ? 1 : 0, onSelected: (i) => setState(() => _language = i == 1 ? 'ur' : 'en')),
                ],
              ),
              const SizedBox(height: 16),
              QuestionSection(
                icon: Icons.lock_outline_rounded,
                title: 'Privacy',
                children: [
                  Material(
                    color: Colors.transparent, // ink and splashes need their own Material inside a coloured card
                    child: SwitchListTile(
                    key: const Key('onboarding_personalize'),
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryBerry,
                    title: const Text('Personalise the AI companion', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                      'Lets it use a short summary of your results and logs (never your name) to answer about you.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, height: 1.35),
                    ),
                    value: _personalize,
                    onChanged: (v) => setState(() => _personalize = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SubmitButton(label: widget.editing ? 'Save' : 'Get started', loading: false, onTap: _save),
              if (!widget.editing)
                TextButton(
                  key: const Key('onboarding_skip'),
                  onPressed: () => _save(skip: true),
                  child: const Text('Skip for now', style: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 4),
              const Text(
                'Femora gives awareness information only. It is not a medical diagnosis.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
