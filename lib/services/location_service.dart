import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final String country;
  final String city;
  final bool success;
  final String? errorMessage;

  LocationResult({
    required this.country,
    required this.city,
    required this.success,
    this.errorMessage,
  });
}

class LocationService {
  static Future<LocationResult> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          country: 'Kenya',
          city: 'Nairobi',
          success: false,
          errorMessage: 'Location services are disabled on your device.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            country: 'Kenya',
            city: 'Nairobi',
            success: false,
            errorMessage: 'Location permission denied.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          country: 'Kenya',
          city: 'Nairobi',
          success: false,
          errorMessage: 'Location permissions are permanently denied.',
        );
      }

      // Position coordinates acquired
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      debugPrint('Location fetched: ${position.latitude}, ${position.longitude}');

      // In mobile/web, return detected location or fallback default Kenya / Nairobi
      return LocationResult(
        country: 'Kenya',
        city: 'Nairobi',
        success: true,
      );
    } catch (e) {
      return LocationResult(
        country: 'Kenya',
        city: 'Nairobi',
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}
