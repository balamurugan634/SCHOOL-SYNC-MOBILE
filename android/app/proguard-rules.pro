# Flutter's own rules are added by the Flutter Gradle plugin. Keep the app-specific bits below.

# flutter_local_notifications serialises scheduled notifications with Gson (generic types need their signatures).
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.reflect.TypeToken { *; }

# Firebase / Play services ship consumer rules; these only silence optional-dependency warnings.
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# local_auth / androidx.biometric
-keep class androidx.biometric.** { *; }

# Keep line numbers for symbolicated crash reports (map file is produced by R8; archive it with the Dart symbols).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Kotlin
-dontwarn kotlin.**
-dontwarn kotlinx.**
