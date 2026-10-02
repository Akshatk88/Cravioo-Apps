import 'package:food_user_application/features/auth/domain/restaurant_model.dart';

/// The restaurant partner app's whole auth lifecycle, driven by
/// [AuthController]. The router's redirect logic switches on this.
sealed class AuthState {
  const AuthState();
}

/// Splash hasn't finished checking for a stored session yet.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// No valid session — show onboarding/login.
class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}

/// OTP requested for [phone]; waiting for the code to be entered.
class AuthOtpSent extends AuthState {
  const AuthOtpSent(this.phone);
  final String phone;
}

/// The phone was OTP-verified but no restaurant exists for it yet.
class AuthNeedsRegistration extends AuthState {
  const AuthNeedsRegistration(this.phone, [this.registrationToken]);
  final String phone;
  final String? registrationToken;
}

/// A restaurant exists for this phone but isn't approved yet.
class AuthPendingApproval extends AuthState {
  const AuthPendingApproval(this.message);
  final String message;
}

/// A restaurant exists for this phone but was rejected.
class AuthRejected extends AuthState {
  const AuthRejected(this.message);
  final String message;
}

/// Logged in with an approved restaurant — dashboard is unlocked.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.restaurant);
  final RestaurantModel restaurant;
}
