import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/insights.dart';
import '../models/pcos.dart';
import '../models/what_if.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

TextStyle _s(double size, {FontWeight w = FontWeight.w400, Color c = AppColors.textDark, double? h}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: c, height: h);

Color _levelColor(RiskLevel l) => switch (l) { RiskLevel.low => const Color(0xFF2E9E68), RiskLevel.medium => const Color(0xFFE08A1E), RiskLevel.high => const Color(0xFFC62828) };

String _points(double p) {
  final r = p.round();
  if (r == 0) return 'no change';
  return r < 0 ? '${r.abs()} points lower' : '$r points higher';
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
      return Text('Change something below to see what the model would say.', key: const Key('whatif_hint'), style: _s(12.5, c: AppColors.textMuted, h: 1.4));
    }
    final live = st.live;
    if (live == null) {
      return Row(children: [
        if (st.loadingLive) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        if (st.loadingLive) const SizedBox(width: 10),
        Expanded(child: Text(st.error ?? 'Working it out…', key: Key(st.error != null ? 'whatif_error' : 'whatif_working'), style: _s(12.5, c: st.error != null ? const Color(0xFF7A2E3E) : AppColors.textMuted))),
      ]);
    }
    final lower = live.changePoints < -0.5;
    final higher = live.changePoints > 0.5;
    final color = lower ? const Color(0xFF2E9E68) : (higher ? const Color(0xFFC62828) : AppColors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Now', style: _s(11, c: AppColors.textMuted)),
              Text('${result.percent}%', key: const Key('whatif_now'), style: _s(24, w: FontWeight.w700, c: AppColors.textMuted)),
            ]),
            const Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, 4), child: Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted)),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('With your changes', overflow: TextOverflow.ellipsis, style: _s(11, c: AppColors.textMuted)),
                Text('${live.percent}%', key: const Key('whatif_live'), style: _s(24, w: FontWeight.w700, c: _levelColor(live.riskLevel))),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Text(_points(live.changePoints), key: const Key('whatif_delta'), style: _s(12, w: FontWeight.w700, c: color)),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.tune_rounded, color: AppColors.primaryBerry),
              const SizedBox(width: 8),
              Expanded(child: Text('What if I changed something?', style: _s(17, w: FontWeight.w700))),
              if (st.hasChanges) TextButton(key: const Key('whatif_reset'), onPressed: st.reset, child: const Text('Reset')),
            ]),
            const SizedBox(height: 2),
            Text('Try the things you can influence. This is what the model would estimate, not a promise.', style: _s(12, c: AppColors.textMuted, h: 1.35)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8F4FB), borderRadius: BorderRadius.circular(16)),
              child: _liveBox(st),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              key: const Key('whatif_exercise'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppColors.primaryBerry,
              title: Text('I exercise regularly', style: _s(13.5, w: FontWeight.w600)),
              value: st.exercise,
              onChanged: st.setExercise,
            ),
            SwitchListTile(
              key: const Key('whatif_fastfood'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppColors.primaryBerry,
              title: Text('I eat fast food often', style: _s(13.5, w: FontWeight.w600)),
              value: st.fastFood,
              onChanged: st.setFastFood,
            ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text('Weight', style: _s(13.5, w: FontWeight.w600))),
              Text('${st.weightKg.toStringAsFixed(1)} kg · BMI ${bmi.toStringAsFixed(1)}', key: const Key('whatif_weight_text'), style: _s(12.5, w: FontWeight.w700, c: AppColors.primaryBerry)),
            ]),
            if (atFloor)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text('Your weight is already at or below the healthy range for your height, so lowering it is not offered.', key: const Key('whatif_weight_note'), style: _s(11.5, c: AppColors.textMuted, h: 1.35)),
              )
            else
              Slider(
                key: const Key('whatif_weight'),
                value: st.weightKg.clamp(minW, maxW).toDouble(),
                min: minW,
                max: maxW,
                divisions: ((maxW - minW) * 2).round().clamp(1, 400),
                activeColor: AppColors.primaryBerry,
                onChanged: st.setWeight,
              ),
            if (!atFloor) Text('The slider stops at a BMI of 18.5. Being underweight is not a goal.', style: _s(10.5, c: AppColors.textLight)),
            if (st.quickScenarios.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Quick wins', style: _s(14, w: FontWeight.w700)),
              const SizedBox(height: 6),
              if (st.loadingQuick && quick == null) Text('Working it out…', style: _s(12, c: AppColors.textMuted)),
              if (quick != null)
                for (var i = 0; i < quick.outcomes.length; i++) _quickRow(i, quick.outcomes[i], quick.baselineProbability),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('You already answered yes to exercise and no to fast food, and your BMI is under 25, so there is nothing left in this model to try. Symptoms cannot be changed with a slider; talk to a doctor about them.',
                    key: const Key('whatif_none'), style: _s(12, c: AppColors.textMuted, h: 1.4)),
              ),
            if (st.error != null && st.hasChanges == false)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(st.error!, key: const Key('whatif_quick_error'), style: _s(12, c: const Color(0xFF7A2E3E)))),
            const SizedBox(height: 12),
            Text(quick?.note ?? 'This shows what the model would estimate if those answers were different. It describes patterns in a small study, not what will happen to you. Please do not change your diet, exercise or weight because of it without asking your doctor.',
                key: const Key('whatif_note'), style: _s(11, c: AppColors.textLight, h: 1.4)),
            if (onAsk != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  key: const Key('whatif_ask'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryBerry, side: const BorderSide(color: AppColors.primaryBerry), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: onAsk,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Ask Femora AI about this'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickRow(int i, WhatIfOutcome o, double baseline) {
    final lower = o.changePoints < -0.5;
    final color = lower ? const Color(0xFF2E9E68) : AppColors.textMuted;
    return Padding(
      key: Key('whatif_quick_$i'),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(o.label, style: _s(12.5, w: FontWeight.w600))),
            Text('${o.percent}%', style: _s(12.5, w: FontWeight.w700, c: _levelColor(o.riskLevel))),
            const SizedBox(width: 8),
            SizedBox(width: 100, child: Text(_points(o.changePoints), textAlign: TextAlign.right, style: _s(11, w: FontWeight.w600, c: color))),
          ]),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, box) => Stack(children: [
              Container(height: 7, decoration: BoxDecoration(color: const Color(0xFFEDE8F1), borderRadius: BorderRadius.circular(4))),
              Container(height: 7, width: box.maxWidth * o.probability.clamp(0.02, 1.0), decoration: BoxDecoration(color: _levelColor(o.riskLevel).withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4))),
              Positioned(left: box.maxWidth * baseline.clamp(0.0, 1.0) - 1, top: -2, child: Container(width: 2, height: 11, color: AppColors.textDark)),
            ]),
          ),
        ],
      ),
    );
  }
}
