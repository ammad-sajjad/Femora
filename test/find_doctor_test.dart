import 'dart:convert';

import 'package:femora/models/doctors.dart';
import 'package:femora/models/health_store.dart';
import 'package:femora/screens/find_doctor_screen.dart';
import 'package:femora/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _doctor(String id, String name, {double? rating, int? count, double km = 1.0, List<Map<String, dynamic>> reviews = const []}) => {
      'id': id,
      'name': name,
      'specialty': 'Gynecologist',
      'qualifications': ['MBBS', 'FCPS'],
      'address': 'F-8 Markaz, Islamabad',
      'city': 'Islamabad',
      'lat': 33.7,
      'lon': 73.04,
      'distance_km': km,
      'phone': '0300 1234567',
      'rating': rating,
      'rating_count': count,
      'open_now': true,
      'hours': ['Monday: 5:00 - 9:00 PM'],
      'reviews': reviews,
      'maps_url': 'https://maps.google.com/?cid=1',
      'oladoc_url': 'https://www.google.com/search?q=site%3Aoladoc.com+$id',
    };

Map<String, dynamic> _response({bool google = true, List<Map<String, dynamic>>? doctors}) => {
      'specialty': 'gynae',
      'source': google ? 'google' : 'openstreetmap',
      'attribution': google ? 'Ratings, reviews and photos from Google' : 'Map data © OpenStreetMap contributors',
      'doctors': doctors ??
          [
            _doctor('d1', 'Dr. Sadia Khan', rating: 4.9, count: 3, km: 0.6),
            _doctor('d2', 'Prof. Dr. Nasreen Akhtar', rating: 4.7, count: 240, km: 5.2, reviews: [
              {'author': 'Ayesha', 'rating': 5, 'text': 'Listened patiently and explained everything.', 'when': 'a month ago'}
            ]),
          ],
    };

