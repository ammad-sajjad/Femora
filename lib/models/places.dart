/// Nearby care: what the server's /places/nearby returns.
enum CareKind { hospital, gynae, clinic, lab, imaging }

class PlaceReview {
  final double? rating;
  final String text;
  final String when;
  const PlaceReview({this.rating, required this.text, this.when = ''});

  factory PlaceReview.fromJson(Map<String, dynamic> j) =>
      PlaceReview(rating: (j['rating'] as num?)?.toDouble(), text: j['text'] as String, when: (j['when'] as String?) ?? '');
}

class CarePlace {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final double distanceKm;
  final String address;
  final String? phone;
  final double? rating;
  final int? ratingCount;
  final bool? openNow;
  final String mapsUrl;
  final List<PlaceReview> reviews;

  const CarePlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.distanceKm,
    this.address = '',
    this.phone,
    this.rating,
    this.ratingCount,
    this.openNow,
    required this.mapsUrl,
    this.reviews = const [],
  });

  factory CarePlace.fromJson(Map<String, dynamic> j) => CarePlace(
        id: j['id'] as String,
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        distanceKm: (j['distance_km'] as num).toDouble(),
        address: (j['address'] as String?) ?? '',
        phone: j['phone'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: (j['rating_count'] as num?)?.toInt(),
        openNow: j['open_now'] as bool?,
        mapsUrl: j['maps_url'] as String,
        reviews: [for (final r in (j['reviews'] as List?) ?? const []) PlaceReview.fromJson(r as Map<String, dynamic>)],
      );

  String get distanceText => distanceKm < 1 ? '${(distanceKm * 1000).round()} m' : '${distanceKm.toStringAsFixed(1)} km';
}

class CarePlaces {
  final CareKind kind;
  final bool fromGoogle; // Google has ratings and reviews; OpenStreetMap does not
  final String attribution;
  final List<CarePlace> places;
  const CarePlaces({required this.kind, required this.fromGoogle, required this.attribution, required this.places});

  factory CarePlaces.fromJson(Map<String, dynamic> j) => CarePlaces(
        kind: CareKind.values.byName(j['kind'] as String),
        fromGoogle: j['source'] == 'google',
        attribution: j['attribution'] as String,
        places: [for (final p in j['places'] as List) CarePlace.fromJson(p as Map<String, dynamic>)],
      );
}

/// Places to search from when her location is not available (city centres).
const pakistanCities = <String, (double, double)>{
  'Islamabad': (33.6844, 73.0479),
  'Rawalpindi': (33.5651, 73.0169),
  'Lahore': (31.5204, 74.3587),
  'Karachi': (24.8607, 67.0011),
  'Peshawar': (34.0151, 71.5249),
  'Quetta': (30.1798, 66.9750),
  'Multan': (30.1575, 71.5249),
  'Faisalabad': (31.4504, 73.1350),
};
