import 'package:femora/models/email_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects badly shaped addresses', () {
    for (final bad in ['', 'ayesha', 'ayesha@', '@gmail.com', 'ayesha@gmail', 'a b@gmail.com', 'ayesha@@gmail.com',
        'ayesha..k@gmail.com', 'ayesha@gmail..com', 'ayesha@-gmail.com', 'ayesha@gmail.c', 'a@b.c']) {
      expect(EmailCheck.formatProblem(bad), isNotNull, reason: bad);
    }
  });

  test('catches typos, throwaway and made-up domains', () {
    expect(EmailCheck.formatProblem('ayesha@g.com'), 'Did you mean ayesha@gmail.com?');
    expect(EmailCheck.formatProblem('ayesha@gmial.com'), 'Did you mean ayesha@gmail.com?');
    expect(EmailCheck.formatProblem('ayesha@gmail.co'), 'Did you mean ayesha@gmail.com?');
    for (final d in ['gml.com', 'gmaail.com', 'gmail.cmo', 'gmali.com', 'gmail.vom']) {
      expect(EmailCheck.formatProblem('ammadsajjad055@$d'), 'Did you mean ammadsajjad055@gmail.com?', reason: d);
    }
    expect(EmailCheck.formatProblem('a@hotmil.com'), 'Did you mean a@hotmail.com?');
    expect(EmailCheck.formatProblem('a@yahho.com'), 'Did you mean a@yahoo.com?');
    expect(EmailCheck.formatProblem('a@outlok.com'), 'Did you mean a@outlook.com?');
    expect(EmailCheck.formatProblem('x@mailinator.com'), contains('Temporary'));
    expect(EmailCheck.formatProblem('x@example.com'), contains('not a real'));
    expect(EmailCheck.formatProblem('x@fake.com'), contains('not a real'));
  });

  test('accepts real addresses', () {
    for (final ok in ['ayesha@gmail.com', 'Ayesha.Khan+femora@Yahoo.com', 'student@students.au.edu.pk', 'a.b@outlook.com',
        'a@mail.com', 'a@ymail.com', 'a@live.com', 'a@hotmail.co.uk', 'a@yahoo.co.uk', 'a@gmx.com', 'a@aol.com', 'a@icloud.com']) {
      expect(EmailCheck.formatProblem(ok), isNull, reason: ok);
    }
  });

  test('a domain with no mail server is refused; an unreachable check is allowed', () async {
    final saved = EmailCheck.mailLookup;
    addTearDown(() => EmailCheck.mailLookup = saved);
    EmailCheck.mailLookup = (d) async => d == 'gmail.com' ? true : (d == 'nomail-domain.com' ? false : null);
    expect(await EmailCheck.problem('ayesha@gmail.com'), isNull);
    expect(await EmailCheck.problem('ayesha@nomail-domain.com'), contains('No email can be delivered'));
    expect(await EmailCheck.problem('ayesha@offline-check.com'), isNull); // could not check: verification email decides
  });

  test('names are letters only', () {
    for (final ok in ['Ayesha', 'Ayesha Khan', 'عائشہ', 'Zoë']) {
      expect(EmailCheck.nameProblem(ok), isNull, reason: ok);
    }
    for (final bad in ['', 'A', 'ammad@gmail.com', 'Ayesha123', 'Ayesha!', 'Ayesha_K', 'Ay  esha', 'x' * 31]) {
      expect(EmailCheck.nameProblem(bad), isNotNull, reason: bad);
    }
  });
}
