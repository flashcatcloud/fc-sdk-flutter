# OkHttp reaches for BouncyCastle, Conscrypt and OpenJSSE to pick a TLS provider,
# and falls back to the platform one when they are absent. R8 does not know that,
# so it reports the missing classes as errors and fails the release build. None of
# these providers are on our classpath and none are needed - suppress the warnings.
#
# Keep this file: without it `flutter build apk --release` fails outright. It is
# the content Android Gradle Plugin itself generates in
# build/app/outputs/mapping/release/missing_rules.txt.
-dontwarn org.bouncycastle.jsse.BCSSLParameters
-dontwarn org.bouncycastle.jsse.BCSSLSocket
-dontwarn org.bouncycastle.jsse.provider.BouncyCastleJsseProvider
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE
