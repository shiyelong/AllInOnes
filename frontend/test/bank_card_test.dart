import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/common/api.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;

@GenerateMocks([http.Client])
void main() {
  group('Bank Card Validation Tests', () {
    test('Bank card number validation should work correctly', () {
      // Valid card numbers
      expect(isValidCardNumber('4111111111111111'), true); // Visa
      expect(isValidCardNumber('5555555555554444'), true); // Mastercard
      expect(isValidCardNumber('6221 8888 8888 8888 888'), false); // UnionPay - too long

      // Invalid card numbers
      expect(isValidCardNumber('411111111111'), false); // Too short
      expect(isValidCardNumber('4111111111111112'), false); // Invalid checksum
      expect(isValidCardNumber('abcdefghijklmnop'), false); // Non-numeric
    });

    test('Bank card masking should work correctly', () {
      expect(maskCardNumber('4111111111111111'), '4111 **** **** 1111');
      expect(maskCardNumber('5555555555554444'), '5555 **** **** 4444');
      expect(maskCardNumber('6221888888888888'), '6221 **** **** 8888');
    });
  });
}

// Helper functions for testing
bool isValidCardNumber(String cardNumber) {
  // Remove spaces and dashes
  cardNumber = cardNumber.replaceAll(' ', '').replaceAll('-', '');

  // Check length (most bank cards are 13-19 digits)
  if (cardNumber.length < 13 || cardNumber.length > 19) {
    return false;
  }

  // Check if all characters are digits
  if (!RegExp(r'^[0-9]+$').hasMatch(cardNumber)) {
    return false;
  }

  // Luhn algorithm validation
  return validateLuhn(cardNumber);
}

bool validateLuhn(String cardNumber) {
  int sum = 0;
  bool alternate = false;

  for (int i = cardNumber.length - 1; i >= 0; i--) {
    int digit = int.parse(cardNumber[i]);

    if (alternate) {
      digit *= 2;
      if (digit > 9) {
        digit -= 9;
      }
    }

    sum += digit;
    alternate = !alternate;
  }

  return sum % 10 == 0;
}

String maskCardNumber(String cardNumber) {
  // Remove spaces and dashes
  cardNumber = cardNumber.replaceAll(' ', '').replaceAll('-', '');

  // Keep first 4 and last 4 digits, mask the rest
  if (cardNumber.length <= 8) {
    return cardNumber;
  }

  String prefix = cardNumber.substring(0, 4);
  String suffix = cardNumber.substring(cardNumber.length - 4);
  String masked = prefix + '*' * (cardNumber.length - 8) + suffix;

  // Add a space every 4 digits for readability
  StringBuffer result = StringBuffer();
  for (int i = 0; i < masked.length; i++) {
    if (i > 0 && i % 4 == 0) {
      result.write(' ');
    }
    result.write(masked[i]);
  }

  return result.toString();
}
