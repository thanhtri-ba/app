/// Pure auth helpers (no Flutter / plugin imports) so they can be unit tested.
final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool isValidEmail(String s) => _emailRe.hasMatch(s.trim());

enum PasswordIssue { tooShort, needsLetter, needsDigit }

const int kMinPasswordLength = 8;

/// Returns the first problem with [p], or null when the password is acceptable.
/// Policy: at least 8 characters, with at least one letter and one digit.
PasswordIssue? passwordIssue(String p) {
  if (p.length < kMinPasswordLength) return PasswordIssue.tooShort;
  if (!RegExp(r'\p{L}', unicode: true).hasMatch(p)) return PasswordIssue.needsLetter;
  if (!RegExp(r'\d').hasMatch(p)) return PasswordIssue.needsDigit;
  return null;
}

String passwordIssueText(PasswordIssue i, {required bool vi}) {
  switch (i) {
    case PasswordIssue.tooShort:
      return vi ? 'Tối thiểu $kMinPasswordLength ký tự' : 'At least $kMinPasswordLength characters';
    case PasswordIssue.needsLetter:
      return vi ? 'Cần có ít nhất một chữ cái' : 'Include at least one letter';
    case PasswordIssue.needsDigit:
      return vi ? 'Cần có ít nhất một chữ số' : 'Include at least one digit';
  }
}

/// Maps a raw backend error message to something a person can act on.
/// Unknown errors get a generic text so internal details are never shown.
String friendlyAuthError(String message, {required bool vi}) {
  final m = message.toLowerCase();
  bool has(String s) => m.contains(s);

  if (has('invalid login credentials') || has('invalid credentials')) {
    return vi ? 'Email hoặc mật khẩu không đúng.' : 'Wrong email or password.';
  }
  if (has('email not confirmed')) {
    return vi
        ? 'Email chưa được xác nhận. Hãy mở thư xác nhận trong hộp thư của bạn.'
        : 'Email not confirmed yet. Open the confirmation email in your inbox.';
  }
  if (has('already registered') || has('already been registered') || has('user already exists')) {
    return vi ? 'Email này đã được đăng ký. Hãy đăng nhập.' : 'This email is already registered. Log in instead.';
  }
  if (has('rate limit') || has('too many')) {
    return vi ? 'Bạn thử quá nhiều lần. Hãy đợi vài phút rồi thử lại.' : 'Too many attempts. Wait a few minutes and try again.';
  }
  if (has('password should') || has('weak password')) {
    return vi ? 'Mật khẩu quá yếu.' : 'That password is too weak.';
  }
  if (has('socketexception') ||
      has('failed host lookup') ||
      has('clientexception') ||
      has('network') ||
      has('connection')) {
    return vi ? 'Không có kết nối mạng. Kiểm tra Wi-Fi hoặc dữ liệu di động.' : 'No network connection. Check your Wi-Fi or mobile data.';
  }
  if (has('provider is not enabled') || has('unsupported provider')) {
    return vi ? 'Cách đăng nhập này chưa được bật.' : 'This sign-in method is not enabled yet.';
  }
  return vi ? 'Có lỗi xảy ra. Hãy thử lại sau.' : 'Something went wrong. Please try again.';
}
