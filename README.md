# Flutter Live Quiz Arena 🚀

Modern, gerçek zamanlı, çok oyunculu bir bilgi yarışması uygulaması. Flutter ve Firebase kullanılarak geliştirilmiştir.
## 🎮 Özellikler

*   **Gerçek Zamanlı Multiplayer:** Arkadaşlarınızla aynı anda aynı odada yarışın.
*   **Oda Sistemi:** Kendi odanızı oluşturun, şifre koyun veya herkese açık yapın.
*   **Canlı Liderlik Tablosu:** Yarışma sırasında puan durumunu anlık takip edin.
*   **Zamanlı Yarışma:** Her soru için belirlenen süre içinde cevap verin.
*   **Kategoriler ve Zorluk Seviyeleri:** Farklı alanlarda bilginizi test edin.
*   **Modern UI/UX:** Akıcı animasyonlar, karanlık mod uyumlu şık tasarım.
*   **QR Kod ile Katılma:** Odalara hızlıca katılmak için QR kod desteği.

## 🛠 Kullanılan Teknolojiler

*   **Flutter:** UI Toolkit (Dart dili ile).
*   **Firebase Authentication:** Kullanıcı kaydı ve girişi (Email/Şifre).
*   **Cloud Firestore:** Gerçek zamanlı veritabanı (Odalar, Sorular, Kullanıcılar).
*   **Riverpod:** State management (Durum yönetimi).
*   **GoRouter:** Navigasyon ve yönlendirme.
*   **Mobile Scanner & QR Flutter:** QR kod okuma ve oluşturma.

## 🚀 Kurulum ve Başlangıç

Projeyi yerel ortamınızda çalıştırmak için aşağıdaki adımları izleyin.

### 1. Projeyi Klonlayın

```bash
git clone https://github.com/kullaniciadi/flutter-live-quiz.git
cd flutter-live-quiz
```

### 2. Bağımlılıkları Yükleyin

```bash
flutter pub get
```

### 3. Firebase Kurulumu (ÖNEMLİ ⚠️)

Bu proje çalışmak için Firebase bağlantısına ihtiyaç duyar. Kendi Firebase projenizi oluşturup bağlamanız gerekmektedir.

#### Adım 3.1: Firebase Projesi Oluşturun
1.  [Firebase Console](https://console.firebase.google.com/) adresine gidin.
2.  Yeni bir proje oluşturun.
3.  **Authentication** menüsünden "Email/Password" yöntemini etkinleştirin.
4.  **Firestore Database**'i oluşturun ve kuralları test modu (veya uygun güvenlik kuralları) ile başlatın.

#### Adım 3.2: Uygulamayı Bağlayın
Proje kök dizininde terminali açın ve `flutterfire` CLI aracını kullanarak projenizi bağlayın (FlutterFire CLI kurulu olmalıdır):

```bash
flutterfire configure
```
*Bu işlem `lib/firebase_options.dart` dosyasını oluşturacaktır.*

### 4. Veritabanı Yapısı (Database Schema)

Uygulamanın düzgün çalışması için Firestore'da aşağıdaki koleksiyon yapısını kullanmanız veya uygulamanın otomatik oluşturmasını beklemeniz gerekir. Uygulama içerisinde `QuestionService` ilk çalıştırmada örnek soruları otomatik yükleyebilir.

#### **A. `users` Koleksiyonu**
Kullanıcı bilgilerini tutar.
*   **Document ID:** (Auth UID)
*   **Alanlar:**
    *   `uid`: (String) Kullanıcı ID'si
    *   `name`: (String) Görünen İsim
    *   `email`: (String) E-posta
    *   `createdAt`: (Timestamp)

#### **B. `rooms` Koleksiyonu**
Oyun odalarını tutar.
*   **Document ID:** (Auto Generated)
*   **Alanlar:**
    *   `roomId`: (String)
    *   `roomCode`: (String) Kullanıcıların girmesi için 6 haneli kod.
    *   `roomName`: (String) Oda ismi.
    *   `ownerId`: (String) Odayı kuran kullanıcının UID'si.
    *   `status`: (String) Odasının durumu (`waiting`, `playing`, `finished`).
    *   `isPrivate`: (Boolean) Şifreli mi?
    *   `password`: (String) Oda şifresi.
    *   `currentQuestionIndex`: (Change) Mevcut soru sırası.
*   **Subcollection: `players`** (Her odanın altında)
    *   **Document ID:** (User UID)
    *   `name`: (String)
    *   `score`: (Number)
    *   `isReady`: (Boolean)

#### **C. `questions` Koleksiyonu** (Önemli!)
Uygulama soruları buradan çeker.
*   **Document ID:** (Auto Generated)
*   **Alanlar:**
    *   `question`: (String) "İstanbul'u kim fethetmiştir?"
    *   `options`: (Map) `{"a": "Fatih Sultan Mehmet", "b": "Osman Bey", ...}`
    *   `correctOption`: (String) "a"
    *   `category`: (String) "Tarih"
    *   `difficulty`: (String) "basit"
    *   `duration`: (Number) 15 (Saniye cinsinden süre)

> **Not:** `QuestionService` sınıfı (`lib/core/services/question_service.dart`) içerisinde `seedQuestionsIfEmpty` fonksiyonu bulunur. Veritabanı boşsa otomatik olarak örnek soru seti yükleyecektir.

## 📱 Ekran Görüntüleri
Ekran görüntülerini images klasörünün içinde bulabilirsiniz.
