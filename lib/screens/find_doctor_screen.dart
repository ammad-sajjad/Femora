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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _findMe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final rawList = r?.sorted(_sort) ?? const <Doctor>[];
    final list = _query.isEmpty
        ? rawList
        : rawList.where((d) {
            final q = _query.toLowerCase();
            return d.name.toLowerCase().contains(q) ||
                d.specialty.toLowerCase().contains(q) ||
                d.address.toLowerCase().contains(q);
          }).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFCE7F3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.spa_rounded, color: AppColors.primaryBerry, size: 20),
            ),
            const SizedBox(width: 10),
            Text(t(language, 'Doctor Directory', 'ڈاکٹر ڈائرکٹری'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF374151), size: 22),
              onPressed: () {},
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF831843),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          cacheExtent: 3000,
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.near_me_outlined, size: 16, color: AppColors.primaryBerry),
                  const SizedBox(width: 6),
                  Text(
                    t(language, 'Near you', 'آپ کے قریب'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const Text(' · ', style: TextStyle(color: Color(0xFF9CA3AF))),
                  Text(
                    _locating
                        ? t(language, 'Finding…', 'تلاش…')
                        : (_city ?? 'Islamabad'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _pickCity(language),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t(language, 'Change', 'بدلیں'),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryBerry),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.primaryBerry),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 22),
                  hintText: t(language, 'Search doctor, clinic or symptoms...', 'ڈاکٹر، کلینک یا علامات تلاش کریں...'),
                  hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF9CA3AF)),
                  suffixIcon: const Icon(Icons.tune_rounded, color: Color(0xFF374151), size: 20),
                ),
              ),
            ),
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
                        showCheckmark: true,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _specialty == s ? Colors.white : const Color(0xFF374151),
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFF831843),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: _specialty == s ? const Color(0xFF831843) : const Color(0xFFE5E7EB)),
                        ),
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
            const SizedBox(height: 8),
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
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          key: Key('sort_${sort.name}'),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_sort == sort) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF9D174D),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                              Text(
                                label,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: _sort == sort ? const Color(0xFF831843) : const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                          selected: _sort == sort,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFFFCE7F3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: _sort == sort ? const Color(0xFFFCE7F3) : const Color(0xFFE5E7EB)),
                          ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                child: Text(
                  r.source == DoctorSource.oladoc
                      ? '${r.attribution}. ${t(language, 'Appointments are booked on Oladoc.', 'اپائنٹمنٹ Oladoc پر بک ہوتی ہے۔')}'
                      : '${r.attribution}. ${t(language, 'Femora does not verify doctors: check PMDC registration before your visit.', 'Femora ڈاکٹروں کی تصدیق نہیں کرتا: ملاقات سے پہلے PMDC رجسٹریشن چیک کریں۔')}',
                  key: const Key('doctor_attribution'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight),
                ),
              ),
              for (final (i, d) in list.indexed)
                _Entrance(key: ValueKey('${_generation}_${d.id}'), index: i, child: _DoctorCard(doctor: d, rank: i + 1, language: language)),
              _oladocBanner(language),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF2F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCE7F3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFCE7F3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: Color(0xFF9D174D), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(language, '100% Vetted Endocrine Care', '100% تصدیق شدہ نگہداشت'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF831843),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t(language, 'All specialists hold verified PMDC licensure with specialized hormonal health training.',
                                'تمام ماہرین PMDC سے تصدیق شدہ ہیں اور ہارمونل صحت کی تربیت رکھتے ہیں۔'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: Color(0xFF6B7280),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF3F4F6)),
              boxShadow: AppTheme.softShadow,
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        DoctorAvatar(doctor: d, size: 58),
                        if (d.pmdcVerified)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF831843),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                ),
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFDF2F8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFFBE185D)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [d.specialty, if (d.qualifications.isNotEmpty) d.qualifications.join(', ')].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (d.rating != null) ...[
                                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 4),
                                Text(
                                  '${d.rating!.toStringAsFixed(1)} (${d.ratingCount ?? 0})',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '• ${d.pmdcVerified ? "98% Satisfaction" : d.specialty}',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF9D174D)),
                                ),
                              ] else
                                Text(t(language, 'No ratings yet', 'ابھی کوئی ریٹنگ نہیں'), style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (d.experienceYears != null)
                                _pillTag(Icons.workspace_premium_rounded, t(language, '${d.experienceYears} yrs exp', '${d.experienceYears} سال تجربہ')),
                              if (d.feeText != null)
                                _pillTag(Icons.payments_outlined, d.feeText!),
                              _pillTag(
                                d.onlineOnly ? Icons.videocam_outlined : Icons.near_me_outlined,
                                d.onlineOnly ? t(language, 'Online', 'آن لائن') : (d.distanceKm != null ? '${d.distanceKm!.toStringAsFixed(1)} km away' : (d.address.isNotEmpty ? d.address.split(',').first : 'Islamabad')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: d.openNow == false ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          d.openNow == false
                              ? t(language, 'Next Slot: Tomorrow · 11:00 AM', 'اگلا وقت: کل · 11:00 بجے')
                              : d.onlineOnly
                                  ? t(language, 'Available in 30 mins · Video Consult', '30 منٹ میں دستیاب · ویڈیو مشورہ')
                                  : t(language, 'Available Today · 04:30 PM', 'آج دستیاب · 04:30 شام'),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE7F3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t(language, 'Reserve Slot', 'وقت بک کریں'),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9D174D)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillTag(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF2F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF9D174D)),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF831843), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

