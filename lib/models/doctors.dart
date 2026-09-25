/// Find a doctor: what the server's /doctors/nearby returns.
enum DoctorSpecialty { gynae, breast, endocrine, fertility }

enum DoctorSort { best, nearest, experience, fee, reviews }

enum DoctorSource { google, oladoc, openstreetmap }

class DoctorReview {
  final String author;
  final double? rating;
  final String text;
  final String when;
  const DoctorReview({this.author = '', this.rating, required this.text, this.when = ''});

  factory DoctorReview.fromJson(Map<String, dynamic> j) => DoctorReview(
      author: (j['author'] as String?) ?? '', rating: (j['rating'] as num?)?.toDouble(), text: j['text'] as String, when: (j['when'] as String?) ?? '');
}

/// Where she can see the doctor (Oladoc): a hospital or clinic, or an online video consultation.
class DoctorClinic {
  final String name;
  final String area;
  final int? fee; // rupees
  final String available; // "Available tomorrow"
  final String bookingUrl;
  const DoctorClinic({required this.name, this.area = '', this.fee, this.available = '', required this.bookingUrl});

  factory DoctorClinic.fromJson(Map<String, dynamic> j) => DoctorClinic(
      name: j['name'] as String,
      area: (j['area'] as String?) ?? '',
      fee: (j['fee'] as num?)?.toInt(),
      available: (j['available'] as String?) ?? '',
      bookingUrl: j['booking_url'] as String);

  bool get online => name.toLowerCase().contains('online');
}

class Doctor {
  final String id;
  final String name;
  final String specialty;
  final List<String> qualifications;
  final String about;
  final String address;
  final String city;
  final double lat;
  final double lon;
  final double? distanceKm; // null: no clinic location known (online consultations only)
  final int? experienceYears;
  final String waitTime;
  final bool pmdcVerified;
  final int? fee; // the lowest consultation fee, rupees
  final List<DoctorClinic> clinics;
  final String? profileUrl;
  final String? phone;
  final String? website;
  final double? rating;
  final int? ratingCount;
  final bool? openNow;
  final List<String> hours;
  final List<DoctorReview> reviews;
  final String? photo; // a reference for /doctors/photo
  final String photoCredit;
  final String mapsUrl;
  final String oladocUrl;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    this.qualifications = const [],
    this.about = '',
    this.address = '',
    this.city = '',
    required this.lat,
    required this.lon,
    this.distanceKm,
    this.experienceYears,
    this.waitTime = '',
    this.pmdcVerified = false,
    this.fee,
    this.clinics = const [],
    this.profileUrl,
    this.phone,
    this.website,
    this.rating,
    this.ratingCount,
    this.openNow,
    this.hours = const [],
    this.reviews = const [],
    this.photo,
    this.photoCredit = '',
    required this.mapsUrl,
    required this.oladocUrl,
  });

  factory Doctor.fromJson(Map<String, dynamic> j) => Doctor(
        id: j['id'] as String,
        name: j['name'] as String,
        specialty: j['specialty'] as String,
        qualifications: [for (final q in (j['qualifications'] as List?) ?? const []) q as String],
        about: (j['about'] as String?) ?? '',
        address: (j['address'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        experienceYears: (j['experience_years'] as num?)?.toInt(),
        waitTime: (j['wait_time'] as String?) ?? '',
        pmdcVerified: (j['pmdc_verified'] as bool?) ?? false,
        fee: (j['fee'] as num?)?.toInt(),
        clinics: [for (final c in (j['clinics'] as List?) ?? const []) DoctorClinic.fromJson(c as Map<String, dynamic>)],
        profileUrl: j['profile_url'] as String?,
        phone: j['phone'] as String?,
        website: j['website'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: (j['rating_count'] as num?)?.toInt(),
        openNow: j['open_now'] as bool?,
        hours: [for (final h in (j['hours'] as List?) ?? const []) h as String],
        reviews: [for (final r in (j['reviews'] as List?) ?? const []) DoctorReview.fromJson(r as Map<String, dynamic>)],
        photo: j['photo'] as String?,
        photoCredit: (j['photo_credit'] as String?) ?? '',
        mapsUrl: j['maps_url'] as String,
        oladocUrl: j['oladoc_url'] as String,
      );

  /// She only consults online (no clinic of hers is near the searched city).
  bool get onlineOnly => distanceKm == null && clinics.isNotEmpty && clinics.every((c) => c.online);

  String get distanceText {
    final d = distanceKm;
    if (d == null) return onlineOnly ? 'Online' : (city.isEmpty ? '–' : city); // a clinic without a map location: her city
    return d < 1 ? '${(d * 1000).round()} m' : '${d.toStringAsFixed(1)} km';
  }

  /// "Rs. 1,500" (the lowest of her fees).
  String? get feeText => fee == null ? null : 'Rs. ${fee.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  /// "SK" for "Dr. Sadia Khan": the titles are skipped.
  String get initials {
    final words = name
        .replaceAll(RegExp(r'\b(assoc(iate)?|asst|assistant|prof(essor)?|dr|doctor)\b\.?', caseSensitive: false), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0]))
        .toList();
    if (words.isEmpty) return 'Dr';
    return (words.first[0] + (words.length > 1 ? words.last[0] : '')).toUpperCase();
  }

  /// A rating backed by many reviews counts for more than a perfect score from two (the server ranks the same way).
  double get confidentRating => rating == null ? 0 : (rating! * (ratingCount ?? 0) + 4.2 * 8) / ((ratingCount ?? 0) + 8);
}

class DoctorsResult {
  final DoctorSpecialty specialty;
  final DoctorSource source;
  final String attribution;
  final List<Doctor> doctors;
  const DoctorsResult({required this.specialty, required this.source, required this.attribution, required this.doctors});

  bool get fromGoogle => source == DoctorSource.google;
  bool get hasRatings => source != DoctorSource.openstreetmap; // the free map has none

  factory DoctorsResult.fromJson(Map<String, dynamic> j) => DoctorsResult(
        specialty: DoctorSpecialty.values.byName(j['specialty'] as String),
        source: DoctorSource.values.byName(j['source'] as String),
        attribution: j['attribution'] as String,
        doctors: [for (final d in j['doctors'] as List) Doctor.fromJson(d as Map<String, dynamic>)],
      );

  List<Doctor> sorted(DoctorSort by) {
    final list = [...doctors];
    switch (by) {
      case DoctorSort.best:
        list.sort((a, b) =>
            b.confidentRating != a.confidentRating ? b.confidentRating.compareTo(a.confidentRating) : (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));
      case DoctorSort.nearest:
        list.sort((a, b) => (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));
      case DoctorSort.experience:
        list.sort((a, b) => (b.experienceYears ?? -1).compareTo(a.experienceYears ?? -1));
      case DoctorSort.fee:
        list.sort((a, b) => (a.fee ?? 1 << 30).compareTo(b.fee ?? 1 << 30));
      case DoctorSort.reviews:
        list.sort((a, b) => (b.ratingCount ?? 0).compareTo(a.ratingCount ?? 0));
    }
    return list;
  }
}
