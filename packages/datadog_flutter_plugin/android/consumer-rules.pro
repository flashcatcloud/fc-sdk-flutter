# Keep the plugin classes the method channels reach reflectively.
-keep class com.datadog.android.api.context.* { *; }
-keep class com.datadoghq.flutter.DatadogSdkPlugin { *; }
-keep class com.datadoghq.flutter.DatadogSdkPlugin$Companion { *; }
-keep class com.datadoghq.flutter.DatadogLogsPlugin { *; }
-keep class com.datadoghq.flutter.DatadogLogsPlugin$Companion { *; }
-keep class com.datadoghq.flutter.DatadogLogEventMapper { *; }
-keep class com.datadoghq.flutter.DatadogLogEventMapper$EventMapper { *; }
-keep class com.datadoghq.flutter.DatadogRumPlugin { *; }
-keep class com.datadoghq.flutter.DatadogRumPlugin$Companion { *; }
-keep class com.datadoghq.flutter.DatadogRumEventMapper { *; }
-keep class com.datadoghq.flutter.DatadogRumEventMapper$EventMapper { *; }

# DO NOT REMOVE THE RULES BELOW. They are not scratch, and they are not
# optional: without them every app that depends on this plugin fails
# `flutter build apk --release` outright with
# "ERROR: R8: Missing class org.bouncycastle.jsse.BCSSLParameters ...".
#
# OkHttp (a transitive runtime dependency of the FlashCat Android SDK) probes
# for BouncyCastle, Conscrypt and OpenJSSE to pick a TLS provider, and falls
# back to the platform provider when none of them are present. R8 cannot see
# that those references are optional, so it reports the absent classes as
# errors. None of these providers are on our classpath and none are needed.
#
# These lines are verbatim what the Android Gradle Plugin itself writes to
# build/app/outputs/mapping/release/missing_rules.txt. They live here, in the
# consumer rules, so that consuming apps receive them automatically -- an
# integrator must not have to rediscover and paste them by hand. An identical
# copy previously lived only in the example app, which is why released versions
# up to 0.1.2 shipped broken; a copy that is not in this file does not reach
# users.
-dontwarn org.bouncycastle.jsse.BCSSLParameters
-dontwarn org.bouncycastle.jsse.BCSSLSocket
-dontwarn org.bouncycastle.jsse.provider.BouncyCastleJsseProvider
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE
