import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/breast.dart';
import '../theme/app_theme.dart';
import '../widgets/questionnaire_widgets.dart';

class BreastRiskQuestionnaireScreen extends StatefulWidget {
  const BreastRiskQuestionnaireScreen({super.key});

  @override
  State<BreastRiskQuestionnaireScreen> createState() => _BreastRiskQuestionnaireScreenState();
}

class _BreastRiskQuestionnaireScreenState extends State<BreastRiskQuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  Menopause? _menopause;
  bool? _hormoneTherapy;
  bool? _surgicalMenopause;
  FirstBirth? _firstBirth;
  int? _relatives; // index into _relativeOptions
  int? _biopsy; // index into _yesNoUnsure
  int _mammogram = 0; // index into _mammogramOptions
  BreastDensity? _density;
  final Set<String> _symptoms = {};
  bool _showMissingChoices = false;

  static const _yesNoUnsure = ['Yes', 'No', 'Not sure'];
  static const _relativeOptions = ['None', 'One', '2+', 'Not sure'];
  static const _firstBirthOptions = [
    (FirstBirth.under30, 'Before age 30'),
    (FirstBirth.thirtyOrOlder, 'At age 30 or later'),
    (FirstBirth.never, "I haven't given birth"),
    (FirstBirth.unknown, 'Prefer not to say'),
  ];
  static const _mammogramOptions = [
    (null, 'Never, or not sure'),
    (LastMammogram.normal, 'Yes, and it was normal'),
    (LastMammogram.falsePositive, 'Yes, I needed extra tests, but it was not cancer'),
  ];
  static const _densityOptions = [
    (BreastDensity.a, 'A: almost entirely fatty'),
    (BreastDensity.b, 'B: scattered areas of density'),
    (BreastDensity.c, 'C: heterogeneously dense'),
    (BreastDensity.d, 'D: extremely dense'),
    (null, "I don't know"),
  ];
  static const _symptomIcons = {
    'breast_lump': Icons.bubble_chart_outlined,
    'armpit_lump': Icons.accessibility_new_rounded,
    'nipple_discharge': Icons.water_drop_outlined,
    'nipple_change': Icons.adjust_rounded,
    'skin_change': Icons.texture_rounded,
    'shape_change': Icons.change_circle_outlined,
    'breast_pain': Icons.healing_outlined,
  };

  @override
  void initState() {
    super.initState();
    // Pre-fill with the previous answers when retaking the assessment
    final previous = context.read<BreastState>().lastRiskAnswers;
    if (previous != null) {
      _ageController.text = '${previous.age}';
      _heightController.text = formatNumber(previous.heightCm);
      _weightController.text = formatNumber(previous.weightKg);
      _menopause = previous.menopause;
      _hormoneTherapy = previous.hormoneTherapy;
      _surgicalMenopause = previous.surgicalMenopause;
      _firstBirth = previous.firstBirth;
      _relatives = previous.relatives ?? 3;
      _biopsy = previous.breastBiopsy == null ? 2 : (previous.breastBiopsy! ? 0 : 1);
      _mammogram = _mammogramOptions.indexWhere((o) => o.$1 == previous.lastMammogram);
      _density = previous.density;
      _symptoms.addAll(previous.symptoms);
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  bool? _fromYesNoUnsure(int? index) => index == null || index == 2 ? null : index == 0;

  int _toYesNoUnsure(bool? value) => value == null ? 2 : (value ? 0 : 1);

  Future<void> _submit() async {
    final choicesAnswered = _menopause != null && _firstBirth != null && _relatives != null && _biopsy != null;
    setState(() => _showMissingChoices = !choicesAnswered);
    if (!_formKey.currentState!.validate() || !choicesAnswered) {
      _showSnack('Please answer all required questions.');
      return;
    }

    final postMenopause = _menopause == Menopause.post;
    final hadMammogram = _mammogramOptions[_mammogram].$1 != null;
    final answers = BreastRiskAnswers(
      age: int.parse(_ageController.text),
      heightCm: double.parse(_heightController.text),
      weightKg: double.parse(_weightController.text),
      menopause: _menopause!,
      hormoneTherapy: postMenopause ? _hormoneTherapy : null,
      surgicalMenopause: postMenopause ? _surgicalMenopause : null,
      firstBirth: _firstBirth!,
      relatives: _relatives == 3 ? null : _relatives,
      breastBiopsy: _fromYesNoUnsure(_biopsy),
      lastMammogram: _mammogramOptions[_mammogram].$1,
      density: hadMammogram ? _density : null,
      symptoms: Set.of(_symptoms),
    );

    final error = await context.read<BreastState>().submitRisk(answers);
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
    final isLoading = context.watch<BreastState>().isAssessing;
    final hadMammogram = _mammogramOptions[_mammogram].$1 != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Breast Health Check',
          style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            const Text(
              'Answer a few questions about your health and family history. It takes about 3 minutes. '
              'If you are not sure about something, choose "Not sure".',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 18),

            // Section 1: About you
            QuestionSection(
              icon: Icons.straighten_rounded,
              title: 'About You',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: NumberField(
                          controller: _ageController, label: 'Age', unit: 'years', min: 18, max: 100, integer: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NumberField(controller: _heightController, label: 'Height', unit: 'cm', min: 120, max: 210),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                NumberField(controller: _weightController, label: 'Weight', unit: 'kg', min: 25, max: 200),
              ],
            ),
            const SizedBox(height: 16),

            // Section 2: Reproductive history
            QuestionSection(
              icon: Icons.water_drop_outlined,
              title: 'Periods & Pregnancy',
              children: [
                QuestionLabel('Have your periods stopped for good (menopause)?',
                    missing: _showMissingChoices && _menopause == null),
                const SizedBox(height: 10),
                ChoiceRow(
                  options: const ['Not yet', 'Yes', 'Not sure'],
                  selectedIndex: _menopause == null ? null : [Menopause.pre, Menopause.post, Menopause.unknown].indexOf(_menopause!),
                  onSelected: (i) => setState(() => _menopause = [Menopause.pre, Menopause.post, Menopause.unknown][i]),
                ),
                if (_menopause == Menopause.post) ...[
                  const SizedBox(height: 18),
                  const QuestionLabel('Are you currently taking hormone therapy (HRT)?'),
                  const SizedBox(height: 10),
                  ChoiceRow(
                    options: _yesNoUnsure,
                    selectedIndex: _toYesNoUnsure(_hormoneTherapy),
                    onSelected: (i) => setState(() => _hormoneTherapy = _fromYesNoUnsure(i)),
                  ),
                  const SizedBox(height: 18),
                  const QuestionLabel('Did your periods stop because your ovaries were removed?'),
                  const SizedBox(height: 10),
                  ChoiceRow(
                    options: _yesNoUnsure,
                    selectedIndex: _toYesNoUnsure(_surgicalMenopause),
                    onSelected: (i) => setState(() => _surgicalMenopause = _fromYesNoUnsure(i)),
                  ),
                ],
                const SizedBox(height: 18),
                QuestionLabel('How old were you when you first gave birth?',
                    missing: _showMissingChoices && _firstBirth == null),
                const SizedBox(height: 10),
                ChoiceList(
                  options: [for (final o in _firstBirthOptions) o.$2],
                  selectedIndex: _firstBirth == null ? null : _firstBirthOptions.indexWhere((o) => o.$1 == _firstBirth),
                  onSelected: (i) => setState(() => _firstBirth = _firstBirthOptions[i].$1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 3: Family & medical history
            QuestionSection(
              icon: Icons.family_restroom_rounded,
              title: 'Family & Medical History',
              children: [
                QuestionLabel('How many of your mother, sisters or daughters have had breast cancer?',
                    missing: _showMissingChoices && _relatives == null),
                const SizedBox(height: 10),
                ChoiceRow(
                  options: _relativeOptions,
                  selectedIndex: _relatives,
                  onSelected: (i) => setState(() => _relatives = i),
                ),
                const SizedBox(height: 18),
                QuestionLabel('Have you ever had a breast biopsy?', missing: _showMissingChoices && _biopsy == null),
                const SizedBox(height: 10),
                ChoiceRow(
                  options: _yesNoUnsure,
                  selectedIndex: _biopsy,
                  onSelected: (i) => setState(() => _biopsy = i),
                ),
                const SizedBox(height: 6),
                const QuestionHint('A biopsy is when a doctor removes a small sample of breast tissue to test it.'),
              ],
            ),
            const SizedBox(height: 16),

            // Section 4: Mammogram (optional)
            QuestionSection(
              icon: Icons.document_scanner_outlined,
              title: 'Mammogram',
              subtitle: 'Optional: makes the estimate more precise',
              children: [
                const QuestionLabel('Have you had a mammogram before?'),
                const SizedBox(height: 10),
                ChoiceList(
                  options: [for (final o in _mammogramOptions) o.$2],
                  selectedIndex: _mammogram,
                  onSelected: (i) => setState(() => _mammogram = i),
                ),
                if (hadMammogram) ...[
                  const SizedBox(height: 18),
                  const QuestionLabel('What breast density did the report mention?'),
                  const SizedBox(height: 6),
                  const QuestionHint('Look for "breast density" or "BI-RADS density" on the mammogram report.'),
                  const SizedBox(height: 10),
                  ChoiceList(
                    options: [for (final o in _densityOptions) o.$2],
                    selectedIndex: _densityOptions.indexWhere((o) => o.$1 == _density),
                    onSelected: (i) => setState(() => _density = _densityOptions[i].$1),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Section 5: Symptoms
            QuestionSection(
              icon: Icons.spa_outlined,
              title: 'Symptoms',
              subtitle: 'Select any changes you have noticed recently',
              children: [
                for (final entry in breastSymptoms.entries) ...[
                  SelectTile(
                    label: entry.value,
                    icon: _symptomIcons[entry.key],
                    selected: _symptoms.contains(entry.key),
                    onTap: () => setState(
                      () => _symptoms.contains(entry.key) ? _symptoms.remove(entry.key) : _symptoms.add(entry.key),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
            const SizedBox(height: 22),

            SubmitButton(label: 'Calculate My Risk', loading: isLoading, onTap: _submit),
            const SizedBox(height: 14),
            const Text(
              'Your answers are analysed by an AI model for risk awareness only. This is not a medical diagnosis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textLight, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
