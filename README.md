# 💗 YMS – Sen & Ben

<p align="center">
  <img src="https://media.giphy.com/media/MDJ9IbxxvDUQM/giphy.gif" width="160px">
</p>

<p align="center">
  <b>İki kişi için tasarlanmış özel bir dijital bağ uygulaması.</b><br>
  Günlük kalpler, mesajlar, seri kazanımlar ve tatlı bir rekabet 💕
</p>

---

## 💌 Projenin Amacı

YMS (You & Me System),  
tamamen kız arkadaşım için geliştirdiğim özel bir uygulamadır.

Amaç:

- Günlük olarak birbirimize kalp ve mesaj göndermek
- Gün sonunda kimin daha aktif olduğunu görmek
- Küçük ama tatlı bir rekabet oluşturmak
- Günlük serileri takip etmek
- Mesafe bilgisi görmek
- Basit ama anlamlı bir bağ kurmak

Bu proje ticari değildir.  
Kişisel ve duygusal bir motivasyonla geliştirilmiştir ❤️

---

## 🚀 Özellikler

- 💗 Tek tıkla kalp gönderme
- 💬 Manuel mesaj gönderme
- 🏆 Günlük kazanan sistemi
- 🔥 Günlük seri (streak) takibi
- 📊 Toplam kazanma sayacı
- 📍 GPS konum güncelleme ve mesafe hesaplama
- 📅 Günlük reset (00:00 otomatik)
- 🔔 Push Notification (Firebase + Cloudflare Worker)
- ☁️ Firestore tabanlı gerçek zamanlı senkronizasyon

---

## 🧠 Sistem Nasıl Çalışır?

### 1️⃣ Eşleşme Sistemi
- Kullanıcılar eşleşme kodu ile bağlanır
- `pairedUserId` üzerinden çift oluşturulur

### 2️⃣ Günlük Sayaç
Her kullanıcı için:

- `dailyHearts`
- `dailyMessages`
- `winnerStreak`
- `totalWins`
- `dailyKey`

tutulur.

### 3️⃣ Gün Sonu Değerlendirme

Saat 00:00 sonrası ilk girişte:

- Günlük kalp + mesaj toplamı hesaplanır
- Kazanan belirlenir
- `totalWins` artırılır
- Seri güncellenir
- Günlük sayaçlar sıfırlanır

### 4️⃣ Push Bildirim Altyapısı

Sistem 2 katmandan oluşur:

- Firebase Cloud Messaging
- Cloudflare Worker (serverless push proxy)

Worker, FCM HTTP v1 API kullanarak güvenli push gönderir.

---

## 🛠️ Teknolojiler

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white&style=flat-square">
  <img src="https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase&logoColor=black&style=flat-square">
  <img src="https://img.shields.io/badge/FCM-Push-FF6F00?logo=firebase&logoColor=white&style=flat-square">
  <img src="https://img.shields.io/badge/Cloudflare-Worker-F38020?logo=cloudflare&logoColor=white&style=flat-square">
</p>

---

## 📂 Proje Yapısı

```
lib/
 ├── screens/
 ├── services/
 ├── utils/
 ├── theme/
 └── main.dart

web/
firebase-messaging-sw.js
worker.js
```

---

## 🔐 Güvenlik

Bu repo içinde:

- ❌ Firebase private key bulunmaz
- ❌ Service account dosyası bulunmaz
- ❌ Cloudflare API key bulunmaz
- ❌ Environment secret dosyaları bulunmaz

Tüm hassas veriler:

- Cloudflare Worker Secrets
- Firebase Console
- Environment Variables

üzerinden yönetilir.

---

## ⚙️ Kurulum

### 1️⃣ Firebase Kurulumu

- Firebase project oluştur
- Firestore aktif et
- Authentication aktif et
- Cloud Messaging aktif et

### 2️⃣ Cloudflare Worker

Worker içerisine:

- API_KEY
- GSA_CLIENT_EMAIL
- GSA_PRIVATE_KEY
- FIREBASE_PROJECT_ID

secret olarak eklenmelidir.

### 3️⃣ Flutter

```
flutter pub get
flutter run -d chrome
```

---

## 🏆 Günlük Kazanma Mantığı

Kazanan =  
`dailyHearts + dailyMessages` toplamı yüksek olan kişi.

Eşitlik durumunda kazanan yoktur.

Toplam kazanma:
```
totalWins
```

Seri:
```
winnerStreak
```

---

## 💡 Gelecek Planları

- 🎨 Tema seçimi
- 📈 Haftalık istatistik ekranı
- 📅 Özel gün hatırlatıcı
- 💬 Sesli mesaj
- 📷 Fotoğraf gönderme
- 🏅 Rozet sistemi

---

## ⚖️ Lisans

Bu proje kişisel kullanım için geliştirilmiştir.

Açık kaynak olarak paylaşılmıştır ancak ticari kullanım için uygun değildir.

---

## ❤️ Not

Bu uygulama, koddan çok hisle yazılmıştır.

Birine değer verdiğinizde,  
bunu göstermek için bazen küçük bir yazılım yeterlidir.
Made with ❤️ by Selçuk
