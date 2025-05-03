import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:geolocator/geolocator.dart';

@GenerateMocks([Geolocator])
void main() {
  group('Location Sharing Tests', () {
    test('Location formatting should work correctly', () {
      // Test address formatting
      final address = formatAddress({
        'street': 'Main St',
        'subLocality': 'Downtown',
        'locality': 'City',
        'administrativeArea': 'State',
        'country': 'Country'
      });
      
      expect(address, 'Main St, Downtown, City, State, Country');
    });
    
    test('Remaining time calculation should work correctly', () {
      // Test remaining time calculation for live location sharing
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final startTime = now - 60; // Started 1 minute ago
      final duration = 5; // 5 minutes duration
      
      final remainingSeconds = calculateRemainingTime(startTime, duration);
      final isExpired = isLocationSharingExpired(startTime, duration);
      
      // Should have about 4 minutes remaining
      expect(remainingSeconds, greaterThan(230));
      expect(remainingSeconds, lessThan(250));
      expect(isExpired, false);
      
      // Test expired location sharing
      final oldStartTime = now - 600; // Started 10 minutes ago
      final oldDuration = 5; // 5 minutes duration
      
      final oldRemainingSeconds = calculateRemainingTime(oldStartTime, oldDuration);
      final oldIsExpired = isLocationSharingExpired(oldStartTime, oldDuration);
      
      expect(oldRemainingSeconds, lessThan(0));
      expect(oldIsExpired, true);
    });
  });
}

// Helper functions for testing
String formatAddress(Map<String, String> placemarkData) {
  return '${placemarkData['street']}, ${placemarkData['subLocality']}, ${placemarkData['locality']}, ${placemarkData['administrativeArea']}, ${placemarkData['country']}';
}

int calculateRemainingTime(int startTime, int durationMinutes) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final endTime = startTime + (durationMinutes * 60);
  return endTime - now;
}

bool isLocationSharingExpired(int startTime, int durationMinutes) {
  return calculateRemainingTime(startTime, durationMinutes) <= 0;
}
