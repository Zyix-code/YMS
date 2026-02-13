String trError(Object e) {
  final t = e.toString();

  if (t.contains('permission-denied')) {
    return 'İzin hatası: Firestore erişimi engelliyor. (permission denied)';
  }
  if (t.contains('CONFIGURATION_NOT_FOUND')) {
    return 'Firebase yapılandırması bulunamadı. (google-services / firebase_options kontrol)';
  }
  if (t.contains('network')) {
    return 'Bağlantı sorunu var gibi. İnterneti kontrol edip tekrar dener misin?';
  }
  if (t.contains('timeout')) {
    return 'İşlem zaman aşımına uğradı. Birazdan tekrar dener misin?';
  }

  return 'Bir şeyler ters gitti. 😅 Tekrar dener misin?';
}