Widget _app(MockClient client) => ChangeNotifierProvider.value(
      value: HealthStore(),
      child: MaterialApp(home: FindDoctorScreen(api: ApiService(client: client), locate: () async => (33.69, 73.05))),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a rating from many reviews ranks above a perfect score from a few', () {
    final r = DoctorsResult.fromJson(_response());
    expect(r.sorted(DoctorSort.best).map((d) => d.id), ['d2', 'd1']);
    expect(r.sorted(DoctorSort.nearest).map((d) => d.id), ['d1', 'd2']);
    expect(r.doctors.last.initials, 'NA');
  });

  testWidgets('lists doctors near her, best rated first, and each opens a mini profile', (tester) async {
    Uri? asked;
    await tester.pumpWidget(_app(MockClient((r) async {
      asked = r.url;
      return http.Response(jsonEncode(_response()), 200);
    })));
    await tester.pumpAndSettle();
    expect(asked!.path, '/doctors/nearby');
    expect(asked!.queryParameters, {'specialty': 'gynae', 'lat': '33.69', 'lon': '73.05'});

    final first = tester.getTopLeft(find.text('Prof. Dr. Nasreen Akhtar')).dy;
    expect(first, lessThan(tester.getTopLeft(find.text('Dr. Sadia Khan')).dy));
    expect(find.text('4.7 (240)'), findsOneWidget);
    expect(find.textContaining('check PMDC registration'), findsOneWidget);

    expect(find.byKey(const Key('sort_experience')), findsNothing); // Google has no years of experience
    await tester.tap(find.byKey(const Key('sort_nearest')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Dr. Sadia Khan')).dy, lessThan(tester.getTopLeft(find.text('Prof. Dr. Nasreen Akhtar')).dy));

    await tester.tap(find.byKey(const Key('doctor_d2')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorProfileScreen), findsOneWidget);
    expect(find.text('Listened patiently and explained everything.'), findsOneWidget);
    expect(find.text('Ayesha'), findsOneWidget);
    expect(find.text('MBBS'), findsOneWidget);
    expect(find.byKey(const Key('doctor_call')), findsOneWidget);
    expect(find.byKey(const Key('doctor_oladoc')), findsOneWidget);
  });

  testWidgets('Oladoc doctors show PMDC, experience and fee, sort by experience, and each clinic can be booked', (tester) async {
    Map<String, dynamic> ola(String id, String name, int years, int fee) => {
          ..._doctor(id, name, rating: 4.8, count: 900),
          'phone': null,
          'open_now': null,
          'hours': <String>[],
          'experience_years': years,
          'wait_time': 'Under 15 Min',
          'pmdc_verified': true,
          'fee': fee,
          'profile_url': 'https://oladoc.com/pakistan/islamabad/dr/gynecologist/$id/1',
          'oladoc_url': 'https://oladoc.com/pakistan/islamabad/dr/gynecologist/$id/1',
          'clinics': [
            {'name': 'Kulsum International Hospital', 'area': 'Blue Area', 'fee': fee, 'available': 'Available tomorrow', 'booking_url': 'https://oladoc.com/appointment/9/$id'},
            {'name': 'Online Video Consultation', 'fee': fee - 500, 'available': 'Online', 'booking_url': 'https://oladoc.com/appointment/8/$id'},
          ],
        };
    await tester.pumpWidget(_app(MockClient((r) async => http.Response(
        jsonEncode({
          'specialty': 'gynae',
          'source': 'oladoc',
          'attribution': "Doctor listings, ratings and fees from oladoc.com, used with Oladoc's permission",
          'doctors': [ola('saira', 'Prof. Dr. Saira Afghan', 39, 3500), ola('armghana', 'Dr. Armghana Ali', 16, 3000)],
        }),
        200))));
    await tester.pumpAndSettle();
    expect(find.text('39 yrs exp'), findsOneWidget);
    expect(find.text('Rs. 3,500'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsNWidgets(2));
    expect(find.textContaining("used with Oladoc's permission"), findsOneWidget);

    await tester.tap(find.byKey(const Key('sort_fee')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('16 yrs exp')).dy, lessThan(tester.getTopLeft(find.text('39 yrs exp')).dy));
    await tester.tap(find.byKey(const Key('sort_experience')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('39 yrs exp')).dy, lessThan(tester.getTopLeft(find.text('16 yrs exp')).dy));

    await tester.tap(find.byKey(const Key('doctor_saira')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doctor_pmdc')), findsOneWidget);
    expect(find.byKey(const Key('doctor_book')), findsOneWidget);
    expect(find.byKey(const Key('doctor_call')), findsNothing); // Oladoc lists no direct number
    expect(find.text('Kulsum International Hospital'), findsOneWidget);
    expect(find.text('Available tomorrow'), findsOneWidget);
    expect(find.text('Rs. 3,000'), findsOneWidget); // the online consultation
    expect(find.byKey(const Key('book_https://oladoc.com/appointment/9/saira')), findsOneWidget);
    expect(find.textContaining('from 900 patient reviews on Oladoc'), findsOneWidget);
    expect(find.byKey(const Key('doctor_read_reviews')), findsOneWidget);
  });

  testWidgets('choosing another specialty searches again', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(_app(MockClient((r) async {
      asked.add(r.url.queryParameters['specialty']!);
      return http.Response(jsonEncode(_response()), 200);
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('specialty_endocrine')));
    await tester.pumpAndSettle();
    expect(asked, ['gynae', 'endocrine']);
  });

  testWidgets('without Google the screen explains that ratings need a key, and still offers Oladoc', (tester) async {
    await tester.pumpWidget(_app(MockClient((r) async => http.Response(jsonEncode(_response(google: false, doctors: [])), 200))));
    await tester.pumpAndSettle();
    expect(find.textContaining('on Oladoc: each profile shows experience'), findsOneWidget);
    expect(find.byKey(const Key('oladoc_more')), findsOneWidget);
  });

  test('Oladoc listing pages are built for each specialty and the nearest city', () {
    expect(oladocListing(DoctorSpecialty.gynae, 'Islamabad'), 'https://oladoc.com/pakistan/islamabad/gynecologist');
    expect(oladocListing(DoctorSpecialty.fertility, 'Lahore'), 'https://oladoc.com/pakistan/lahore/fertility-consultant');
    expect(nearestCity((33.60, 73.03)), 'Rawalpindi');
    expect(nearestCity((24.9, 67.1)), 'Karachi');
  });
}
