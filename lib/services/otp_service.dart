import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../l10n/l10n.dart';
import 'auth_repository.dart';

/// Base URL of the YNO email-OTP Worker (see `server/`).
///
/// Firebase Auth cannot send a 6-digit code — only sign-in links — so claiming
/// an auto-created account goes through this service instead.
///
/// Deployed 2026-08-20 to Cloudflare Workers, account `huzm651@gmail.com`.
/// `wrangler deploy` from `server/` prints this URL and redeploys in place, so
/// it only changes if the Worker or the account's workers.dev subdomain is
/// renamed.
const kOtpServiceUrl = 'https://yno-otp.yno-otp-server.workers.dev';

/// A failure the user should be told about, already localised.
class OtpException implements Exception {
  OtpException(this.code, this.message, {this.retryAfter, this.attemptsLeft});

  /// Stable machine-readable code from the service: `invalid_request`,
  /// `not_claimable`, `rate_limited`, `invalid_code`, `code_expired`,
  /// `too_many_attempts`, `server_error`, or `network` when the request never
  /// landed.
  final String code;
  final String message;
  final int? retryAfter;
  final int? attemptsLeft;

  @override
  String toString() => 'OtpException($code): $message';
}

/// Claim-your-account over email OTP.
///
/// Flow: [requestOtp] confirms a host-created account exists for the address and
/// mails a 6-digit code, then [verifyAndSignIn] checks it and signs the player
/// in silently. See the warning on [verifyAndSignIn] for what the OTP does and
/// does not protect.
class OtpService {
  OtpService._();
  static final OtpService instance = OtpService._();

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path) => Uri.parse('$kOtpServiceUrl$path');

  /// Confirm a host-created account exists for [email] and mail a code.
  ///
  /// Throws [OtpException] with code `not_claimable` when there is no such
  /// account — either the address is unknown or it belongs to a real account
  /// that already has its own password.
  Future<void> requestOtp(String email) async {
    final res = await _post('/request-otp', {'email': email.trim()});
    if (res['ok'] != true) throw _error(res);
  }

  /// Verify [code] and sign the player in silently.
  ///
  /// Returns the uid. Throws [OtpException] on a bad/expired code and
  /// [FirebaseAuthException] if the sign-in itself is rejected.
  ///
  /// ⚠️ **Signs in with [kAutoAccountPassword], not the custom token the
  /// service returns** — a product decision (2026-08-18). The consequence is
  /// that `email + 123456` also still works on the normal login screen, so the
  /// OTP guards this path only. The service keeps returning a token so that
  /// closing that gap later is a one-line change here plus randomising
  /// [kAutoAccountPassword]; nothing server-side has to move.
  Future<String> verifyAndSignIn(String email, String code) async {
    final res = await _post('/verify-otp', {
      'email': email.trim(),
      'code': code.trim(),
    });
    if (res['ok'] != true) throw _error(res);
    final cred = await AuthRepository.instance.signIn(
      email: email.trim(),
      password: kAutoAccountPassword,
    );
    return cred.user!.uid;
  }

  /// Mail a code that will authorise deleting the signed-in account.
  ///
  /// Sends the current Firebase **ID token** alongside the address. The
  /// service refuses the request without it, and refuses it if the token
  /// belongs to a different account — an OTP on its own must never be enough
  /// to destroy an account, and without the token this endpoint would let a
  /// stranger fire "your account is being deleted" mail at any address.
  Future<void> requestDeletionOtp() async {
    final user = AuthRepository.instance.currentUser;
    final email = user?.email?.trim() ?? '';
    if (user == null || email.isEmpty) {
      throw OtpException('unauthorised', tr('auth.otpErrUnauthorised'));
    }
    final idToken = await _idToken(user);
    final res = await _post('/request-otp', {
      'email': email,
      'purpose': 'delete',
      'idToken': idToken,
    });
    if (res['ok'] != true) throw _error(res);
  }

  /// Verify [code] and permanently delete the account.
  ///
  /// The deletion happens **server-side**, with admin credentials. Doing it
  /// from the client would mean `FirebaseAuth.currentUser.delete()`, which
  /// fails with `requires-recent-login` for anyone who has not signed in in
  /// the last few minutes — i.e. almost everybody, and only at the very last
  /// step, after they have already confirmed and waited out the countdown.
  ///
  /// Signs out afterwards: the account is gone, so the cached session is a
  /// credential for something that no longer exists.
  Future<void> verifyAndDeleteAccount(String code) async {
    final user = AuthRepository.instance.currentUser;
    final email = user?.email?.trim() ?? '';
    if (user == null || email.isEmpty) {
      throw OtpException('unauthorised', tr('auth.otpErrUnauthorised'));
    }
    final idToken = await _idToken(user);
    final res = await _post('/verify-otp', {
      'email': email,
      'code': code.trim(),
      'purpose': 'delete',
      'idToken': idToken,
    });
    if (res['ok'] != true) throw _error(res);
    await AuthRepository.instance.signOut();
  }

  /// A fresh ID token. `forceRefresh` because a cached one can be up to an
  /// hour old, and the service rejects anything Google will not vouch for.
  Future<String> _idToken(User user) async {
    try {
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw OtpException('unauthorised', tr('auth.otpErrUnauthorised'));
      }
      return token;
    } on OtpException {
      rethrow;
    } catch (_) {
      throw OtpException('unauthorised', tr('auth.otpErrUnauthorised'));
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, String> body) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri(path),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw OtpException('network', tr('auth.otpErrNetwork'));
    } catch (_) {
      throw OtpException('network', tr('auth.otpErrNetwork'));
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fall through — a non-JSON body means the Worker is down or misrouted.
    }
    throw OtpException('server_error', tr('auth.otpErrGeneric'));
  }

  /// Map the service's error code onto a localised message. The server's own
  /// English `message` is a fallback, never what we show when we have a key.
  OtpException _error(Map<String, dynamic> res) {
    final code = (res['error'] as String?) ?? 'server_error';
    final retryAfter = (res['retryAfter'] as num?)?.toInt();
    final attemptsLeft = (res['attemptsLeft'] as num?)?.toInt();
    final message = switch (code) {
      'rate_limited' => retryAfter != null && retryAfter > 0
          ? '${tr('auth.otpErrRateLimited')} ${_wait(retryAfter)}'
          : tr('auth.otpErrRateLimited'),
      'not_claimable' => tr('auth.otpErrNotClaimable'),
      'invalid_code' => tr('auth.otpErrInvalidCode'),
      'code_expired' => tr('auth.otpErrExpired'),
      'too_many_attempts' => tr('auth.otpErrTooManyAttempts'),
      'invalid_request' => tr('auth.otpErrInvalidRequest'),
      'unauthorised' => tr('auth.otpErrUnauthorised'),
      'network' => tr('auth.otpErrNetwork'),
      _ => tr('auth.otpErrGeneric'),
    };
    return OtpException(code, message,
        retryAfter: retryAfter, attemptsLeft: attemptsLeft);
  }

  String _wait(int seconds) {
    if (seconds < 60) return '$seconds${tr('auth.otpSecondsShort')}';
    final mins = (seconds / 60).ceil();
    return '$mins${tr('auth.otpMinutesShort')}';
  }
}
