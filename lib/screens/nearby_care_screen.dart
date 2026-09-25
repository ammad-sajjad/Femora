import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/lang.dart';
import '../models/health_store.dart';
import '../models/places.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Her location, or null when it is off or refused. Injectable for tests.
typedef LocationFinder = Future<(double, double)?> Function();

Future<(double, double)?> deviceLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)));
    return (pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}

/// Hospitals, gynaecologists, clinics, labs and breast imaging centres near her, on a map and in a list.
class NearbyCareScreen extends StatefulWidget {
  final CareKind initialKind;
  final ApiService? api;
  final LocationFinder? locate;
  final bool showMap; // off in widget tests (map tiles come from the internet)

  const NearbyCareScreen({super.key, this.initialKind = CareKind.hospital, this.api, this.locate, this.showMap = true});

  @override
  State<NearbyCareScreen> createState() => _NearbyCareScreenState();
}

class _NearbyCareScreenState extends State<NearbyCareScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  late CareKind _kind = widget.initialKind;
  (double, double)? _where;
  String? _city; // set when searching from a city instead of her location
  bool _locating = true;
  bool _loading = false;
  String? _error;
  CarePlaces? _result;
  String? _expanded;
  final _map = MapController();

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
      final r = await _api.nearbyCare(_kind, w.$1, w.$2);
      if (!mounted) return;
      setState(() => _result = r);
      if (widget.showMap && r.places.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _map.fitCamera(CameraFit.coordinates(
                coordinates: [LatLng(w.$1, w.$2), for (final p in r.places.take(10)) LatLng(p.lat, p.lon)], padding: const EdgeInsets.all(36)));
          } catch (_) {}
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _kindLabel(CareKind k, String language) => switch (k) {
        CareKind.hospital => t(language, 'Hospitals', 'ہسپتال'),
        CareKind.gynae => t(language, 'Gynaecologists', 'گائناکالوجسٹ'),
        CareKind.clinic => t(language, 'Clinics', 'کلینک'),
        CareKind.lab => t(language, 'Labs', 'لیبارٹری'),
        CareKind.imaging => t(language, 'Breast imaging', 'بریسٹ امیجنگ'),
      };

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: Text(t(language, 'Nearby care', 'قریبی طبی سہولیات'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final k in CareKind.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      key: Key('care_${k.name}'),
                      label: Text(_kindLabel(k, language)),
                      selected: _kind == k,
                      selectedColor: const Color(0xFFFFD7E4),
                      onSelected: (_) {
                        if (_kind == k) return;
                        setState(() => _kind = k);
                        _search();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 4),
            child: Row(
              children: [
                Icon(_city == null ? Icons.my_location_rounded : Icons.location_city_rounded, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _locating
                        ? t(language, 'Finding your location…', 'آپ کا مقام تلاش ہو رہا ہے…')
                        : _city == null
                            ? t(language, 'Near you (your location is only used for this search)', 'آپ کے قریب (مقام صرف اس تلاش کے لیے)')
                            : t(language, 'Showing $_city (location is off)', '$_city دکھا رہے ہیں (مقام بند ہے)'),
                    key: const Key('care_where'),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                TextButton(onPressed: () => _pickCity(language), child: Text(t(language, 'Change', 'بدلیں'))),
              ],
            ),
          ),
          if (widget.showMap && _where != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 220,
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(initialCenter: LatLng(_where!.$1, _where!.$2), initialZoom: 13),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'pk.edu.au.femora'),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(_where!.$1, _where!.$2),
                          width: 22,
                          height: 22,
                          child: Container(
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1E88E5), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3))),
                        ),
                        if (r != null)
                          for (final (i, p) in r.places.take(15).indexed)
                            Marker(
                              point: LatLng(p.lat, p.lon),
                              width: 28,
                              height: 28,
                              child: GestureDetector(
                                onTap: () => setState(() => _expanded = p.id),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: AppColors.primaryBerry, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                      ]),
                      const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (_loading || _locating)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            _message(Icons.cloud_off_rounded, _error!, language, retry: true)
          else if (r != null && r.places.isEmpty)
            _message(
                Icons.search_off_rounded,
                _kind == CareKind.hospital
                    ? t(language, 'No hospitals found within 8 km on the map.', 'نقشے پر 8 کلومیٹر کے اندر کوئی ہسپتال نہیں ملا۔')
                    : t(language, 'Few places of this kind are on the free map here. Hospitals nearby usually have these services too.',
                        'یہاں مفت نقشے پر اس قسم کی جگہیں کم ہیں۔ قریبی ہسپتالوں میں عموماً یہ سہولیات بھی ہوتی ہیں۔'),
                language,
                showHospitals: _kind != CareKind.hospital)
          else if (r != null) ...[
            for (final (i, p) in r.places.indexed) _placeCard(i, p, r.fromGoogle, language),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                r.fromGoogle
                    ? r.attribution
                    : '${r.attribution}. ${t(language, 'Ratings appear once a Google Places key is added on the server.', 'سرور پر گوگل پلیسز کی کلید شامل ہونے پر ریٹنگز نظر آئیں گی۔')}',
                key: const Key('care_attribution'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textLight),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _message(IconData icon, String text, String language, {bool retry = false, bool showHospitals = false}) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.textLight),
            const SizedBox(height: 8),
            Text(text, key: const Key('care_message'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, height: 1.4)),
            const SizedBox(height: 10),
            if (retry) OutlinedButton(onPressed: _search, child: Text(t(language, 'Try again', 'دوبارہ کوشش کریں'))),
            if (showHospitals)
              OutlinedButton(
                onPressed: () {
                  setState(() => _kind = CareKind.hospital);
                  _search();
                },
                child: Text(t(language, 'Show hospitals', 'ہسپتال دکھائیں')),
              ),
          ],
        ),
      );

  Widget _stars(double rating) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(rating >= i ? Icons.star_rounded : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
                size: 15, color: const Color(0xFFF4B400)),
        ],
      );

  Widget _placeCard(int i, CarePlace p, bool google, String language) {
    final open = _expanded == p.id;
    return Container(
      key: Key('place_${p.id}'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: AppTheme.softShadow),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFFFFE1EA),
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBerry))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(p.distanceText, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textMuted)),
                          if (p.rating != null) ...[
                            _stars(p.rating!),
                            Text('${p.rating!.toStringAsFixed(1)} (${p.ratingCount ?? 0})',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                          ],
                          if (p.openNow != null)
                            Text(p.openNow! ? t(language, 'Open now', 'ابھی کھلا ہے') : t(language, 'Closed now', 'ابھی بند ہے'),
                                style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: p.openNow! ? const Color(0xFF2E7D57) : AppColors.accentPink)),
                        ],
                      ),
                      if (p.address.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(p.address, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textMuted)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (open && p.reviews.isNotEmpty)
              for (final rv in p.reviews)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 34),
                  child: Text('${rv.rating == null ? '' : '★ ${rv.rating!.toStringAsFixed(0)}  '}"${rv.text}"${rv.when.isEmpty ? '' : ' · ${rv.when}'}',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textDark, height: 1.35)),
                ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (p.reviews.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _expanded = open ? null : p.id),
                    child: Text(open ? t(language, 'Hide reviews', 'ریویوز چھپائیں') : t(language, 'Reviews', 'ریویوز')),
                  ),
                if (p.phone != null)
                  TextButton.icon(
                    key: Key('call_${p.id}'),
                    onPressed: () => _open('tel:${p.phone!.replaceAll(RegExp(r'[^0-9+]'), '')}'),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(t(language, 'Call', 'کال')),
                  ),
                TextButton.icon(
                  key: Key('directions_${p.id}'),
                  onPressed: () => _open(p.mapsUrl),
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: Text(t(language, 'Directions', 'راستہ')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
