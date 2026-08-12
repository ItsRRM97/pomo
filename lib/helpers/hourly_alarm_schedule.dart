/// Pure scheduling math for Android exact hourly alarms.
///
/// Kept free of platform channels so unit tests can cover hour boundaries
/// without a device. Native AlarmManager uses the epoch millis from
/// [nextHourBoundary].
DateTime nextHourBoundary(DateTime now) {
  return DateTime(now.year, now.month, now.day, now.hour)
      .add(const Duration(hours: 1));
}
