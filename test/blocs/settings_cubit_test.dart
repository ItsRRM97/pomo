import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsCubit', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    test('initial state is SettingsInitial', () {
      final cubit = SettingsCubit();
      expect(cubit.state, isA<SettingsInitial>());
      cubit.close();
    });

    blocTest<SettingsCubit, SettingsState>(
      'loadSettings emits SettingsState with loaded preferences',
      build: SettingsCubit.new,
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        isA<SettingsState>(),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setAlwaysOnTop updates state and persists to Prefs',
      build: () {
        final cubit = SettingsCubit()..loadSettings();
        return cubit;
      },
      act: (cubit) => cubit.setAlwaysOnTop(true),
      expect: () => [
        isA<SettingsState>().having((s) => s.alwaysOnTop, 'alwaysOnTop', true),
      ],
      verify: (cubit) {
        expect(Prefs.alwaysOnTop, isTrue);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'setWorkMinutes updates state and persists to Prefs',
      build: () {
        final cubit = SettingsCubit()..loadSettings();
        return cubit;
      },
      act: (cubit) => cubit.setWorkMinutes(30),
      expect: () => [
        isA<SettingsState>().having((s) => s.workMinutes, 'workMinutes', 30),
      ],
      verify: (cubit) {
        expect(Prefs.workMinutes, 30);
      },
    );
  });
}
