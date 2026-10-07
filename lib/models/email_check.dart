import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Checks an email address before an account is made with it: the shape, common typos of big providers,
/// throwaway inboxes, reserved test domains, and (online) whether the domain can receive mail at all.
/// The real proof is still the verification link or code sent to the address; this stops the obvious fakes early.
class EmailCheck {
  EmailCheck._();

  // local@domain.tld: no spaces, no double dots, labels of letters/digits/hyphens, a top-level domain of 2+ letters.
  static final _shape = RegExp(
      r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,24}$");

  /// Misspellings of the providers most people in Pakistan use, mapped to what they meant.
  static const _typos = {
    'gmial.com': 'gmail.com', 'gmal.com': 'gmail.com', 'gamil.com': 'gmail.com', 'gmai.com': 'gmail.com',
    'gmil.com': 'gmail.com', 'gmaill.com': 'gmail.com', 'gnail.com': 'gmail.com', 'gmail.co': 'gmail.com',
    'gmail.con': 'gmail.com', 'gmail.cm': 'gmail.com', 'gmail.om': 'gmail.com', 'gmail.comm': 'gmail.com',
    'gmail.pk': 'gmail.com', 'g.com': 'gmail.com', 'gm.com': 'gmail.com', 'gmail.c': 'gmail.com',
    'yaho.com': 'yahoo.com', 'yahooo.com': 'yahoo.com', 'yahoo.co': 'yahoo.com', 'yahoo.con': 'yahoo.com',
    'hotmial.com': 'hotmail.com', 'hotmal.com': 'hotmail.com', 'hotmail.co': 'hotmail.com', 'hotmail.con': 'hotmail.com',
    'outlok.com': 'outlook.com', 'outloo.com': 'outlook.com', 'outlook.co': 'outlook.com', 'outlook.con': 'outlook.com',
    'iclod.com': 'icloud.com', 'icloud.co': 'icloud.com',
  };

  /// Throwaway inboxes that anyone can read: an account made with one proves nothing about the person.
  static const _disposable = {
    'mailinator.com', 'yopmail.com', 'guerrillamail.com', 'guerrillamail.net', 'sharklasers.com', '10minutemail.com',
    'tempmail.com', 'temp-mail.org', 'tempmail.net', 'throwawaymail.com', 'trashmail.com', 'getnada.com', 'nada.email',
    'dispostable.com', 'fakeinbox.com', 'maildrop.cc', 'mintemail.com', 'mohmal.com', 'emailondeck.com', 'tempr.email',
    'discard.email', 'spamgourmet.com', 'mailnesia.com', 'mytemp.email', 'tempinbox.com', 'burnermail.io', 'moakt.com',
  };

