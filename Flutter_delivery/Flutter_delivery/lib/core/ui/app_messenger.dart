import 'package:flutter/material.dart';

/// App-wide ScaffoldMessenger, so code without a BuildContext (controllers,
/// the incoming-order flow) can still tell the rider why something failed.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppMessage(String message, {bool isError = false}) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFD64545) : null,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 6 : 3),
      ),
    );
}
