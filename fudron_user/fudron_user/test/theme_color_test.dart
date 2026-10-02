import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/presentation/branding/app_colors.dart';
import 'package:food_user_application/src/presentation/branding/app_theme.dart';
import 'package:food_user_application/src/presentation/branding/theme_color_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the app-theme-color feature: picking a color must repaint widgets
/// that read [AppColors] without an app restart. Regresses if someone
/// reintroduces a hardcoded brand hex or marks a brand-colored widget `const`.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Tests mutate the global AppColors; reset so order doesn't matter.
    AppColors.primary = AppThemeColor.fudron.color;
    AppColors.primaryButton = AppThemeColor.fudron.buttonColor;
  });

  test('derived shades follow primary and stay in the brand hue', () {
    AppColors.primary = AppThemeColor.blue.color;
    final blueHue = HSLColor.fromColor(AppColors.primary).hue;

    for (final shade in [
      AppColors.primaryLight,
      AppColors.primaryDeep,
      AppColors.primaryDeepText,
      AppColors.primaryTint,
      AppColors.primaryTintStrong,
      AppColors.primarySoft,
      AppColors.primaryTintDark,
      AppColors.primaryTintDarkStrong,
    ]) {
      // Tolerance is wide for the darkest shades: at very low lightness the
      // 8-bit round-trip through toColor() quantizes hue noticeably.
      expect(HSLColor.fromColor(shade).hue, closeTo(blueHue, 6.0));
    }

    // Ordering by lightness is what makes tints read as tints.
    double l(Color c) => HSLColor.fromColor(c).lightness;
    expect(l(AppColors.primaryTint), greaterThan(l(AppColors.primaryTintStrong)));
    expect(l(AppColors.primaryTintStrong), greaterThan(l(AppColors.primarySoft)));
    expect(l(AppColors.primarySoft), greaterThan(l(AppColors.primaryDeep)));
    expect(l(AppColors.primaryDeep), greaterThan(l(AppColors.primaryTintDark)));
  });

  testWidgets('changing the theme color repaints a live widget tree', (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            ref.watch(themeColorProvider); // what the real app root does
            return MaterialApp(
              theme: buildLightTheme(),
              home: Scaffold(
                body: Column(
                  children: [
                    ColoredBox(
                      key: const Key('direct'),
                      color: AppColors.primary,
                      child: const SizedBox(width: 10, height: 10),
                    ),
                    ColoredBox(
                      key: const Key('tint'),
                      color: AppColors.primaryTint,
                      child: const SizedBox(width: 10, height: 10),
                    ),
                    Builder(
                      builder: (c) => ColoredBox(
                        key: const Key('themed'),
                        color: Theme.of(c).colorScheme.primary,
                        child: const SizedBox(width: 10, height: 10),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    // Keyed lookup, not index: Scaffold/Material paint their own ColoredBoxes.
    Color painted(String key) => tester.widget<ColoredBox>(find.byKey(Key(key))).color;

    expect(painted('direct'), AppThemeColor.fudron.color);
    expect(painted('themed'), AppThemeColor.fudron.color, reason: 'ThemeData must carry the brand color');
    final brandTint = painted('tint');

    await capturedRef.read(themeColorProvider.notifier).setColor(AppThemeColor.green);
    await tester.pumpAndSettle();

    expect(painted('direct'), AppThemeColor.green.color, reason: 'direct AppColors read must update');
    expect(painted('themed'), AppThemeColor.green.color, reason: 'Theme.of() consumers must update');
    expect(painted('tint'), isNot(brandTint), reason: 'derived tints must update too');
  });
}
