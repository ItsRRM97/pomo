import 'package:flutter/widgets.dart';
import 'package:pomo/l10n/generated/app_localizations.dart';

export 'package:pomo/l10n/generated/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  S get l10n => S.of(this);
}
