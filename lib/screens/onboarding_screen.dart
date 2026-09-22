import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
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

  static const _concernOptions = <(String id, String en, String lang, IconData icon)>[
    ('pcos', 'PCOS or irregular periods', 'PCOS یا بے قاعدہ پیریڈز', Icons.bubble_chart_outlined),
    ('cycle', 'Tracking my cycle', 'اپنا سائیکل ٹریک کرنا', Icons.calendar_month_outlined),
    ('pregnancy', 'Pregnancy', 'حمل', Icons.child_friendly_outlined),
    ('breast', 'Breast health', 'بریسٹ کی صحت', Icons.favorite_border_rounded),
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
    // Shows what she just picked straight away, in both direction and script, rather than waiting for Save:
    // the whole form previews the language switch before it is committed to the profile.
    final lang = _language;
    return Directionality(
      textDirection: directionOf(lang),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: widget.editing
            ? AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                foregroundColor: AppColors.textDark,
                title: Text(t(lang, 'My profile', 'میری پروفائل'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
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
                  Text(
                    t(lang, 'Your personal women\'s health companion. Tell us a little about you so Femora can personalise what it shows and says.',
                        'آپ کا ذاتی خواتین صحت کا کمپینین۔ اپنے بارے میں کچھ بتائیں تاکہ Femora آپ کے لیے مواد اور جوابات کو ذاتی بنا سکے۔'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, color: AppColors.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                ],
                QuestionSection(
                  icon: Icons.person_outline_rounded,
                  title: t(lang, 'About you', 'آپ کے بارے میں'),
                  subtitle: t(lang, 'All optional. This stays on your phone.', 'سب اختیاری ہے۔ یہ صرف آپ کے فون میں رہتا ہے۔'),
                  children: [
                    TextFormField(
                      key: const Key('onboarding_name'),
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: t(lang, 'Name (shown on your report)', 'نام (آپ کی رپورٹ پر ظاہر ہوگا)'),
                        filled: true,
                        fillColor: AppColors.lightGrayBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: NumberField(controller: _age, label: t(lang, 'Age', 'عمر'), unit: t(lang, 'years', 'سال'), min: 12, max: 100, integer: true, required: false)),
                        const SizedBox(width: 12),
                        Expanded(child: NumberField(controller: _height, label: t(lang, 'Height', 'قد'), unit: t(lang, 'cm', 'سینٹی میٹر'), min: 120, max: 210, required: false)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    NumberField(controller: _weight, label: t(lang, 'Weight', 'وزن'), unit: t(lang, 'kg', 'کلوگرام'), min: 25, max: 200, required: false),
                  ],
                ),
                const SizedBox(height: 16),
                QuestionSection(
                  icon: Icons.favorite_outline_rounded,
                  title: t(lang, 'What matters to you?', 'آپ کے لیے کیا اہم ہے؟'),
                  subtitle: t(lang, 'Choose any that apply.', 'جو بھی لاگو ہو منتخب کریں۔'),
                  children: [
                    for (final (id, en, urLabel, icon) in _concernOptions) ...[
                      SelectTile(
                        label: t(lang, en, urLabel),
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
                  title: t(lang, 'Language', 'زبان'),
                  subtitle: t(lang, 'The companion also understands Urdu and Roman Urdu, whatever you choose here.', 'کمپینین اردو اور رومن اردو بھی سمجھتا ہے، چاہے آپ یہاں کچھ بھی منتخب کریں۔'),
                  children: [
                    ChoiceRow(options: const ['English', 'اردو'], selectedIndex: _language == 'ur' ? 1 : 0, onSelected: (i) => setState(() => _language = i == 1 ? 'ur' : 'en')),
                  ],
                ),
                const SizedBox(height: 16),
                QuestionSection(
                  icon: Icons.lock_outline_rounded,
                  title: t(lang, 'Privacy', 'پرائیویسی'),
                  children: [
                    Material(
                      color: Colors.transparent, // ink and splashes need their own Material inside a coloured card
                      child: SwitchListTile(
                        key: const Key('onboarding_personalize'),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primaryBerry,
                        title: Text(t(lang, 'Personalise the AI companion', 'AI کمپینین کو ذاتی بنائیں'), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          t(lang, 'Lets it use a short summary of your results and logs (never your name) to answer about you.',
                              'اسے آپ کے نتائج اور اندراجات کا مختصر خلاصہ (کبھی آپ کا نام نہیں) استعمال کرنے دیتا ہے تاکہ وہ آپ کے بارے میں جواب دے سکے۔'),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, height: 1.35),
                        ),
                        value: _personalize,
                        onChanged: (v) => setState(() => _personalize = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SubmitButton(label: t(lang, widget.editing ? 'Save' : 'Get started', widget.editing ? 'محفوظ کریں' : 'شروع کریں'), loading: false, onTap: _save),
                if (!widget.editing)
                  TextButton(
                    key: const Key('onboarding_skip'),
                    onPressed: () => _save(skip: true),
                    child: Text(t(lang, 'Skip for now', 'ابھی کے لیے چھوڑیں'), style: const TextStyle(fontFamily: 'Inter', color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 4),
                Text(
                  t(lang, 'Femora gives awareness information only. It is not a medical diagnosis.', 'Femora صرف آگاہی کی معلومات فراہم کرتا ہے۔ یہ طبی تشخیص نہیں ہے۔'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
