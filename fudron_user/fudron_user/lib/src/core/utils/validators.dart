/// Shared input rules.
///
/// These live here rather than inline in each screen because the same field
/// shows up in several places — a phone number is entered at login and edited
/// again in the profile — and when the rules were duplicated they drifted:
/// login demanded 10 digits while the profile editor accepted a single one.
class Validators {
  Validators._();

  /// Deliberately loose on the local part — one @, no spaces — but the TLD has
  /// to be at least two letters, so `a@b.c` and `a@b.1` are rejected. Anything
  /// stricter on the local part starts rejecting addresses that really do
  /// deliver.
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$');

  /// Mail domains typed often enough that a near-miss is a typo rather than a
  /// real address. Includes the legitimate near-neighbours (ymail, email, gmx)
  /// so they match exactly here and never get "corrected" into something else.
  static const List<String> _knownDomains = [
    'gmail.com', 'googlemail.com', 'yahoo.com', 'yahoo.co.in', 'yahoo.in',
    'ymail.com', 'hotmail.com', 'hotmail.co.uk', 'outlook.com', 'outlook.in',
    'live.com', 'msn.com', 'icloud.com', 'me.com', 'mac.com', 'aol.com',
    'rediffmail.com', 'protonmail.com', 'proton.me', 'zoho.com', 'zohomail.in',
    'email.com', 'mail.com', 'gmx.com', 'yandex.com', 'fastmail.com',
    'hey.com', 'qq.com', '163.com',
  ];

  /// TLDs that are only ever a slipped finger on `.com`. `.co` is excluded —
  /// it is a real TLD, and `gmail.co` is already caught as a near-miss below.
  static const List<String> _badTlds = ['con', 'cmo', 'vom', 'xom', 'comm', 'ocm', 'cim', 'som'];

  /// Returns an error message, or null when [value] is a usable email.
  /// Empty is allowed — email is optional; callers requiring it check first.
  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    if (!_email.hasMatch(v)) return 'Please enter a valid email address';

    // A regex only proves the address is well-formed. "gmaol.com" is a
    // perfectly legal domain, so shape alone accepts it and the typo reaches
    // the account — where a wrong address means order receipts and password
    // resets go nowhere, silently.
    final domain = v.split('@').last.toLowerCase();
    if (_knownDomains.contains(domain)) return null;

    if (_badTlds.contains(domain.split('.').last)) {
      return 'Did you mean .com? Please check your email address';
    }

    for (final known in _knownDomains) {
      if (_editDistance(domain, known) <= 2) {
        return 'Did you mean $known? Please check your email address';
      }
    }
    return null;
  }

  /// Levenshtein distance, two rows rather than a full matrix.
  ///
  /// ponytail: O(n*m) over a ~29-entry domain list, run per keystroke-free
  /// submit. Fine at this size; index by first letter if the list ever grows.
  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > 2) return 3; // over threshold, stop early
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final curr = List<int>.filled(b.length + 1, 0);
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
      }
      prev = curr;
    }
    return prev[b.length];
  }

  /// Indian mobile: 10 digits starting 6-9, ignoring any +91 the user pasted.
  static String? phone(String value) {
    final digits = digitsOf(value);
    final local = digits.length == 12 && digits.startsWith('91')
        ? digits.substring(2)
        : digits;
    if (local.length != 10 || !RegExp(r'^[6-9]').hasMatch(local)) {
      return 'Please enter a valid 10-digit mobile number';
    }
    return null;
  }

  /// Indian PIN: exactly 6 digits, never starting with 0.
  static String? pincode(String value) {
    final digits = digitsOf(value);
    if (digits.length != 6 || digits.startsWith('0')) {
      return 'Please enter a valid 6-digit pincode';
    }
    return null;
  }

  static String? name(String value) =>
      value.trim().length < 2 ? 'Please enter your full name' : null;

  static String digitsOf(String value) => value.replaceAll(RegExp(r'\D'), '');
}
