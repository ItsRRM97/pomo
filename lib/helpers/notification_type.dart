/// Timer / lap lifecycle events that can trigger sounds or OS notifications.
enum NotificationType {
  workStart,
  workEnd,
  shortBreakStart,
  shortBreakEnd,
  longBreakStart,
  longBreakEnd,
  startStop,
  nextLap,
  tick,
}
