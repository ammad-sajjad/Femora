import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/pcos.dart';
import '../theme/app_theme.dart';

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
    ('weight_gain', 'Weight Gain', Icons.monitor_weight_outlined),
    ('hair_growth', 'Excess Facial / Body Hair', Icons.face_retouching_natural_outlined),
    ('skin_darkening', 'Skin Darkening', Icons.contrast_outlined),
    ('hair_loss', 'Hair Thinning / Loss', Icons.content_cut_outlined),
    ('pimples', 'Acne / Pimples', Icons.auto_awesome_outlined),
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill with the previous answers when retaking the assessment
    final previous = context.read<PcosState>().lastAnswers;
    if (previous != null) {
      _ageController.text = '${previous.age}';
      _heightController.text = _formatNumber(previous.heightCm);
      _weightController.text = _formatNumber(previous.weightKg);
      if (previous.waistIn != null) _waistController.text = _formatNumber(previous.waistIn!);
      if (previous.hipIn != null) _hipController.text = _formatNumber(previous.hipIn!);
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

  String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Future<void> _submit() async {
    final choicesAnswered = _irregularCycle != null && _fastFood != null && _regularExercise != null;
    setState(() => _showMissingChoices = !choicesAnswered);
    if (!_formKey.currentState!.validate() || !choicesAnswered) {
      _showSnack('Please answer all required questions.');
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'PCOS Risk Check',
          style: TextStyle(
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
            const Text(
              'Answer a few questions about your body, cycle and lifestyle. '
              'It takes about 2 minutes.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 18),

            // Section 1: Body measurements
            _buildSection(
              icon: Icons.straighten_rounded,
              title: 'About You',
              children: [
                Row(
                  children: [
                    Expanded(child: _buildNumberField(_ageController, 'Age', 'years', min: 12, max: 60, integer: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNumberField(_heightController, 'Height', 'cm', min: 120, max: 210)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildNumberField(_weightController, 'Weight', 'kg', min: 25, max: 200),
                const SizedBox(height: 16),
                const Text(
                  'Optional — improves accuracy',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildNumberField(_waistController, 'Waist', 'inches', min: 15, max: 70, required: false)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNumberField(_hipController, 'Hip', 'inches', min: 15, max: 80, required: false)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 2: Menstrual cycle
            _buildSection(
              icon: Icons.water_drop_outlined,
              title: 'Your Cycle',
              children: [
                _buildQuestionLabel('How regular are your periods?', missing: _showMissingChoices && _irregularCycle == null),
                const SizedBox(height: 10),
                _buildChoiceRow(
                  options: const ['Regular', 'Irregular'],
                  selectedIndex: _irregularCycle == null ? null : (_irregularCycle! ? 1 : 0),
                  onSelected: (i) => setState(() => _irregularCycle = i == 1),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Irregular = cycles shorter than 21 or longer than 35 days, or varying a lot month to month.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textLight, height: 1.35),
                ),
                const SizedBox(height: 18),
                _buildQuestionLabel('How many days does your period usually last?'),
                const SizedBox(height: 10),
                _buildStepper(),
              ],
            ),
            const SizedBox(height: 16),

            // Section 3: Symptoms
            _buildSection(
              icon: Icons.spa_outlined,
              title: 'Symptoms',
              subtitle: 'Select any you have noticed in the past 6 months',
              children: [
                for (final (key, label, icon) in _symptomOptions) ...[
                  _buildSymptomTile(key, label, icon),
                  const SizedBox(height: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Section 4: Lifestyle
            _buildSection(
              icon: Icons.self_improvement_rounded,
              title: 'Lifestyle',
              children: [
                _buildQuestionLabel('Do you eat fast food often?', missing: _showMissingChoices && _fastFood == null),
                const SizedBox(height: 10),
                _buildChoiceRow(
                  options: const ['Yes', 'No'],
                  selectedIndex: _fastFood == null ? null : (_fastFood! ? 0 : 1),
                  onSelected: (i) => setState(() => _fastFood = i == 0),
                ),
                const SizedBox(height: 18),
                _buildQuestionLabel('Do you exercise regularly?', missing: _showMissingChoices && _regularExercise == null),
                const SizedBox(height: 10),
                _buildChoiceRow(
                  options: const ['Yes', 'No'],
                  selectedIndex: _regularExercise == null ? null : (_regularExercise! ? 0 : 1),
                  onSelected: (i) => setState(() => _regularExercise = i == 0),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Submit
            GestureDetector(
              onTap: isLoading ? null : _submit,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: AppTheme.buttonShadow,
                ),
                alignment: Alignment.center,
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Calculate My Risk',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
              ),
            ),
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

  Widget _buildSection({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: AppColors.quickLogPeriod, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primaryBerry, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildQuestionLabel(String text, {bool missing = false}) {
    return Text(
      missing ? '$text  •  Required' : text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: missing ? AppColors.accentPink : AppColors.textDark,
      ),
    );
  }

  Widget _buildNumberField(
    TextEditingController controller,
    String label,
    String unit, {
    required double min,
    required double max,
    bool integer = false,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [
        FilteringTextInputFormatter.allow(integer ? RegExp(r'[0-9]') : RegExp(r'[0-9.]')),
      ],
      style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        filled: true,
        fillColor: AppColors.lightGrayBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryBerry, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return required ? 'Required' : null;
        final number = double.tryParse(value);
        if (number == null || number < min || number > max) {
          return '${_formatNumber(min)}–${_formatNumber(max)}';
        }
        return null;
      },
    );
  }

  Widget _buildChoiceRow({
    required List<String> options,
    required int? selectedIndex,
    required ValueChanged<int> onSelected,
  }) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedIndex == i ? AppColors.primaryBerry : AppColors.lightGrayBg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selectedIndex == i ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepper() {
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
            '$_periodDays ${_periodDays == 1 ? 'day' : 'days'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
        button(Icons.add_rounded, _periodDays < 15 ? () => setState(() => _periodDays++) : null),
      ],
    );
  }

  Widget _buildSymptomTile(String key, String label, IconData icon) {
    final selected = _symptoms[key]!;
    return GestureDetector(
      onTap: () => setState(() => _symptoms[key] = !selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.pinkTagBg : AppColors.lightGrayBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primaryBerry : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? AppColors.primaryBerry : AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 22,
              color: selected ? AppColors.primaryBerry : AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}
