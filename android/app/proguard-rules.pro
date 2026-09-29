# ML Kit referencia los reconocedores de otros idiomas que no se incluyen.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Firebase ComponentDiscovery crea estos registradores por reflexión. La regla
# transitiva conserva sus nombres, pero con R8/AGP 9 no conserva el constructor
# vacío y ML Kit no puede inicializarse en release.
-keepclassmembers class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
