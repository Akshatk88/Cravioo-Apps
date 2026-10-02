import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/data/models/restaurant_model.dart';

/// distanceKm is only populated when the request carried the user's lat/lng, so
/// the app keeps the restaurant's own coordinates to measure with when it did
/// not. Shapes here are what the live API actually returns.
void main() {
  Map<String, dynamic> base(Map<String, dynamic> extra) => {
        '_id': 'r1',
        'restaurantName': 'okok',
        'rating': 5.0,
        ...extra,
      };

  group('restaurant coordinates', () {
    test('reads a location map with latitude/longitude', () {
      final r = RestaurantModel.fromApi(base({
        'location': {
          'latitude': 18.7893671,
          'longitude': 78.9185345,
          'coordinates': [78.9185345, 18.7893671],
        },
      }));
      expect(r.latitude, closeTo(18.7893671, 1e-9));
      expect(r.longitude, closeTo(78.9185345, 1e-9));
    });

    test('falls back to GeoJSON coordinates, which are [lng, lat]', () {
      final r = RestaurantModel.fromApi(base({
        'location': {
          'coordinates': [76.44337099045515, 21.74111955557781],
        },
      }));
      // Latitude is the second element — swapping them puts Indore in Somalia.
      expect(r.latitude, closeTo(21.74111955557781, 1e-9));
      expect(r.longitude, closeTo(76.44337099045515, 1e-9));
    });

    test('is null when the backend sent no usable location', () {
      expect(RestaurantModel.fromApi(base({})).latitude, isNull);
      expect(RestaurantModel.fromApi(base({'location': 'Vijay Nagar, Indore'})).latitude, isNull);
      expect(RestaurantModel.fromApi(base({'location': {'coordinates': []}})).latitude, isNull);
    });
  });

  group('distanceKm', () {
    test('is taken from the backend when it measured one', () {
      final r = RestaurantModel.fromApi(base({'distanceInKm': 540.57}));
      expect(r.distanceKm, closeTo(540.57, 1e-9));
    });

    test('is 0 when the request carried no coordinates', () {
      // The case behind "0.0 km" on screen: absent, not zero, from the server.
      expect(RestaurantModel.fromApi(base({})).distanceKm, 0.0);
    });

    test('survives a local round trip through toJson', () {
      final r = RestaurantModel.fromApi(base({
        'distanceInKm': 12.5,
        'location': {'latitude': 22.7196, 'longitude': 75.8577},
      }));
      final back = RestaurantModel.fromJson(r.toJson());
      expect(back.distanceKm, closeTo(12.5, 1e-9));
      expect(back.latitude, closeTo(22.7196, 1e-9));
      expect(back.longitude, closeTo(75.8577, 1e-9));
    });
  });
}
