import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/lang.dart';
import '../models/health_store.dart';
import '../models/pcos.dart';
import '../theme/app_theme.dart';
import '../widgets/questionnaire_widgets.dart';

/// The questionnaire (questions, options, buttons) is bilingual; the result screen's guidance text is not yet.
class PCOSQuestionnaireScreen extends StatefulWidget {
  const PCOSQuestionnaireScreen({super.key});

  @override
  State<PCOSQuestionnaireScreen> createState() => _PCOSQuestionnaireScreenState();
}

class _PCOSQuestionnaireScreenState extends State<PCOSQuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();

  bool? _irregularCycle;
  int _periodDays = 5;
  final Map<String, bool> _symptoms = {
    'weight_gain': false,
    'hair_growth': false,
    'skin_darkening': false,
    'hair_loss': false,
    'pimples': false,
  };
  bool? _fastFood;
  bool? _regularExercise;
  bool _showMissingChoices = false;

  static const _symptomOptions = [
    ('weight_gain', 'Weight Gain', 'وزن میں اضافہ', Icons.monitor_weight_outlined),
    ('hair_growth', 'Excess Facial / Body Hair', 'چہرے/جسم پر زائد بال', Icons.face_retouching_natural_outlined),
    ('skin_darkening', 'Skin Darkening', 'جلد کا سیاہ ہونا', Icons.contrast_outlined),
    ('hair_loss', 'Hair Thinning / Loss', 'بالوں کا پتلا ہونا / گرنا', Icons.content_cut_outlined),
    ('pimples', 'Acne / Pimples', 'کیل مہاسے', Icons.auto_awesome_outlined),
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill with the previous answers when retaking the assessment
    final previous = context.read<PcosState>().lastAnswers;
    if (previous != null) {
      _ageController.text = '${previous.age}';
      _heightController.text = formatNumber(previous.heightCm);
      _weightController.text = formatNumber(previous.weightKg);
      if (previous.waistIn != null) _waistController.text = formatNumber(previous.waistIn!);
      if (previous.hipIn != null) _hipController.text = formatNumber(previous.hipIn!);
      _irregularCycle = previous.irregularCycle;
      _periodDays = previous.periodDays;
      _symptoms['weight_gain'] = previous.weightGain;
      _symptoms['hair_growth'] = previous.hairGrowth;
      _symptoms['skin_darkening'] = previous.skinDarkening;
      _symptoms['hair_loss'] = previous.hairLoss;
      _symptoms['pimples'] = previous.pimples;
      _fastFood = previous.fastFood;
      _regularExercise = previous.regularExercise;
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    super.dispose();
  }

  Future<void> _submit(String language) async {
    final choicesAnswered = _irregularCycle != null && _fastFood != null && _regularExercise != null;
    setState(() => _showMissingChoices = !choicesAnswered);
    if (!_formKey.currentState!.validate() || !choicesAnswered) {
      _showSnack(t(language, 'Please answer all required questions.', 'براہِ کرم تمام ضروری سوالات کے جواب دیں۔'));
      return;
    }

    final answers = PcosAnswers(
      age: int.parse(_ageController.text),
      heightCm: double.parse(_heightController.text),
      weightKg: double.parse(_weightController.text),
      waistIn: double.tryParse(_waistController.text),
      hipIn: double.tryParse(_hipController.text),
      irregularCycle: _irregularCycle!,
      periodDays: _periodDays,
      weightGain: _symptoms['weight_gain']!,
      hairGrowth: _symptoms['hair_growth']!,
      skinDarkening: _symptoms['skin_darkening']!,
      hairLoss: _symptoms['hair_loss']!,
      pimples: _symptoms['pimples']!,
      fastFood: _fastFood!,
      regularExercise: _regularExercise!,
    );

    final error = await context.read<PcosState>().submit(answers);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      _showSnack(error);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<PcosState>().isLoading;
    final language = context.watch<HealthStore>().profile.language;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t(language, 'PCOS Risk Check', 'PCOS رسک چیک'),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text(
              t(language, 'Answer a few questions about your body, cycle and lifestyle. It takes about 2 minutes.',
                  'اپنے جسم، سائیکل اور طرزِ زندگی کے بارے میں چند سوالات کے جواب دیں۔ اس میں تقریباً 2 منٹ لگتے ہیں۔'),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 18),

            // Section 1: Body measurements
            QuestionSection(
              icon: Icons.straighten_rounded,
              title: t(language, 'About You', 'آپ کے بارے میں'),
              children: [
                Row(
                  children: [
                    Expanded(child: NumberField(controller: _ageController, label: t(language, 'Age', 'عمر'), unit: t(language, 'years', 'سال'), min: 12, max: 60, integer: true)),
                    const SizedBox(width: 12),
                    Expanded(child: NumberField(controller: _heightController, label: t(language, 'Height', 'قد'), unit: t(language, 'cm', 'سینٹی میٹر'), min: 120, max: 210)),
                  ],
                ),
                const SizedBox(height: 12),
                NumberField(controller: _weightController, label: t(language, 'Weight', 'وزن'), unit: t(language, 'kg', 'کلوگرام'), min: 25, max: 200),
                const SizedBox(height: 16),
                Text(
                  t(language, 'Optional — improves accuracy', 'اختیاری — درستگی بہتر بناتا ہے'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: NumberField(controller: _waistController, label: t(language, 'Waist', 'کمر'), unit: t(language, 'inches', 'انچ'), min: 15, max: 70, required: false)),
                    const SizedBox(width: 12),
                    Expanded(child: NumberField(controller: _hipController, label: t(language, 'Hip', 'کولہا'), unit: t(language, 'inches', 'انچ'), min: 15, max: 80, required: false)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 2: Menstrual cycle
            QuestionSection(
              icon: Icons.water_drop_outlined,
              title: t(language, 'Your Cycle', 'آپ کا سائیکل'),
              children: [
                QuestionLabel(t(language, 'How regular are your periods?', 'آپ کے پیریڈز کتنے باقاعدہ ہیں؟'), missing: _showMissingChoices && _irregularCycle == null),
                const SizedBox(height: 10),
                ChoiceRow(
                  options: tList(language, const ['Regular', 'Irregular'], const ['باقاعدہ', 'بے قاعدہ']),
                  selectedIndex: _irregularCycle == null ? null : (_irregularCycle! ? 1 : 0),
                  onSelected: (i) => setState(() => _irregularCycle = i == 1),
                ),
                const SizedBox(height: 6),
                QuestionHint(
                  t(language, 'Irregular = cycles shorter than 21 or longer than 35 days, or varying a lot month to month.',
                      'بے قاعدہ = 21 دن سے کم یا 35 دن سے زیادہ سائیکل، یا مہینے بہ مہینے بہت زیادہ فرق۔'),
                ),
                const SizedBox(height: 18),
                QuestionLabel(t(language, 'How many days does your period usually last?', 'آپ کا پیریڈ عام طور پر کتنے دن رہتا ہے؟')),
                const SizedBox(height: 10),
                _buildStepper(language),
              ],
            ),
            const SizedBox(height: 16),

            // Section 3: Symptoms
            QuestionSection(
              icon: Icons.spa_outlined,
              title: t(language, 'Symptoms', 'علامات'),
              subtitle: t(language, 'Select any you have noticed in the past 6 months', 'پچھلے 6 مہینوں میں محسوس کی گئی کوئی بھی علامت منتخب کریں'),
              children: [
                for (final (key, en, ur, icon) in _symptomOptions) ...[
                  SelectTile(
                    label: t(language, en, ur),
                    icon: icon,
                    selected: _symptoms[key]!,
                    onTap: () => setState(() => _symptoms[key] = !_symptoms[key]!),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Section 4: Lifestyle
            QuestionSection(
              icon: Icons.self_improvement_rounded,
              title: t(language, 'Lifestyle', 'طرزِ زندگی'),
              children: [
                QuestionLabel(t(language, 'Do you eat fast food often?', 'کیا آپ اکثر فاسٹ فوڈ کھاتی ہیں؟'), missing: _showMissingChoices && _fastFood == null),
                const SizedBox(height: 10),
                ChoiceRow(
                  options: tList(language, const ['Yes', 'No'], const ['جی ہاں', 'نہیں']),
                  selectedIndex: _fastFood == null ? null : (_fastFood! ? 0 : 1),
                  onSelected: (i) => setState(() => _fastFood = i == 0),
                ),
                const SizedBox(height: 18),
                QuestionLabel(t(language, 'Do you exercise regularly?', 'کیا آپ باقاعدگی سے ورزش کرتی ہیں؟'), missing: _showMissingChoices && _regularExercise == null),
                const SizedBox(height: 10),
                ChoiceRow(
                  options: tList(language, const ['Yes', 'No'], const ['جی ہاں', 'نہیں']),
                  selectedIndex: _regularExercise == null ? null : (_regularExercise! ? 0 : 1),
                  onSelected: (i) => setState(() => _regularExercise = i == 0),
                ),
              ],
            ),
            const SizedBox(height: 22),

            SubmitButton(label: t(language, 'Calculate My Risk', 'میرا رسک معلوم کریں'), loading: isLoading, onTap: () => _submit(language)),
            const SizedBox(height: 14),
            Text(
              t(language, 'Your answers are analysed by an AI model for risk awareness only. This is not a medical diagnosis.',
                  'آپ کے جوابات کا تجزیہ صرف آگاہی کے لیے ایک AI ماڈل کرتا ہے۔ یہ طبی تشخیص نہیں ہے۔'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textLight, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper(String language) {
    Widget button(IconData icon, VoidCallback? onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: onTap == null ? AppColors.lightGrayBg : AppColors.quickLogPeriod,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: onTap == null ? AppColors.textLight : AppColors.primaryBerry, size: 20),
          ),
        );

    return Row(
      children: [
        button(Icons.remove_rounded, _periodDays > 1 ? () => setState(() => _periodDays--) : null),
        Expanded(
          child: Text(
            t(language, '$_periodDays ${_periodDays == 1 ? 'day' : 'days'}', '$_periodDays دن'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
        button(Icons.add_rounded, _periodDays < 15 ? () => setState(() => _periodDays++) : null),
      ],
    );
  }
}
