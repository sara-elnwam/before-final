enum AppState {
  idle,       // التطبيق خامل وجاهز
  speaking,   // التطبيق يتحدث (TTS)
  listeningForCommand, // يستمع لأمر صوتي عام
  listeningForData,    // يستمع لإدخال بيانات (مثل الاسم)
  listeningForLanguage // يستمع لاختيار لغة
}
