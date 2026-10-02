# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Delivery native notifications and services
-keep class com.cravioo.delivery.** { *; }
-keepclassmembers class com.cravioo.delivery.** { *; }

# Firebase messaging
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.messaging.** { *; }

# Flutter local notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Audio players
-keep class xyz.luan.audioplayers.** { *; }

# Google Play Core – Flutter's PlayStoreDeferredComponentManager references these
# classes at compile time. If you don't use deferred/dynamic delivery, they are
# absent from the classpath, causing R8 to abort. Suppress the error with a dontwarn
# and keep any stubs so the shrinker can resolve references.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
