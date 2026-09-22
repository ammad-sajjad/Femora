import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/lang.dart';
import '../models/health_store.dart';
import '../models/self_exam.dart';
import '../theme/app_theme.dart';

class _Step {
  final IconData icon;
  final String title;
  final String intro;
  final List<String> points;
  final String? tip;

  const _Step({required this.icon, required this.title, required this.intro, required this.points, this.tip});
}

const _steps = [
  _Step(
    icon: Icons.person_outline_rounded,
    title: 'Look in the Mirror',
    intro: 'Stand with your shoulders straight and your arms by your sides.',
    points: [
      'Compare the size, shape and colour of both breasts.',
      'Look for dimpling, puckering or bulging of the skin.',
      'Check for redness, a rash, soreness or swelling.',
      'Notice any nipple that has changed position or turned inward.',
    ],
    tip: 'It is normal for one breast to be slightly larger. You are looking for changes from what is normal for you.',
  ),
  _Step(
    icon: Icons.accessibility_new_rounded,
    title: 'Raise Your Arms',
    intro: 'Lift both arms high above your head and look again.',
    points: [
      'Look for the same changes in shape, skin and nipples.',
      'Check the area under your breasts and towards your armpits.',
    ],
  ),
  _Step(
    icon: Icons.water_drop_outlined,
    title: 'Check Your Nipples',
    intro: 'While you are at the mirror, look closely at both nipples.',
    points: [
      'Look for any fluid coming out: watery, milky, yellow or blood.',
      'Look for crusting, scaling or a rash on the nipple or the dark area around it.',
    ],
    tip: 'Milky discharge while breastfeeding is normal.',
  ),
  _Step(
    icon: Icons.airline_seat_flat_outlined,
    title: 'Lie Down and Feel',
    intro: 'Lie on your back with your right hand behind your head. Use the pads of the three middle fingers of your '
        'left hand to check your right breast, then swap sides.',
    points: [
      'Move your fingers in small, coin-sized circles.',
      'Use light, then medium, then firm pressure at each spot.',
      'Cover the whole area: from your collarbone to the top of your belly, and from your armpit to your breastbone.',
      'Follow an up-and-down pattern, like mowing a lawn, so you don\'t miss anything.',
    ],
  ),
  _Step(
    icon: Icons.shower_outlined,
    title: 'Repeat Standing Up',
    intro: 'Many women find this easiest in the shower, when the skin is wet and soapy.',
    points: [
      'Use the same circular movements and up-and-down pattern.',
      'Feel your armpits too, where breast tissue also sits.',
    ],
  ),
];

const _warningSigns = [
  'A new lump or thickening in the breast or armpit',
  'A change in size or shape',
  'Dimpling, puckering or redness of the skin',
  'A nipple that has turned inward',
  'Fluid or blood from a nipple',
  'Pain in one spot that does not go away',
];

class SelfExamGuideScreen extends StatefulWidget {
  const SelfExamGuideScreen({super.key});

  @override
  State<SelfExamGuideScreen> createState() => _SelfExamGuideScreenState();
}

class _SelfExamGuideScreenState extends State<SelfExamGuideScreen> {
  final _controller = PageController();
  int _page = 0;

  // Intro page + one page per step + "when to see a doctor"
  int get _pageCount => _steps.length + 2;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) =>
      _controller.animateToPage(page, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

  Future<void> _complete(String language) async {
    await context.read<SelfExamState>().logExam();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(t(language, 'Self-exam logged. Your next one is due in 30 days.', 'سیلف ایگزام درج ہو گیا۔ آپ کا اگلا معائنہ 30 دن میں واجب ہے۔')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pageCount - 1;
    final language = context.watch<HealthStore>().profile.language;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t(language, 'Self-Exam Guide', 'سیلف ایگزام گائیڈ'),
          style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_page + 1) / _pageCount,
                        minHeight: 6,
                        backgroundColor: AppColors.pinkTagBg,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primaryBerry),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_page + 1} / $_pageCount',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _buildIntroPage(),
                  for (var i = 0; i < _steps.length; i++) _buildStepPage(i),
                  _buildWarningPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_page > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _goTo(_page - 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: AppColors.primaryBerry, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: Text(
                          t(language, 'Back', 'واپس'),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryBerry),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: isLast ? () => _complete(language) : () => _goTo(_page + 1),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: AppTheme.buttonShadow,
                        ),
                        child: Text(
                          isLast ? t(language, "I've Done My Self-Exam", 'میں نے اپنا سیلف ایگزام کر لیا ہے') : (_page == 0 ? t(language, 'Start', 'شروع کریں') : t(language, 'Next', 'اگلا')),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageScroll(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );

  Widget _buildIntroPage() => _pageScroll([
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset('assets/images/self_exam_guide.png', width: double.infinity, height: 170, fit: BoxFit.cover),
        ),
        const SizedBox(height: 18),
        const Text(
          'Know What Is Normal for You',
          style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        const Text(
          'A monthly self-exam takes about 3 minutes. Most breast changes are not cancer, but knowing how your '
          'breasts normally look and feel helps you notice a change early.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: AppColors.textMuted, height: 1.45),
        ),
        const SizedBox(height: 16),
        _infoRow(Icons.event_rounded, 'When', 'Once a month, 3–5 days after your period ends, when breasts are least tender. '
            'After menopause, pick the same date every month.'),
        const SizedBox(height: 12),
        _infoRow(Icons.timer_outlined, 'How long', 'About 3 minutes: 1 at the mirror, 2 feeling each breast.'),
      ]);

  Widget _buildStepPage(int i) {
    final step = _steps[i];
    return _pageScroll([
      Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.quickLogPeriod, shape: BoxShape.circle),
            child: Icon(step.icon, color: AppColors.primaryBerry, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP ${i + 1}',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.accentPink, letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  step.title,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(step.intro, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textDark, height: 1.45)),
      const SizedBox(height: 14),
      for (final point in step.points) _bullet(point),
      if (step.tip != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFEFF3FA), borderRadius: BorderRadius.circular(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF7A4F84), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(step.tip!, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF4A5568), height: 1.4)),
              ),
            ],
          ),
        ),
      ],
    ]);
  }

  Widget _buildWarningPage() => _pageScroll([
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.pinkTagBg, shape: BoxShape.circle),
              child: const Icon(Icons.local_hospital_outlined, color: AppColors.pinkTagText, size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'When to See a Doctor',
                style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Book an appointment if you notice any of these, even if you are young or had a normal exam before:',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textDark, height: 1.45),
        ),
        const SizedBox(height: 14),
        for (final sign in _warningSigns) _bullet(sign),
        const SizedBox(height: 8),
        const Text(
          'Most lumps turn out to be harmless, like cysts or fibroadenomas, but only a doctor can tell. '
          'You can also use the Breast Health Check in Femora to record your symptoms.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted, height: 1.45),
        ),
      ]);

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.check_circle_outline, color: AppColors.primaryBerry, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF4A5568), height: 1.4)),
            ),
          ],
        ),
      );

  Widget _infoRow(IconData icon, String title, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryBerry, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                TextSpan(text: text),
              ]),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF4A5568), height: 1.4),
            ),
          ),
        ],
      );
}
