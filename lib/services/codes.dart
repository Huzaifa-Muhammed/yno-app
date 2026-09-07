import 'dart:math';

const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous 0/O/1/I

final _rng = Random();

/// A short human-friendly code (match codes, referral codes).
String randomCode([int length = 6]) => String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => _alphabet.codeUnitAt(_rng.nextInt(_alphabet.length)),
      ),
    );
