import 'package:animated_emoji/animated_emoji.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'companion_effects.dart';

/// A feeling a user can tap instead of finding the words for it.
///
/// The point is that saying "I hurt" should take one tap and no courage: many women are shy about these
/// topics, so the emoji does the talking and the companion answers with comfort. Tapping a mood sends
/// [message] as an ordinary chat message, in her app language.
class Mood {
  const Mood(
      {required this.key, required this.emoji, required this.labelEn, required this.labelUr, required this.messageEn, required this.messageUr});

  final String key;
  final AnimatedEmojiData emoji;
  final String labelEn;
  final String labelUr;
  final String messageEn;
  final String messageUr;

  String label(bool urdu) => urdu ? labelUr : labelEn;
  String message(bool urdu) => urdu ? messageUr : messageEn;
}

/// The six feelings offered. Kept short on purpose: a long list is a form, not a conversation.
const moods = <Mood>[
  Mood(
    key: 'happy',
    emoji: AnimatedEmojis.smile,
    labelEn: 'Happy',
    labelUr: 'خوش',
    messageEn: 'I am feeling happy today.',
    messageUr: 'آج میں خوش محسوس کر رہی ہوں۔',
  ),
  Mood(
    key: 'sad',
    emoji: AnimatedEmojis.sad,
    labelEn: 'Sad',
    labelUr: 'اداس',
    messageEn: 'I am feeling sad today and I am not sure why.',
    messageUr: 'آج میں اداس ہوں اور مجھے سمجھ نہیں آ رہی کیوں۔',
  ),
  Mood(
    key: 'angry',
    emoji: AnimatedEmojis.angry,
    labelEn: 'Angry',
    labelUr: 'غصہ',
    messageEn: 'I am feeling angry and irritated over small things.',
    messageUr: 'مجھے چھوٹی چھوٹی باتوں پر غصہ آ رہا ہے۔',
  ),
  Mood(
    key: 'tired',
    emoji: AnimatedEmojis.tired,
    labelEn: 'Tired',
    labelUr: 'تھکن',
    messageEn: 'I am feeling very tired and low on energy.',
    messageUr: 'میں بہت تھکی ہوئی ہوں اور مجھ میں توانائی نہیں۔',
  ),
  Mood(
    key: 'worried',
    emoji: AnimatedEmojis.anxiousWithSweat,
    labelEn: 'Worried',
    labelUr: 'پریشان',
    messageEn: 'I am feeling worried and anxious about my health.',
    messageUr: 'میں اپنی صحت کے بارے میں پریشان اور بے چین ہوں۔',
  ),
  Mood(
    key: 'pain',
    emoji: AnimatedEmojis.bandageFace, // weary renders blank in lottie 3.x; this one works and reads as hurting
    labelEn: 'In pain',
    labelUr: 'درد',
    messageEn: 'I am having a lot of pain today.',
    messageUr: 'آج مجھے بہت درد ہو رہا ہے۔',
  ),
];

/// The large, inviting version shown before the conversation starts.
class MoodGrid extends StatelessWidget {
  const MoodGrid({super.key, required this.urdu, required this.onPick, this.animate = true});

  final bool urdu;
  final ValueChanged<Mood> onPick;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 12,
      children: [
        for (final (i, m) in moods.indexed)
          _MoodCircle(mood: m, urdu: urdu, onPick: onPick, delay: Duration(milliseconds: i * 190), animate: animate),
      ],
    );
  }
}

class _MoodCircle extends StatelessWidget {
  const _MoodCircle({required this.mood, required this.urdu, required this.onPick, required this.delay, required this.animate});

  final Mood mood;
  final bool urdu;
  final ValueChanged<Mood> onPick;
  final Duration delay;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: GestureDetector(
        key: Key('mood_${mood.key}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onPick(mood),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Breathing(
              delay: delay,
              animate: animate,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFF1F5), Color(0xFFFFE0EB)],
                  ),
                  border: Border.all(color: const Color(0xFFFFD0E0)),
                  boxShadow: const [BoxShadow(color: Color(0x14B5234A), blurRadius: 14, offset: Offset(0, 5))],
                ),
                child: Center(
                  child: AnimatedEmoji(mood.emoji, size: 38, source: AnimatedEmojiSource.asset, repeat: animate && companionAnimations),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              mood.label(urdu),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ],
        ),
      ),
    );
  }
}

/// The slim version that stays above the input once the conversation has started.
class MoodStrip extends StatelessWidget {
  const MoodStrip({super.key, required this.urdu, required this.onPick, this.animate = true});

  final bool urdu;
  final ValueChanged<Mood> onPick;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  urdu ? 'آپ اس بارے میں کیسا محسوس کر رہی ہیں؟' : 'HOW ARE YOU FEELING ABOUT THIS?',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Color(0xFF4B5563),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                urdu ? 'حالت درج کریں' : 'Log state',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9D174D),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: moods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final m = moods[i];
              return GestureDetector(
                key: Key('mood_strip_${m.key}'),
                onTap: () => onPick(m),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedEmoji(m.emoji, size: 22, source: AnimatedEmojiSource.asset, repeat: animate && companionAnimations),
                      const SizedBox(width: 6),
                      Text(
                        m.label(urdu),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
