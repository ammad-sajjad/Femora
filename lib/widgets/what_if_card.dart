import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/insights.dart';
import '../models/pcos.dart';
import '../models/what_if.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

TextStyle _s(double size, {FontWeight w = FontWeight.w400, Color c = AppColors.textDark, double? h, double? letterSpacing}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: letterSpacing);

Color _levelColor(RiskLevel l) => switch (l) {
      RiskLevel.low => const Color(0xFF10B981),
      RiskLevel.medium => const Color(0xFFF59E0B),
      RiskLevel.high => const Color(0xFFBE185D),
    };

String _points(double p) {
  final r = p.round();
  if (r == 0) return 'no change';
  return r < 0 ? '${r.abs()} points lower' : '$r points higher';
}

String _badgePoints(double p) {
  final r = p.round();
  if (r == 0) return '0 pts';
  return r < 0 ? '$r pts' : '+$r pts';
}

/// "What if I changed something?": the PCOS model's estimate for changes she can make, with live sliders and quick wins.
class WhatIfCard extends StatelessWidget {
  final PcosAnswers answers;
  final PcosResult result;
  final ApiService? api; // tests pass their own
  final VoidCallback? onAsk;

  const WhatIfCard({super.key, required this.answers, required this.result, this.api, this.onAsk});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<WhatIfState>(
        create: (_) => WhatIfState(api: api)..start(answers),
        child: _WhatIfBody(answers: answers, result: result, onAsk: onAsk),
      );
}

class _WhatIfBody extends StatelessWidget {
  final PcosAnswers answers;
  final PcosResult result;
  final VoidCallback? onAsk;
  const _WhatIfBody({required this.answers, required this.result, this.onAsk});

