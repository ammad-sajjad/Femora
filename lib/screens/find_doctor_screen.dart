import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/lang.dart';
import '../models/doctors.dart';
import '../models/health_store.dart';
import '../models/places.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'nearby_care_screen.dart' show LocationFinder, deviceLocation;

String _specialtyLabel(DoctorSpecialty s, String language) => switch (s) {
      DoctorSpecialty.gynae => t(language, 'Gynaecologist', 'گائناکالوجسٹ'),
      DoctorSpecialty.breast => t(language, 'Breast surgeon', 'بریسٹ سرجن'),
      DoctorSpecialty.endocrine => t(language, 'Hormones & PCOS', 'ہارمونز اور PCOS'),
      DoctorSpecialty.fertility => t(language, 'Fertility', 'بانجھ پن کی ماہر'),
    };

/// [inApp] opens the page in a browser tab inside Femora (Oladoc), so she comes straight back to the app.
Future<void> _open(BuildContext context, String url, {bool inApp = false}) async {
  final ok = await launchUrl(Uri.parse(url), mode: inApp ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
}

/// Oladoc's own listing page for a specialty in a city (checked 25 Sep 2026: all four specialties exist for every city in
/// [pakistanCities]). Oladoc has no public API, so Femora opens its pages as they are instead of copying them.
String oladocListing(DoctorSpecialty s, String city) {
  final slug = switch (s) {
    DoctorSpecialty.gynae => 'gynecologist',
    DoctorSpecialty.breast => 'breast-surgeon',
    DoctorSpecialty.endocrine => 'endocrinologist',
    DoctorSpecialty.fertility => 'fertility-consultant',
  };
  return 'https://oladoc.com/pakistan/${city.toLowerCase().replaceAll(' ', '-')}/$slug';
}

/// The city in [pakistanCities] nearest to a point (her location), for Oladoc's city pages.
String nearestCity((double, double) at) {
  var best = pakistanCities.keys.first;
  var bestD = double.infinity;
  for (final e in pakistanCities.entries) {
    final d = (e.value.$1 - at.$1) * (e.value.$1 - at.$1) + (e.value.$2 - at.$2) * (e.value.$2 - at.$2);
    if (d < bestD) {
      bestD = d;
      best = e.key;
    }
  }
  return best;
}

/// Find a doctor: individual women's-health doctors near her with ratings, so she can compare them before choosing.
class FindDoctorScreen extends StatefulWidget {
  final DoctorSpecialty initialSpecialty;
  final ApiService? api;
  final LocationFinder? locate;

  const FindDoctorScreen({super.key, this.initialSpecialty = DoctorSpecialty.gynae, this.api, this.locate});

  @override
  State<FindDoctorScreen> createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends State<FindDoctorScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  late DoctorSpecialty _specialty = widget.initialSpecialty;
  DoctorSort _sort = DoctorSort.best;
  (double, double)? _where;
  String? _city;
  bool _locating = true;
  bool _loading = false;
  String? _error;
  DoctorsResult? _result;
  int _generation = 0; // restarts the cards' entrance animation for each new list

  @override
  void initState() {
    super.initState();
    _findMe();
  }

  Future<void> _findMe() async {
    setState(() => _locating = true);
    final here = await (widget.locate ?? deviceLocation)();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (here != null) {
        _where = here;
        _city = null;
      } else {
        _city ??= 'Islamabad';
        _where = pakistanCities[_city];
      }
    });
    _search();
  }

  Future<void> _search() async {
    final w = _where;
    if (w == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.nearbyDoctors(_specialty, w.$1, w.$2);
      if (mounted) {
        setState(() {
          _result = r;
          _generation++;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCity(String language) async {
    final city = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            leading: const Icon(Icons.my_location_rounded, color: AppColors.primaryBerry),
            title: Text(t(language, 'Use my location', 'میرا مقام استعمال کریں')),
            onTap: () => Navigator.pop(c, ''),
          ),
          for (final name in pakistanCities.keys) ListTile(title: Text(name), onTap: () => Navigator.pop(c, name)),
        ]),
      ),
    );
    if (city == null || !mounted) return;
    if (city.isEmpty) {
      _city = null;
      await _findMe();
      return;
    }
    setState(() {
      _city = city;
      _where = pakistanCities[city];
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<HealthStore>().profile.language;
    final r = _result;
    final list = r?.sorted(_sort) ?? const <Doctor>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: Text(t(language, 'Find a doctor', 'ڈاکٹر تلاش کریں'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final s in DoctorSpecialty.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        key: Key('specialty_${s.name}'),
                        label: Text(_specialtyLabel(s, language)),
                        selected: _specialty == s,
                        selectedColor: const Color(0xFFFFD7E4),
                        onSelected: (_) {
                          if (_specialty == s) return;
                          setState(() => _specialty = s);
                          _search();
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
              child: Row(
                children: [
                  Icon(_city == null ? Icons.my_location_rounded : Icons.location_city_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _locating
                          ? t(language, 'Finding your location…', 'آپ کا مقام تلاش ہو رہا ہے…')
                          : _city == null
                              ? t(language, 'Near you', 'آپ کے قریب')
                              : t(language, 'In $_city (location is off)', '$_city میں (مقام بند ہے)'),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                  TextButton(onPressed: () => _pickCity(language), child: Text(t(language, 'Change', 'بدلیں'))),
                ],
              ),
            ),
            if (r != null && r.doctors.length > 1)
              SizedBox(
                key: const Key('doctor_sort'),
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  children: [
                    for (final (sort, label) in [
                      (DoctorSort.best, t(language, 'Top rated', 'بہترین ریٹنگ')),
                      (DoctorSort.nearest, t(language, 'Nearest', 'قریب ترین')),
                      if (r.source == DoctorSource.oladoc) ...[
                        (DoctorSort.experience, t(language, 'Most experienced', 'زیادہ تجربہ')),
                        (DoctorSort.fee, t(language, 'Lowest fee', 'کم فیس')),
                      ],
                      (DoctorSort.reviews, t(language, 'Most reviewed', 'زیادہ ریویوز')),
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          key: Key('sort_${sort.name}'),
                          label: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600)),
                          selected: _sort == sort,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          selectedColor: const Color(0xFFFFE1EA),
                          onSelected: (_) => setState(() {
                            _sort = sort;
                            _generation++;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            if (_loading || _locating)
              for (var i = 0; i < 4; i++) const _SkeletonCard()
            else if (_error != null)
              _message(Icons.cloud_off_rounded, _error!, language, retry: true)
            else if (r != null && r.doctors.isEmpty)
              _message(
                  Icons.person_search_rounded,
                  r.hasRatings
                      ? t(language, 'No ${_specialtyLabel(_specialty, language).toLowerCase()} found near here. Try another city.',
                          'یہاں قریب کوئی ڈاکٹر نہیں ملا۔ کوئی اور شہر آزمائیں۔')
                      : t(language, 'Browse ${_specialtyLabel(_specialty, language).toLowerCase()}s in $_cityForLinks on Oladoc: each profile shows experience, fees, patient reviews and booking.',
                          '$_cityForLinks میں Oladoc پر ڈاکٹر دیکھیں: ہر پروفائل میں تجربہ، فیس، مریضوں کے ریویوز اور اپائنٹمنٹ موجود ہیں۔'),
                  language,
                  oladoc: true)
            else if (r != null) ...[
              for (final (i, d) in list.indexed)
                _Entrance(key: ValueKey('${_generation}_${d.id}'), index: i, child: _DoctorCard(doctor: d, rank: i + 1, language: language)),
              _oladocBanner(language),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  r.source == DoctorSource.oladoc
                      ? '${r.attribution}. ${t(language, 'Appointments are booked on Oladoc.', 'اپائنٹمنٹ Oladoc پر بک ہوتی ہے۔')}'
                      : '${r.attribution}. ${t(language, 'Femora does not verify doctors: check PMDC registration before your visit.', 'Femora ڈاکٹروں کی تصدیق نہیں کرتا: ملاقات سے پہلے PMDC رجسٹریشن چیک کریں۔')}',
                  key: const Key('doctor_attribution'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _cityForLinks => _city ?? (_where == null ? 'Islamabad' : nearestCity(_where!));

  Widget _oladocBanner(String language) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Material(
          color: const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            key: const Key('oladoc_more'),
            leading: const Icon(Icons.travel_explore_rounded, color: Color(0xFF2957B8)),
            title: Text(t(language, '${_specialtyLabel(_specialty, language)}s in $_cityForLinks on Oladoc', '$_cityForLinks میں Oladoc پر ${_specialtyLabel(_specialty, language)}'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3F87))),
            subtitle: Text(t(language, 'Experience, fees, patient reviews and booking', 'تجربہ، فیس، ریویوز اور اپائنٹمنٹ'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF41568A))),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF41568A)),
            onTap: () => _open(context, oladocListing(_specialty, _cityForLinks), inApp: true),
          ),
        ),
      );

  Widget _message(IconData icon, String text, String language, {bool retry = false, bool oladoc = false}) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 44, color: AppColors.textLight),
            const SizedBox(height: 8),
            Text(text, key: const Key('doctor_message'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, height: 1.4)),
            const SizedBox(height: 10),
            if (retry) OutlinedButton(onPressed: _search, child: Text(t(language, 'Try again', 'دوبارہ کوشش کریں'))),
            if (oladoc) _oladocBanner(language),
          ],
        ),
      );
}

/// Each card slides up and fades in, one after another.
class _Entrance extends StatelessWidget {
  final int index;
  final Widget child;
  const _Entrance({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.08).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + (delay * 1000).round()),
      builder: (context, v, child) {
        final t = Curves.easeOutCubic.transform(((v * (1 + delay)) - delay).clamp(0.0, 1.0));
        return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child));
      },
      child: child,
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: const Color(0xFFEDE7EF), borderRadius: BorderRadius.circular(6)));
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(width: 58, height: 58, decoration: const BoxDecoration(color: Color(0xFFEDE7EF), shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(160, 14), const SizedBox(height: 8), bar(110, 11), const SizedBox(height: 8), bar(140, 11)])),
        ]),
      ),
    );
  }
}

