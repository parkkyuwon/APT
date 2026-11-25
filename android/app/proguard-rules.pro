# Flutter / Dart
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# Dio / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# mobile_scanner (ML Kit)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.mlkit.**

# flutter_secure_storage (AndroidX Security / BouncyCastle)
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# image_picker + platform plugins
-keep class io.flutter.plugins.imagepicker.** { *; }

# dio 파일 업로드 MultipartFile (런타임 reflection 사용 가능성)
-keep class dio.** { *; }

# Kotlin reflection (일부 플러그인 사용)
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Kotlin serialization / coroutines
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes Signature
