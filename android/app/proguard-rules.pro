# ─────────────────────────────────────────────────────────────────────────────
# Flutter / Dart
# ─────────────────────────────────────────────────────────────────────────────
# Flutter keeps its own rules, but keep the embedding classes intact
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-dontwarn io.flutter.embedding.**

# ─────────────────────────────────────────────────────────────────────────────
# App – Native Adhan Components
# These are referenced by name in AndroidManifest.xml and via AlarmManager /
# PendingIntent. Obfuscating them will break them silently in release mode.
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.slatk.slatkapp.** { *; }
-keepclassmembers class com.slatk.slatkapp.** { *; }
-dontwarn com.slatk.slatkapp.**

# Keep R.raw, R.drawable, R.mipmap identifiers and values
-keepclassmembers class **.R$raw {
    public static <fields>;
}
-keep class **.R$raw { *; }
-keepclassmembers class **.R$drawable {
    public static <fields>;
}
-keep class **.R$drawable { *; }
-keepclassmembers class **.R$mipmap {
    public static <fields>;
}
-keep class **.R$mipmap { *; }

# Keep all BroadcastReceivers, Services, and Activities in the app package
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.app.Service
-keep public class * extends android.app.Activity

# ─────────────────────────────────────────────────────────────────────────────
# AndroidX & Support libraries
# ─────────────────────────────────────────────────────────────────────────────
-keep class androidx.core.content.ContextCompat { *; }
-keep class androidx.core.app.NotificationCompat { *; }
-dontwarn androidx.**

# ─────────────────────────────────────────────────────────────────────────────
# Firebase (Firestore, Auth, etc.)
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─────────────────────────────────────────────────────────────────────────────
# Flutter Local Notifications plugin
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# ─────────────────────────────────────────────────────────────────────────────
# General Android alarm / media safety rules
# ─────────────────────────────────────────────────────────────────────────────
-keep class android.media.** { *; }
-dontwarn android.media.**

-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Prevent stripping of classes used only via reflection (e.g., Parcelable)
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ─────────────────────────────────────────────────────────────────────────────
# Suppress common harmless warnings
# ─────────────────────────────────────────────────────────────────────────────
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn sun.misc.Unsafe
