import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/core/utils/validators.dart';

/// The rules these cover were previously duplicated per screen and had drifted:
/// login demanded a 10-digit phone while the profile editor accepted "1", and
/// a blank pincode was silently replaced with a hardcoded city.
void main() {
  group('email', () {
    test('accepts an ordinary address', () {
      expect(Validators.email('name@example.com'), isNull);
      expect(Validators.email('  name@example.co.uk  '), isNull);
    });

    test('accepts empty — email is optional', () {
      expect(Validators.email(''), isNull);
      expect(Validators.email('   '), isNull);
    });

    test('rejects what the old isNotEmpty check let through', () {
      expect(Validators.email('x'), isNotNull);
      expect(Validators.email('name@example'), isNotNull);
      expect(Validators.email('name example.com'), isNotNull);
      expect(Validators.email('@example.com'), isNotNull);
    });

    test('rejects a one-letter or numeric TLD', () {
      expect(Validators.email('a@b.c'), isNotNull);
      expect(Validators.email('a@b.1'), isNotNull);
    });

    test('catches typos in well-known domains', () {
      // The address that got through and prompted this: structurally valid,
      // but gmaol.com is nobody's mailbox.
      expect(Validators.email('sdvcghj@gmaol.com'), contains('gmail.com'));
      expect(Validators.email('x@gmial.com'), contains('gmail.com'));
      expect(Validators.email('x@gmail.co'), contains('gmail.com'));
      expect(Validators.email('x@yahooo.com'), contains('yahoo.com'));
      expect(Validators.email('x@hotmial.com'), contains('hotmail.com'));
      expect(Validators.email('x@outlok.com'), contains('outlook.com'));
    });

    test('catches a slipped-finger TLD on any domain', () {
      expect(Validators.email('x@mycompany.con'), isNotNull);
      expect(Validators.email('x@gmail.con'), isNotNull);
    });

    test('leaves real domains alone, including gmail near-neighbours', () {
      // One edit from gmail.com but genuinely deliverable — must not be
      // "corrected" into something the user never typed.
      expect(Validators.email('x@ymail.com'), isNull);
      expect(Validators.email('x@email.com'), isNull);
      expect(Validators.email('x@gmx.com'), isNull);
      // Ordinary company domains are nowhere near the known list.
      expect(Validators.email('someone@fudron.com'), isNull);
      expect(Validators.email('dev@appzeto.co'), isNull);
      expect(Validators.email('x@yahoo.co.in'), isNull);
    });
  });

  group('phone', () {
    test('accepts a 10-digit mobile, with or without +91 and spacing', () {
      expect(Validators.phone('9876543210'), isNull);
      expect(Validators.phone('+91 98765 43210'), isNull);
      expect(Validators.phone('919876543210'), isNull);
    });

    test('rejects wrong length and landline-style prefixes', () {
      expect(Validators.phone('1'), isNotNull);
      expect(Validators.phone('987654321'), isNotNull);
      expect(Validators.phone('98765432109'), isNotNull);
      expect(Validators.phone('1234567890'), isNotNull);
      expect(Validators.phone(''), isNotNull);
    });
  });

  group('pincode', () {
    test('accepts six digits', () {
      expect(Validators.pincode('452001'), isNull);
    });

    test('rejects letters, wrong length, and a leading zero', () {
      expect(Validators.pincode('abcd'), isNotNull);
      expect(Validators.pincode('45200'), isNotNull);
      expect(Validators.pincode('4520011'), isNotNull);
      expect(Validators.pincode('045200'), isNotNull);
      expect(Validators.pincode(''), isNotNull);
    });
  });

  group('name', () {
    test('needs at least two characters', () {
      expect(Validators.name('Jo'), isNull);
      expect(Validators.name('J'), isNotNull);
      expect(Validators.name('   '), isNotNull);
    });
  });
}