/// The doctor's photo, or her initials on the brand gradient.
class DoctorAvatar extends StatelessWidget {
  final Doctor doctor;
  final double size;
  const DoctorAvatar({super.key, required this.doctor, required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.heroGradient),
      child: Text(doctor.initials, style: TextStyle(fontFamily: 'Inter', fontSize: size * 0.34, fontWeight: FontWeight.w700, color: Colors.white)),
    );
    final ref = doctor.photo;
    return Hero(
      tag: 'doctor_${doctor.id}',
      child: ClipOval(
        child: ref == null
            ? initials
            : Image.network(ApiService.doctorPhotoUrl(ref),
                width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials, frameBuilder: (context, child, frame, sync) {
                return AnimatedOpacity(opacity: frame == null && !sync ? 0 : 1, duration: const Duration(milliseconds: 300), child: frame == null && !sync ? initials : child);
              }),
      ),
    );
  }
}

Widget stars(double rating, {double size = 15}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(rating >= i ? Icons.star_rounded : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
              size: size, color: const Color(0xFFF4B400)),
      ],
    );

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final int rank;
  final String language;
  const _DoctorCard({required this.doctor, required this.rank, required this.language});

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          key: Key('doctor_${d.id}'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
              context,
              PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 450),
                pageBuilder: (_, __, ___) => DoctorProfileScreen(doctor: d, language: language),
                transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
              )),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.softShadow, color: Colors.white),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DoctorAvatar(doctor: d, size: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: d.name),
                          if (d.pmdcVerified)
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 16, color: Color(0xFF2A872E))),
                            ),
                        ]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text([d.specialty, if (d.qualifications.isNotEmpty) d.qualifications.join(', ')].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.primaryBerry, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (d.rating != null) ...[
                            stars(d.rating!),
                            Text('${d.rating!.toStringAsFixed(1)} (${d.ratingCount ?? 0})',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          ] else
                            Text(t(language, 'No ratings yet', 'ابھی کوئی ریٹنگ نہیں'), style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          if (d.experienceYears != null)
                            _pill(Icons.workspace_premium_rounded, t(language, '${d.experienceYears} yrs exp', '${d.experienceYears} سال تجربہ'), AppColors.primaryBerry),
                          if (d.feeText != null) _pill(Icons.payments_outlined, d.feeText!, const Color(0xFF2E7D57)),
                          _pill(d.onlineOnly ? Icons.videocam_outlined : (d.distanceKm == null ? Icons.location_city_rounded : Icons.near_me_rounded),
                              d.onlineOnly ? t(language, 'Online', 'آن لائن') : d.distanceText, AppColors.textMuted),
                          if (d.openNow != null)
                            _pill(d.openNow! ? Icons.circle : Icons.circle_outlined, d.openNow! ? t(language, 'Open now', 'ابھی کھلا ہے') : t(language, 'Closed now', 'ابھی بند ہے'),
                                d.openNow! ? const Color(0xFF2E7D57) : AppColors.accentPink),
                          if (d.reviews.isNotEmpty) _pill(Icons.chat_bubble_outline_rounded, t(language, '${d.reviews.length} reviews', '${d.reviews.length} ریویوز'), AppColors.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color colour) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: colour),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: colour, fontWeight: FontWeight.w600)),
      ]);
}