  Widget _liveBox(WhatIfState st) {
    if (!st.hasChanges) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE4E6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFBE185D), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Adjust controls below to see instant predictive recalibration.',
                key: const Key('whatif_hint'),
                style: _s(12.5, w: FontWeight.w500, c: const Color(0xFF9D174D), h: 1.35),
              ),
            ),
          ],
        ),
      );
    }
    final live = st.live;
    if (live == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE4E6)),
        ),
        child: Row(
          children: [
            if (st.loadingLive) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFBE185D))),
            if (st.loadingLive) const SizedBox(width: 10),
            Expanded(
              child: Text(
                st.error ?? 'Working it out…',
                key: Key(st.error != null ? 'whatif_error' : 'whatif_working'),
                style: _s(12.5, c: st.error != null ? const Color(0xFFBE185D) : AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }
    final lower = live.changePoints < -0.5;
    final higher = live.changePoints > 0.5;
    final color = lower ? const Color(0xFF059669) : (higher ? const Color(0xFFBE185D) : AppColors.textMuted);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE4E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Now', style: _s(11, w: FontWeight.w600, c: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text('${result.percent}%', key: const Key('whatif_now'), style: _s(22, w: FontWeight.w800, c: AppColors.textMuted)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Icons.arrow_forward_rounded, color: Color(0xFFBE185D), size: 20),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('With your changes', overflow: TextOverflow.ellipsis, style: _s(11, w: FontWeight.w600, c: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text('${live.percent}%', key: const Key('whatif_live'), style: _s(22, w: FontWeight.w800, c: _levelColor(live.riskLevel))),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: lower ? const Color(0xFFD1FAE5) : const Color(0xFFFCE7F3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _points(live.changePoints),
                  key: const Key('whatif_delta'),
                  style: _s(12, w: FontWeight.w700, c: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<WhatIfState>();
    final a = answers;
    final atFloor = WhatIfPlanner.weightAtFloor(a);
    final minW = WhatIfPlanner.sliderMin(a);
    final maxW = WhatIfPlanner.sliderMax(a);
    final bmi = st.bmi;
    final quick = st.quick;

    return Container(
      key: const Key('whatif_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFFBE185D),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'What if I changed something?',
                    style: _s(17, w: FontWeight.w800, letterSpacing: -0.3),
                  ),
                ),
                if (st.hasChanges)
                  TextButton(
                    key: const Key('whatif_reset'),
                    onPressed: st.reset,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Reset', style: _s(13, w: FontWeight.w700, c: const Color(0xFFBE185D))),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Explore modifiable factors you can influence. This shows simulated probabilistic response, not guaranteed outcomes.',
              style: _s(13, c: AppColors.textMuted, h: 1.4),
            ),
            const SizedBox(height: 14),

            // Live Callout Box
            _liveBox(st),
            const SizedBox(height: 14),

            // Controls Box (Switches & Slider)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9FA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFCE7F3)),
              ),
              child: Column(
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      key: const Key('whatif_exercise'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: const Color(0xFFBE185D),
                      title: Text('I exercise regularly', style: _s(13.5, w: FontWeight.w700)),
                      subtitle: Text('≥ 150 mins aerobic or strength', style: _s(11.5, c: AppColors.textMuted)),
                      value: st.exercise,
                      onChanged: st.setExercise,
                    ),
                  ),
                  const Divider(color: Color(0xFFF3E8EE), height: 14),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      key: const Key('whatif_fastfood'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: const Color(0xFFBE185D),
                      title: Text('I eat fast food often', style: _s(13.5, w: FontWeight.w700)),
                      subtitle: Text('> 3 times per week', style: _s(11.5, c: AppColors.textMuted)),
                      value: st.fastFood,
                      onChanged: st.setFastFood,
                    ),
                  ),
                  const Divider(color: Color(0xFFF3E8EE), height: 14),
                  const SizedBox(height: 4),

                  // Weight / Body Mass Metric
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Body Mass Metric', style: _s(13.5, w: FontWeight.w700)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Text(
                          '${st.weightKg.toStringAsFixed(1)} kg · BMI ${bmi.toStringAsFixed(1)}',
                          key: const Key('whatif_weight_text'),
                          style: _s(12, w: FontWeight.w700, c: const Color(0xFF9D174D)),
                        ),
                      ),
                    ],
                  ),
                  if (atFloor)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        'Your weight is already at or below the healthy range for your height, so lowering it is not offered.',
                        key: const Key('whatif_weight_note'),
                        style: _s(11.5, c: AppColors.textMuted, h: 1.35),
                      ),
                    )
                  else ...[
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFBE185D),
                        inactiveTrackColor: const Color(0xFFFCE7F3),
                        thumbColor: const Color(0xFFBE185D),
                        overlayColor: const Color(0xFFBE185D).withOpacity(0.12),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                      ),
                      child: Slider(
                        key: const Key('whatif_weight'),
                        value: st.weightKg.clamp(minW, maxW).toDouble(),
                        min: minW,
                        max: maxW,
                        divisions: ((maxW - minW) * 2).round().clamp(1, 400),
                        onChanged: st.setWeight,
                      ),
                    ),
                    Text(
                      'Slider stops at BMI 18.5 threshold. Being underweight introduces separate endocrine strain.',
                      key: const Key('whatif_weight_note'),
                      style: _s(11, c: AppColors.textLight),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // PREDICTIVE SENSITIVITY IMPACT
            if (st.quickScenarios.isNotEmpty) ...[
              Text(
                'PREDICTIVE SENSITIVITY IMPACT',
                style: _s(11, w: FontWeight.w700, c: const Color(0xFFBE185D), letterSpacing: 0.8),
              ),
              const SizedBox(height: 10),
              if (st.loadingQuick && quick == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Working it out…', style: _s(12, c: AppColors.textMuted)),
                ),
              if (quick != null)
                for (var i = 0; i < quick.outcomes.length; i++)
                  _buildQuickOutcome(i, quick.outcomes[i], quick.baselineProbability),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'You already answered yes to exercise and no to fast food, and your BMI is under 25, so there is nothing left in this model to try. Symptoms cannot be changed with a slider; talk to a doctor about them.',
                  key: const Key('whatif_none'),
                  style: _s(12, c: AppColors.textMuted, h: 1.4),
                ),
              ),

            if (st.error != null && st.hasChanges == false)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(st.error!, key: const Key('whatif_quick_error'), style: _s(12, c: const Color(0xFFBE185D))),
              ),

            const SizedBox(height: 12),
            Text(
              quick?.note ??
                  'Model projections are derived from metabolic population cohorts (n=541). Real-world endocrine shifts depend on individual insulin response and hormonal setpoints. Please do not change your diet, exercise or weight because of it without asking your doctor.',
              key: const Key('whatif_note'),
              style: _s(11.5, c: AppColors.textLight, h: 1.4),
            ),

            if (onAsk != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onAsk,
                child: Container(
                  key: const Key('whatif_ask'),
                  width: double.infinity,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF3E8FF), width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFF9D174D), size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Ask Femora AI about this simulation',
                          overflow: TextOverflow.ellipsis,
                          style: _s(13, w: FontWeight.w700, c: const Color(0xFF9D174D)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOutcome(int i, WhatIfOutcome o, double baseline) {
    final isCombination = o.label.toLowerCase().contains('together') || o.label.toLowerCase().contains('combined');

    if (isCombination) {
      // Highlight Card matching Figma "All modifications combined"
      return Container(
        key: Key('whatif_quick_$i'),
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    o.label,
                    style: _s(13.5, w: FontWeight.w700, c: const Color(0xFF065F46)),
                  ),
                ),
                Text(
                  '${o.percent}%',
                  style: _s(20, w: FontWeight.w800, c: const Color(0xFF831843)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0.0,
                        child: Text(
                          _points(o.changePoints),
                          style: const TextStyle(fontSize: 0.1),
                        ),
                      ),
                      Text(
                        _badgePoints(o.changePoints),
                        style: _s(11, w: FontWeight.w700, c: const Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 6,
                    width: box.maxWidth * o.probability.clamp(0.02, 1.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFFBE185D)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Standard row
    final isWeight = o.label.toLowerCase().contains('lighter') || o.label.toLowerCase().contains('kg') || o.label.toLowerCase().contains('weight');
    final lower = o.changePoints < -0.5;
    final badgeColor = lower ? const Color(0xFF059669) : AppColors.textMuted;
    final badgeBg = lower ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9);
    final barColor = isWeight ? const Color(0xFFE11D48) : const Color(0xFF10B981);

    return Padding(
      key: Key('whatif_quick_$i'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(o.label, style: _s(13, w: FontWeight.w700))),
              Text('${o.percent}% risk', style: _s(12, w: FontWeight.w600, c: AppColors.textMuted)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 0.0,
                      child: Text(
                        _points(o.changePoints),
                        style: const TextStyle(fontSize: 0.1),
                      ),
                    ),
                    Text(
                      _badgePoints(o.changePoints),
                      textAlign: TextAlign.right,
                      style: _s(11, w: FontWeight.w700, c: badgeColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE7F3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 6,
                  width: box.maxWidth * o.probability.clamp(0.02, 1.0),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
