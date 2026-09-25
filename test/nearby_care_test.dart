import 'dart:convert';

import 'package:femora/models/health_store.dart';
import 'package:femora/models/places.dart';
import 'package:femora/screens/nearby_care_screen.dart';
import 'package:femora/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _response(String kind, {bool google = false, List<Map<String, dynamic>>? places}) => {
      'kind': kind,
      'source': google ? 'google' : 'openstreetmap',
      'attribution': google ? 'Ratings and reviews from Google' : 'Map data © OpenStreetMap contributors',
      'places': places ??
          [
            {
              'id': 'p1', 'name': 'PIMS Hospital', 'lat': 33.70, 'lon': 73.05, 'distance_km': 0.8, 'address': 'G-8/3',
              'phone': '051-9261170', 'maps_url': 'https://www.google.com/maps/dir/?api=1&destination=33.7,73.05',
              if (google) ...{'rating': 4.3, 'rating_count': 212, 'open_now': true, 'reviews': [{'rating': 5, 'text': 'Kind staff.', 'when': 'a week ago'}]},
            },
            {'id': 'p2', 'name': 'Poly Clinic', 'lat': 33.72, 'lon': 73.08, 'distance_km': 3.4, 'maps_url': 'https://x'},
          ],
    };

Widget _app(MockClient client, {(double, double)? location, CareKind kind = CareKind.hospital}) {
  final store = HealthStore();
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
        home: NearbyCareScreen(initialKind: kind, api: ApiService(client: client), locate: () async => location, showMap: false)),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('searches near her location and lists places nearest first with call and directions', (tester) async {
    Uri? asked;
    await tester.pumpWidget(_app(MockClient((r) async {
      asked = r.url;
      return http.Response(jsonEncode(_response(r.url.queryParameters['kind']!)), 200);
    }), location: (33.69, 73.05)));
    await tester.pumpAndSettle();
    expect(asked!.path, '/places/nearby');
    expect(asked!.queryParameters, {'kind': 'hospital', 'lat': '33.69', 'lon': '73.05'});
    expect(find.text('PIMS Hospital'), findsOneWidget);
    expect(find.text('800 m'), findsOneWidget);
    expect(find.text('3.4 km'), findsOneWidget);
    expect(find.byKey(const Key('call_p1')), findsOneWidget);
    expect(find.byKey(const Key('call_p2')), findsNothing); // no phone number known
    expect(find.byKey(const Key('directions_p2')), findsOneWidget);
    expect(find.textContaining('Ratings appear once a Google Places key'), findsOneWidget);
  });

  testWidgets('with Google, ratings, open now and reviews are shown', (tester) async {
    await tester.pumpWidget(_app(MockClient((r) async => http.Response(jsonEncode(_response('gynae', google: true)), 200)),
        location: (33.69, 73.05), kind: CareKind.gynae));
    await tester.pumpAndSettle();
    expect(find.text('4.3 (212)'), findsOneWidget);
    expect(find.text('Open now'), findsOneWidget);
    await tester.tap(find.text('Reviews'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kind staff.'), findsOneWidget);
  });

  testWidgets('switching the kind searches again', (tester) async {
    final kinds = <String>[];
    await tester.pumpWidget(_app(MockClient((r) async {
      kinds.add(r.url.queryParameters['kind']!);
      return http.Response(jsonEncode(_response(r.url.queryParameters['kind']!)), 200);
    }), location: (33.69, 73.05)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('care_lab')));
    await tester.pumpAndSettle();
    expect(kinds, ['hospital', 'lab']);
  });

  testWidgets('with location off it searches Islamabad and says so', (tester) async {
    Uri? asked;
    await tester.pumpWidget(_app(MockClient((r) async {
      asked = r.url;
      return http.Response(jsonEncode(_response('hospital')), 200);
    })));
    await tester.pumpAndSettle();
    expect(find.text('Showing Islamabad (location is off)'), findsOneWidget);
    expect(asked!.queryParameters['lat'], '33.6844');
  });

  testWidgets('few results suggest hospitals, and a server problem offers a retry', (tester) async {
    var fail = true;
    await tester.pumpWidget(_app(MockClient((r) async {
      if (fail) return http.Response(jsonEncode({'detail': 'The map search is not answering right now.'}), 502);
      return http.Response(jsonEncode(_response('imaging', places: const [])), 200);
    }), location: (33.69, 73.05), kind: CareKind.imaging));
    await tester.pumpAndSettle();
    expect(find.text('The map search is not answering right now.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Show hospitals'), findsOneWidget);
  });
}