  /// The big providers, and real providers whose names happen to sit close to them (so they are not "corrected").
  static const _providers = ['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'icloud.com'];
  static const _realLookalikes = {
    'mail.com', 'email.com', 'ymail.com', 'gmx.com', 'live.com', 'msn.com', 'aol.com', 'me.com', 'mac.com',
    'proton.me', 'protonmail.com', 'pm.me', 'zoho.com', 'yandex.com', 'rocketmail.com', 'hey.com', 'fastmail.com',
  };
  static const _comTypos = {'co', 'con', 'cm', 'om', 'comm', 'cmo', 'cpm', 'vom', 'xom', 'cim', 'coom', 'c'};

  /// Edit distance (insertions, deletions, substitutions) between two short strings.
  static int _distance(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = <int>[i];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur.add([prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y));
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// The big provider [domain] is a misspelling of (gml.com, gmaail.com, hotmil.com, gmail.cmo...), or null.
  /// Such lookalike domains are often registered by others with real mail servers, so the DNS check alone misses them.
  static String? lookalikeOf(String domain) {
    if (_providers.contains(domain) || _realLookalikes.contains(domain)) return null;
    final dot = domain.lastIndexOf('.');
    if (dot <= 0) return null;
    final name = domain.substring(0, dot), tld = domain.substring(dot + 1);
    for (final provider in _providers) {
      final pName = provider.substring(0, provider.indexOf('.'));
      if (name == pName && _comTypos.contains(tld)) return provider; // gmail.cmo
      if (name.length >= 3 && name != pName && _distance(name, pName) <= 2 && (tld == 'com' || _comTypos.contains(tld))) {
        return provider; // gml.com, gmaail.com, hotmil.com
      }
      if (_distance(domain, provider) <= 2 && domain != provider) return provider;
    }
    return null;
  }

  /// Domains reserved for examples and tests, or obviously made up.
  static const _reserved = {
    'example.com', 'example.org', 'example.net', 'test.com', 'fake.com', 'fakemail.com', 'email.test', 'domain.com',
    'abc.com', 'xyz.com', 'asdf.com', 'qwerty.com', 'mail.com.com', 'localhost',
  };
  static const _reservedTlds = {'test', 'example', 'invalid', 'localhost', 'local'};

  /// What is wrong with [raw] on its own (no network), or null when it looks like a real address.
  static String? formatProblem(String? raw) {
    final email = (raw ?? '').trim().toLowerCase();
    if (email.isEmpty) return 'Please enter your email address.';
    if (email.length > 254 || !_shape.hasMatch(email)) return 'Please enter a valid email address, like name@gmail.com.';
    final domain = email.split('@').last;
    final fix = _typos[domain] ?? lookalikeOf(domain);
    if (fix != null) return 'Did you mean ${email.split('@').first}@$fix?';
    if (_disposable.contains(domain)) return 'Temporary email addresses cannot be used. Please use your own email.';
    if (_reserved.contains(domain) || _reservedTlds.contains(domain.split('.').last)) {
      return 'That is not a real email address. Please use your own email.';
    }
    return null;
  }

  /// A plain name: letters (any alphabet, so Urdu works) and single spaces, 2 to 30 characters. No digits, emails or symbols.
  static final _name = RegExp(r"^\p{L}[\p{L}\p{M}]*( [\p{L}\p{M}]+)*$", unicode: true);
  static final nameCharacters = RegExp(r"[\p{L}\p{M} ]", unicode: true);

  static String? nameProblem(String? raw) {
    final name = (raw ?? '').trim();
    if (name.isEmpty) return 'Please tell me what to call you.';
    if (name.length < 2) return 'Please enter at least 2 letters.';
    if (name.length > 30) return 'Please keep your name under 30 letters.';
    if (!_name.hasMatch(name)) return 'Please use letters only, without numbers or symbols.';
    return null;
  }

  /// Asks DNS whether the domain has a mail server. True or false, or null when it could not be checked
  /// (no internet, timeout): then the address is allowed and the verification email decides.
  static Future<bool?> Function(String domain) mailLookup = _lookupMx;

  static Future<bool?> _lookupMx(String domain) async {
    try {
      final res = await http
          .get(Uri.https('dns.google', '/resolve', {'name': domain, 'type': 'MX'}))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['Status'] == 3) return false; // the domain does not exist
      if (json['Status'] != 0) return null;
      final answers = (json['Answer'] as List?) ?? const [];
      // A real mail server, not the "null MX" record (0 .) that says the domain takes no mail.
      return answers.any((a) => a is Map && a['type'] == 15 && (a['data'] as String? ?? '').trim() != '0 .');
    } catch (_) {
      return null;
    }
  }

  /// Full check: format first, then whether the domain can receive email.
  static Future<String?> problem(String? raw) async {
    final format = formatProblem(raw);
    if (format != null) return format;
    final domain = raw!.trim().toLowerCase().split('@').last;
    if (await mailLookup(domain) == false) {
      return 'No email can be delivered to @$domain. Please check the address.';
    }
    return null;
  }
}
