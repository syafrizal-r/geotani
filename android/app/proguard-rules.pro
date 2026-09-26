# Google ML Kit registers its internal components via reflection at app
# startup (ComponentDiscovery), which requires each *Registrar class to keep
# its public no-arg constructor. Without these rules, R8 strips/renames those
# constructors, ComponentDiscovery silently fails to register ML Kit's vision
# internals, and any later face-detection call crashes with a native NPE
# ("Attempt to invoke virtual method ... getClass() on a null object
# reference") instead of a catchable Dart exception.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-dontwarn com.google.mlkit.**
