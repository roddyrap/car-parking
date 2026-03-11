import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> initSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('themeMode') ?? 'system';

  if (savedTheme == 'light') {
    themeNotifier.value = ThemeMode.light;
  }
  else if (savedTheme == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  }
}

Widget createThemeButton(BuildContext context) {
  return ValueListenableBuilder(valueListenable: themeNotifier, builder: (a, b, c) {
    ThemeMode currentMode = themeNotifier.value;

    ThemeMode nextMode;
    String prefsString;
    IconData iconData;

    if (currentMode == ThemeMode.system) {
      iconData = Icons.brightness_auto;
      nextMode = ThemeMode.light;
      prefsString = 'light';
    }
    else if (currentMode == ThemeMode.light) {
      iconData = Icons.light_mode;
      nextMode = ThemeMode.dark;
      prefsString = 'dark';
    }
    else {
      iconData = Icons.dark_mode;
      nextMode = ThemeMode.system;
      prefsString = 'system';
    }

    return IconButton(
      onPressed: () {
        themeNotifier.value = nextMode;
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString("themeMode", prefsString);
        });
      },
      icon: Icon(iconData)
    );
  });
}

class CarStatusColors extends ThemeExtension<CarStatusColors> {
  const CarStatusColors({required this.occupiedByMeColor, required this.occupiedByOtherColor});

  final Color occupiedByMeColor;
  final Color occupiedByOtherColor;

  @override
  ThemeExtension<CarStatusColors> copyWith({Color? occupiedByMeColor, Color? occupiedByOtherColor}) {
    return CarStatusColors(
      occupiedByMeColor: occupiedByMeColor ?? this.occupiedByMeColor,
      occupiedByOtherColor: occupiedByOtherColor ?? this.occupiedByOtherColor
    );
  }

  @override
  ThemeExtension<CarStatusColors> lerp(covariant ThemeExtension<CarStatusColors>? other, double t) {
    if (other is! CarStatusColors) {
      return this;
    }

    return CarStatusColors(
      occupiedByMeColor: Color.lerp(occupiedByMeColor, other.occupiedByMeColor, t)!,
      occupiedByOtherColor: Color.lerp(occupiedByOtherColor, other.occupiedByOtherColor, t)!,
    );
  }

}