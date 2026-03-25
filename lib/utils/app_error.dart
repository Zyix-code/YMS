import 'package:mobile_scanner/mobile_scanner.dart';

String trError(Object e) {
  final t = e.toString().toLowerCase();

  if (t.contains('permission-denied') ||
      t.contains('missing or insufficient permissions')) {
    return '🚫 İzin hatası!\nFirestore erişimine izin verilmiyor.\n'
        '🔧 Çözüm: Firestore Rules + Auth oturumu kontrol et.';
  }

  if (t.contains('failed-precondition')) {
    return '⚠️ İşlem şu an yapılamıyor (failed-precondition).\n'
        'Genelde index / query / transaction çakışması olur.\n'
        '🔧 Çözüm: Query’yi sadeleştir veya gerekli indexi aç.';
  }

  if (t.contains('not-found')) {
    return '🔍 Bulunamadı!\nİstenen kayıt yok gibi görünüyor.';
  }

  if (t.contains('already-exists')) {
    return '🧩 Zaten var!\nAynı kayıt daha önce oluşturulmuş.';
  }

  if (t.contains('cancelled')) {
    return '🛑 İşlem iptal edildi.\nTekrar deneyebilirsin.';
  }

  if (t.contains('deadline-exceeded') || t.contains('timeout')) {
    return '⏳ Zaman aşımı!\nİşlem uzun sürdü, tekrar dener misin?';
  }

  if (t.contains('resource-exhausted')) {
    return '🥵 Sunucu yoğun görünüyor.\nBiraz bekleyip tekrar dene.';
  }

  if (t.contains('unavailable') || t.contains('service unavailable')) {
    return '📡 Servis şu an ulaşılmıyor.\nİnternetini kontrol edip tekrar dene.';
  }

  if (t.contains('unauthenticated') ||
      t.contains('auth') && t.contains('token')) {
    return '🔐 Oturum doğrulanamadı.\nÇıkış yapıp tekrar giriş yapmayı dene.';
  }

  if (t.contains('configuration_not_found') || t.contains('firebase_options')) {
    return '🧩 Firebase yapılandırması bulunamadı.\n'
        '🔧 google-services / firebase_options dosyalarını kontrol et.';
  }

  if (t.contains('network') ||
      t.contains('socketexception') ||
      t.contains('failed to fetch') ||
      t.contains('connection') && t.contains('error')) {
    return '🌐 Bağlantı sorunu var gibi.\nİnterneti kontrol edip tekrar dener misin?';
  }

  if (t.contains('cors')) {
    return '🧱 CORS hatası!\nWeb’de istek engelleniyor.\n'
        '🔧 Çözüm: Server/Worker CORS allowlist kontrol.';
  }

  if (t.contains('403')) {
    return '🚫 403 Yetkisiz erişim.\nİzinler / oturum / rules kontrol.';
  }

  if (t.contains('401')) {
    return '🔑 401 Yetkilendirme hatası.\nAPI Key / Token kontrol.';
  }

  if (t.contains('400')) {
    return '🧾 400 Hatalı istek.\nGönderilen veride bir problem olabilir.';
  }

  if (t.contains('500') || t.contains('internal server error')) {
    return '💥 Sunucu hatası (500).\nBiraz sonra tekrar dene.';
  }

  if (t.contains('format') && t.contains('exception')) {
    return '🧩 Veri formatı bozuk görünüyor.\nBir şey ters parse edilmiş olabilir.';
  }

  if (t.contains('type') && t.contains('is not a subtype')) {
    return '🧱 Tip uyuşmazlığı!\nBeklenen veri tipi farklı geldi.';
  }

  if (t.contains('permission') && t.contains('denied')) {
    return '🚫 İzin reddedildi.\nGerekli izinleri verip tekrar dener misin?';
  }

  return '😅 Bir şeyler ters gitti.\n'
      'Tekrar dener misin?\n\n'
      '🧠 İpucu: Bu hata sürekli olursa konsol logunu bana at, direkt nokta atışı çözelim.';
}

String trCameraError(MobileScannerException error) {
  final t = error.toString().toLowerCase();

  if (t.contains('notallowederror') ||
      t.contains('permission') ||
      t.contains('denied')) {
    return '🙈 Kamera izni verilmedi.\n\n'
        '🔧 Çözüm:\n'
        '• Adres çubuğundaki 🔒 simgesine tıkla\n'
        '• Kamera iznini “İzin ver” yap\n'
        '• Sayfayı yenile (Ctrl+Shift+R)';
  }

  if (t.contains('notfounderror') ||
      t.contains('device not found') ||
      t.contains('nocamera')) {
    return '📷 Kamera bulunamadı.\n\n'
        '🔧 Çözüm:\n'
        '• Cihazında kamera var mı kontrol et\n'
        '• Harici kamera ise tak-çıkar yap\n'
        '• Başka tarayıcıda dene';
  }

  if (t.contains('notreadableerror') ||
      t.contains('device in use') ||
      t.contains('trackstarterror')) {
    return '🔒 Kamera şu an kullanılıyor.\n\n'
        '🔧 Çözüm:\n'
        '• Diğer YMS sekmelerini kapat\n'
        '• Zoom/Meet/Discord/OBS gibi uygulamaları kapat\n'
        '• Sonra tekrar dene';
  }

  if (t.contains('overconstrainederror') || t.contains('constraint')) {
    return '⚙️ Kamera ayarları cihazla uyumlu değil.\n\n'
        '🔧 Çözüm:\n'
        '• Ön/arka kamera değiştir\n'
        '• Farklı tarayıcıda dene';
  }

  if (t.contains('securityerror') || t.contains('https')) {
    return '🔐 Güvenlik nedeniyle kamera açılamadı.\n\n'
        '🌍 Web’de kamera için HTTPS gerekir (localhost hariç).\n'
        'Siteyi https üzerinden açmalısın.';
  }

  return '😅 Kamera açılamadı. (${error.errorCode.name})\n\n'
      'Tekrar dener misin?';
}
