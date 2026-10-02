import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:food_user_application/app.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'config/constants/app_constants.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = FlutterError.presentError;

      PlatformDispatcher.instance.onError = (error, stack) {
        if (kDebugMode) {
          debugPrint('Uncaught error: $error\n$stack');
        }
        return true;
      };

      try {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: AppConstants.firbaseApiKey,
            appId: AppConstants.firebaseAppId,
            messagingSenderId: AppConstants.firebasemessagingSenderId,
            projectId: AppConstants.firebaseProjectId,
          ),
        );

        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('Firebase init failed: $e\n$s');
        }
      }

      runApp(const ProviderScope(child: FoodUserApplication()));
    },
    (error, stack) {
      if (kDebugMode) {
        debugPrint('Uncaught zone error: $error\n$stack');
      }
    },
  );
}
