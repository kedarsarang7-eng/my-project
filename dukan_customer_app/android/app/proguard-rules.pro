# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# firebase_messaging
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# amazon_cognito_identity_dart_2 — uses reflection for JSON
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod

# Keep all model classes used by JSON serialisation
-keep class ** implements java.io.Serializable { *; }

# Prevent stripping of Kotlin metadata
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# OkHttp (used by http package under the hood on some paths)
-dontwarn okhttp3.**
-dontwarn okio.**

# Flutter Play Core Deferred Components fallback
-dontwarn com.google.android.play.core.**

