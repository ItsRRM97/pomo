# Flutter wrapper & plugin packages
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class dev.flutter.plugins.** { *; }
-keep class xyz.luan.audioplayers.** { *; }

# Suppress warnings for optional Google Play Core / deferred components in Flutter embedding
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Pomo custom classes and services
-keep class com.recoskyler.pomo.** { *; }
-keep class com.recoskyler.MainActivity { *; }

# RemoteViews / Android resource references & plugin constructors
-keepclassmembers class * {
    public <init>(...);
}