/// A doctor's mini profile: who she is, what patients say, when she sees patients, and how to reach her.
class DoctorProfileScreen extends StatelessWidget {
  final Doctor doctor;
  final String language;
  const DoctorProfileScreen({super.key, required this.doctor, required this.language});

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    Widget section(String title, List<Widget> children) => Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.softShadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 8),
            ...children,
          ]),
        );
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
          ]),
        );
    final fromOladoc = d.profileUrl != null;
    final bookAt = d.clinics.where((c) => !c.online).firstOrNull ?? d.clinics.firstOrNull;
    final actions = <(IconData, String, String, Key, bool)>[
      if (fromOladoc) (Icons.event_available_rounded, t(language, 'Book', 'اپائنٹمنٹ'), bookAt?.bookingUrl ?? d.profileUrl!, const Key('doctor_book'), true),
      if (d.phone != null) (Icons.call_rounded, t(language, 'Call', 'کال'), 'tel:${d.phone!.replaceAll(RegExp(r'[^0-9+]'), '')}', const Key('doctor_call'), false),
      if (d.distanceKm != null) (Icons.directions_rounded, t(language, 'Directions', 'راستہ'), d.mapsUrl, const Key('doctor_directions'), false),
      if (d.website != null) (Icons.language_rounded, t(language, 'Website', 'ویب سائٹ'), d.website!, const Key('doctor_website'), false),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryBerry,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                padding: const EdgeInsets.fromLTRB(20, 84, 20, 16),
                child: Column(
                  children: [
                    DoctorAvatar(doctor: d, size: 92),
                    const SizedBox(height: 10),
                    Text(d.name, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(d.specialty, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                    const Spacer(),
                    Row(children: [
                      stat(d.rating == null ? '–' : d.rating!.toStringAsFixed(1), fromOladoc ? t(language, 'rating', 'ریٹنگ') : t(language, 'Google rating', 'گوگل ریٹنگ')),
                      stat('${d.ratingCount ?? 0}', t(language, 'reviews', 'ریویوز')),
                      if (d.experienceYears != null)
                        stat('${d.experienceYears}', t(language, 'years experience', 'سال تجربہ'))
                      else
                        stat(d.distanceText, t(language, 'away', 'فاصلہ')),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (d.qualifications.isNotEmpty || d.openNow != null || d.pmdcVerified || d.waitTime.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        if (d.pmdcVerified)
                          Chip(
                            key: const Key('doctor_pmdc'),
                            avatar: const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF2A872E)),
                            label: Text(t(language, 'PMDC verified', 'PMDC سے تصدیق شدہ')),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(0xFFE8F5E9),
                            side: BorderSide.none,
                          ),
                        if (d.waitTime.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textMuted),
                            label: Text(t(language, 'Wait: ${d.waitTime}', 'انتظار: ${d.waitTime}')),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                          ),
                        for (final q in d.qualifications)
                          Chip(label: Text(q), visualDensity: VisualDensity.compact, backgroundColor: const Color(0xFFFFE9F0), side: BorderSide.none),
                        if (d.openNow != null)
                          Chip(
                            avatar: Icon(Icons.circle, size: 10, color: d.openNow! ? const Color(0xFF2E7D57) : AppColors.accentPink),
                            label: Text(d.openNow! ? t(language, 'Open now', 'ابھی کھلا ہے') : t(language, 'Closed now', 'ابھی بند ہے')),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                          ),
                      ]),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(children: [
                      for (final (i, (icon, label, url, key, inApp)) in actions.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            key: key,
                            style: FilledButton.styleFrom(
                                backgroundColor: i == 0 ? AppColors.primaryBerry : Colors.white,
                                foregroundColor: i == 0 ? Colors.white : AppColors.primaryBerry,
                                padding: const EdgeInsets.symmetric(vertical: 12)),
                            onPressed: () => _open(context, url, inApp: inApp),
                            icon: Icon(icon, size: 18),
                            label: Text(label),
                          ),
                        ),
                      ],
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Material(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        key: const Key('doctor_oladoc'),
                        leading: const Icon(Icons.workspace_premium_outlined, color: Color(0xFF2957B8)),
                        title: Text(
                            fromOladoc ? t(language, 'Full profile and reviews on Oladoc', 'Oladoc پر مکمل پروفائل اور ریویوز') : t(language, 'Experience, fees and booking', 'تجربہ، فیس اور اپائنٹمنٹ'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3F87))),
                        subtitle: Text(
                            fromOladoc
                                ? t(language, 'What patients wrote, services and every clinic', 'مریضوں کی رائے، خدمات اور تمام کلینک')
                                : t(language, 'Find ${d.name} on Oladoc', '${d.name} کو Oladoc پر تلاش کریں'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF41568A))),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF41568A)),
                        onTap: () => _open(context, d.oladocUrl, inApp: true),
                      ),
                    ),
                  ),
                  if (d.clinics.isNotEmpty)
                    section(t(language, 'Where to see her', 'کہاں ملیں'), [
                      for (final c in d.clinics)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          decoration: BoxDecoration(color: AppColors.lightGrayBg, borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            Icon(c.online ? Icons.videocam_rounded : Icons.local_hospital_rounded, size: 20, color: AppColors.primaryBerry),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                if (c.area.isNotEmpty) Text(c.area, style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textMuted)),
                                if (c.available.isNotEmpty)
                                  Text(c.available, style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2E7D57))),
                              ]),
                            ),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              if (c.fee != null)
                                Text('Rs. ${c.fee.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}',
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                              TextButton(
                                key: Key('book_${c.bookingUrl}'),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                onPressed: () => _open(context, c.bookingUrl, inApp: true),
                                child: Text(t(language, 'Book', 'بک کریں')),
                              ),
                            ]),
                          ]),
                        ),
                    ]),
                  if (d.about.isNotEmpty)
                    section(fromOladoc ? t(language, 'Services', 'خدمات') : t(language, 'About', 'تعارف'),
                        [Text(d.about, style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, height: 1.45))]),
                  section(t(language, 'What patients say', 'مریض کیا کہتے ہیں'), [
                    if (d.rating != null)
                      Row(children: [
                        Text(d.rating!.toStringAsFixed(1), style: const TextStyle(fontFamily: 'Inter', fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          stars(d.rating!, size: 18),
                          Text(
                              fromOladoc
                                  ? t(language, 'from ${d.ratingCount ?? 0} patient reviews on Oladoc', 'Oladoc پر ${d.ratingCount ?? 0} مریضوں کے ریویوز سے')
                                  : t(language, 'from ${d.ratingCount ?? 0} Google reviews', '${d.ratingCount ?? 0} گوگل ریویوز سے'),
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textMuted)),
                        ]),
                      ]),
                    if (d.reviews.isEmpty && fromOladoc)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          key: const Key('doctor_read_reviews'),
                          onPressed: () => _open(context, d.profileUrl!, inApp: true),
                          icon: const Icon(Icons.rate_review_outlined, size: 18),
                          label: Text(t(language, 'Read what patients wrote', 'مریضوں کی رائے پڑھیں')),
                        ),
                      )
                    else if (d.reviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(t(language, 'No written reviews to show.', 'دکھانے کے لیے کوئی تحریری ریویو نہیں۔'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textMuted)),
                      ),
                    for (final rv in d.reviews)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.lightGrayBg, borderRadius: BorderRadius.circular(14)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFFFFE1EA),
                                child: Text(rv.author.isEmpty ? '?' : rv.author[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBerry))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(rv.author.isEmpty ? t(language, 'A Google user', 'ایک گوگل صارف') : rv.author,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700))),
                            if (rv.rating != null) stars(rv.rating!, size: 13),
                          ]),
                          const SizedBox(height: 6),
                          Text(rv.text, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4, color: AppColors.textDark)),
                          if (rv.when.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(rv.when, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight)),
                          ],
                        ]),
                      ),
                  ]),
                  if (d.hours.isNotEmpty)
                    section(t(language, 'Clinic hours', 'کلینک کے اوقات'), [
                      for (final h in d.hours)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(h, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textDark)),
                        ),
                    ]),
                  if (d.address.isNotEmpty)
                    section(t(language, 'Clinic', 'کلینک'), [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.place_outlined, size: 18, color: AppColors.primaryBerry),
                        const SizedBox(width: 6),
                        Expanded(child: Text(d.address, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4))),
                      ]),
                    ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Text(
                      [
                        if (fromOladoc)
                          t(language, 'Profile, ratings, fees and PMDC verification from oladoc.com, used with Oladoc\'s permission. Appointments are booked on Oladoc.',
                              'پروفائل، ریٹنگ، فیس اور PMDC تصدیق oladoc.com سے، Oladoc کی اجازت کے ساتھ۔ اپائنٹمنٹ Oladoc پر بک ہوتی ہے۔')
                        else ...[
                          t(language, 'Ratings and reviews are from Google users.', 'ریٹنگز اور ریویوز گوگل صارفین کے ہیں۔'),
                          if (d.photoCredit.isNotEmpty) t(language, 'Photo: ${d.photoCredit}.', 'تصویر: ${d.photoCredit}۔'),
                          t(language, 'Femora does not verify doctors; you can check PMDC registration at pmdc.pk.',
                              'Femora ڈاکٹروں کی تصدیق نہیں کرتا؛ PMDC رجسٹریشن pmdc.pk پر چیک کی جا سکتی ہے۔'),
                        ],
                      ].join(' '),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
