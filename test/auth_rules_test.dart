import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/core/auth_rules.dart';

void main() {
  group('isValidEmail', () {
    test('accepts normal emails and trims spaces', () {
      expect(isValidEmail('a@b.co'), isTrue);
      expect(isValidEmail('  name.surname+tag@example.com '), isTrue);
    });
    test('rejects broken ones', () {
      for (final s in ['', 'abc', 'a@b', '@b.com', 'a b@c.com', 'a@b@c.com']) {
        expect(isValidEmail(s), isFalse, reason: s);
      }
    });
  });

  group('passwordIssue', () {
    test('too short', () => expect(passwordIssue('abc12'), PasswordIssue.tooShort));
    test('exactly 8 with letter and digit is fine', () => expect(passwordIssue('abcdef12'), isNull));
    test('needs a letter', () => expect(passwordIssue('12345678'), PasswordIssue.needsLetter));
    test('needs a digit', () => expect(passwordIssue('abcdefgh'), PasswordIssue.needsDigit));
    test('accepts Vietnamese letters', () => expect(passwordIssue('mậtkhẩu1'), isNull));
    test('messages exist in both languages', () {
      for (final i in PasswordIssue.values) {
        expect(passwordIssueText(i, vi: true), isNotEmpty);
        expect(passwordIssueText(i, vi: false), isNotEmpty);
      }
    });
  });

  group('friendlyAuthError', () {
    test('wrong credentials', () {
      expect(friendlyAuthError('Invalid login credentials', vi: true), contains('không đúng'));
      expect(friendlyAuthError('Invalid login credentials', vi: false), contains('Wrong'));
    });
    test('unconfirmed email', () {
      expect(friendlyAuthError('Email not confirmed', vi: true), contains('xác nhận'));
    });
    test('already registered', () {
      expect(friendlyAuthError('User already registered', vi: true), contains('đã được đăng ký'));
    });
    test('rate limit', () {
      expect(friendlyAuthError('email rate limit exceeded', vi: true), contains('quá nhiều'));
    });
    test('network', () {
      expect(friendlyAuthError('SocketException: Failed host lookup', vi: true), contains('kết nối mạng'));
    });
    test('unknown errors never leak the raw message', () {
      final t = friendlyAuthError('PGRST301 internal: secret detail 42', vi: false);
      expect(t.contains('secret'), isFalse);
      expect(t.contains('PGRST'), isFalse);
    });
  });
}