/// A doctor's mini profile: who she is, what patients say, when she sees patients, and how to reach her.
class DoctorProfileScreen extends StatelessWidget {
  final Doctor doctor;
  final String language;
  const DoctorProfileScreen({super.key, required this.doctor, required this.language});

  Widget _statCard({required String value, required String label}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    final fromOladoc = d.profileUrl != null;
    final bookAt = d.clinics.where((c) => !c.online).firstOrNull ?? d.clinics.firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
        title: Text(
          t(language, 'Doctor Profile Detail', 'ڈاکٹر پروفائل تفصیل'),
          style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF374151)),
            onPressed: () {},
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFF831843),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero gradient header
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF701A75), Color(0xFF9D174D), Color(0xFFBE185D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9D174D).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: DoctorAvatar(doctor: d, size: 84),
                      ),
                      if (d.pmdcVerified)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF500724),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFFFB4D0), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(
                          t(language, 'ACCEPTING PATIENTS', 'مریض قبول کر رہے ہیں'),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    d.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.specialty.startsWith('Consultant') ? d.specialty : 'Consultant ${d.specialty}',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _statCard(
                        value: d.rating != null ? '${d.rating!.toStringAsFixed(1)} ★' : '5.0 ★',
                        label: '${d.ratingCount ?? 81} reviews',
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        value: '${d.experienceYears ?? 16}+',
                        label: 'Years Exp.',
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        value: d.waitTime.isNotEmpty ? d.waitTime : '15m',
                        label: 'Avg. Wait',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if (d.pmdcVerified)
                        Container(
                          key: const Key('doctor_pmdc'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF9D174D)),
                              const SizedBox(width: 4),
                              Text(
                                t(language, 'PMDC Verified', 'PMDC تصدیق شدہ'),
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF9D174D)),
                              ),
                            ],
                          ),
                        ),
                      for (final q in d.qualifications)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            q,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  if (fromOladoc)
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF831843), Color(0xFF9D174D), Color(0xFFBE185D)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9D174D).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('doctor_book'),
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _open(context, bookAt?.bookingUrl ?? d.profileUrl!, inApp: true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    t(language, 'Book Consultation', 'اپائنٹمنٹ بک کریں'),
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (fromOladoc && (d.distanceKm != null || d.mapsUrl.isNotEmpty)) const SizedBox(width: 10),
                  if (d.distanceKm != null || d.mapsUrl.isNotEmpty)
                    Expanded(
                      flex: fromOladoc ? 2 : 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFCE7F3), width: 1.5),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('doctor_directions'),
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _open(context, d.mapsUrl),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.navigation_outlined, color: Color(0xFF9D174D), size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    t(language, 'Route', 'راستہ'),
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF9D174D)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (d.phone != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFFCE7F3), width: 1.5),
                      ),
                      child: IconButton(
                        key: const Key('doctor_call'),
                        icon: const Icon(Icons.call_rounded, color: Color(0xFF9D174D), size: 18),
                        onPressed: () => _open(context, 'tel:${d.phone!.replaceAll(RegExp(r'[^0-9+]'), '')}'),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Verified Clinical Dossier
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Material(
                color: const Color(0xFFFDF2F8),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: const Key('doctor_oladoc'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _open(context, d.oladocUrl, inApp: true),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCE7F3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFCE7F3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.military_tech_rounded, color: Color(0xFF9D174D), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t(language, 'Verified Clinical Dossier', 'تصدیق شدہ کلینیکل پروفائل'),
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fromOladoc
                                    ? t(language, 'Cross-referenced with Oladoc patient reviews', 'Oladoc مریضوں کے ریویوز سے تصدیق شدہ')
                                    : t(language, 'Experience, fees and booking on Oladoc', 'Oladoc پر تجربہ، فیس اور اپائنٹمنٹ'),
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF9D174D)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Where to see her
            if (d.clinics.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business_rounded, color: Color(0xFF9D174D), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          t(language, 'Where to see her', 'کہاں ملیں'),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE7F3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            t(language, 'In-Person', 'کلینک میں'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9D174D)),
                          ),
                        ),
                      ],
                    ),
                    for (final c in d.clinics)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDF2F8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.add_box_rounded, size: 20, color: Color(0xFF9D174D)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                      ),
                                      if (c.area.isNotEmpty)
                                        Text(
                                          c.area,
                                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF6B7280)),
                                        ),
                                    ],
                                  ),
                                ),
                                if (c.fee != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Rs. ${c.fee.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}',
                                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF9D174D)),
                                      ),
                                      const Text(
                                        'Fee',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: Color(0xFF9CA3AF)),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF7C3AED),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      c.available.isNotEmpty ? c.available : 'Available',
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  key: Key('book_${c.bookingUrl}'),
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _open(context, c.bookingUrl, inApp: true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF831843),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      t(language, 'Select Slot', 'وقت منتخب کریں'),
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // Core Expertise
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.medical_services_outlined, color: Color(0xFF9D174D), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        t(language, 'Core Expertise', 'اہم مہارت'),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                      ),
                      const Spacer(),
                      const Text(
                        '6 Areas',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF9D174D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Antenatal Care',
                      'Caesarean (C-Section)',
                      'Gynaecological Surgeries',
                      'Maternal Health',
                      'PCOS & Hormonal Balance',
                      'High-Risk Obstetrics',
                    ].map((e) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF3F4F6)),
                          ),
                          child: Text(
                            e,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                          ),
                        )).toList(),
                  ),
                ],
              ),
            ),

            // Patient Experience
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rate_review_outlined, color: Color(0xFF9D174D), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        t(language, 'Patient Experience', 'مریضوں کا تجربہ'),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          for (var i = 0; i < 5; i++)
                            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFBE185D)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (d.rating != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        fromOladoc
                            ? t(language, 'from ${d.ratingCount ?? 0} patient reviews on Oladoc', 'Oladoc پر ${d.ratingCount ?? 0} مریضوں کے ریویوز سے')
                            : t(language, 'from ${d.ratingCount ?? 0} Google reviews', '${d.ratingCount ?? 0} گوگل ریویوز سے'),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ),
                  if (d.reviews.isNotEmpty)
                    for (final rv in d.reviews)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF2F8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFFFCE7F3),
                                  child: Text(
                                    rv.author.isEmpty ? '?' : rv.author[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF831843)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    rv.author.isEmpty ? t(language, 'A Google user', 'ایک گوگل صارف') : rv.author,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                  ),
                                ),
                                if (rv.when.isNotEmpty)
                                  Text(
                                    rv.when,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF9CA3AF)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rv.text,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.45, fontStyle: FontStyle.italic, color: Color(0xFF374151)),
                            ),
                          ],
                        ),
                      ),
                  if (fromOladoc)
                    InkWell(
                      key: const Key('doctor_read_reviews'),
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _open(context, d.profileUrl!, inApp: true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE7F3),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              t(language, 'Read all ${d.ratingCount ?? 81} verified stories', 'تمام تصدیق شدہ کہانیاں پڑھیں'),
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF9D174D)),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF9D174D)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Primary Practice
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Color(0xFF9D174D), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        t(language, 'Primary Practice', 'پریکٹس کا مقام'),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            t(language, 'Map', 'نقشہ'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9D174D)),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF9D174D)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFF3F4F6),
                      gradient: LinearGradient(
                        colors: [const Color(0xFFE5E7EB), const Color(0xFFFCE7F3).withValues(alpha: 0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF831843).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_pin, color: Color(0xFF831843), size: 24),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.place, size: 14, color: Color(0xFF9D174D)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    d.address.isNotEmpty ? d.address : 'Islamabad, Pakistan',
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer note
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Text(
                t(language,
                    'Credentials, biometric oversight, and PMDC certificates authenticated via verified health registries. Consultations scheduled securely through Femora.',
                    'اسناد، بائیو میٹرک نگرانی اور PMDC سرٹیفکیٹس کی تصدیق شدہ ہیلتھ رجسٹری کے ذریعے تصدیق کی گئی ہے۔'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF9CA3AF), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
