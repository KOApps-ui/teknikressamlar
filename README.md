<div align="center">

# 📐 KO|Apps - Teknik Ressamlar
### *Yeni Nesil Merkeziyetsiz, Şifreli Teknik Ressam Ekosistemi*

[![Flutter](https://img.shields.io/badge/Flutter-3.47.2-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.2-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/P2P-Nostr%20%2B%20UDP-FF9900?style=for-the-badge&logo=rss&logoColor=white)](https://nostr.com)
[![Encryption](https://img.shields.io/badge/Security-X25519%20%2B%20ChaCha20-00C853?style=for-the-badge&logo=lock&logoColor=white)](https://en.wikipedia.org/wiki/Curve25519)
[![Platform](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Linux-455A64?style=for-the-badge&logo=android&logoColor=white)](https://github.com/KOApps-ui/teknikressamlar)
[![License](https://img.shields.io/badge/License-Proprietary-D32F2F?style=for-the-badge)](LICENSE)

<br/>

**Teknik Ressamlar**, mimarlık, makine, inşaat, elektrik ve harita mühendisliği alanlarında uzman teknik ressamlar ile imalatçı, müşavir ve taahhüt şirketlerini **hiçbir aracı sunucuya ihtiyaç duymaksızın doğrudan (P2P)** buluşturan devrimsel bir mobil & masaüstü platformudur.

[📱 Android APK İndir](https://github.com/KOApps-ui/teknikressamlar/releases) • [🍏 iOS IPA Indir](https://github.com/KOApps-ui/teknikressamlar/releases) • [✨ Temel Özellikler](#-öne-çıkan-özellikler) • [🛡️ Güvenlik ve Gizlilik](#%EF%B8%8F-askeri-düzeyde-güvenlik-ve-gizlilik)

---

</div>

## 💡 Neden Teknik Ressamlar?

Geleneksel iş arama ve serbest çalışan platformları yüksek komisyon oranları, merkezi veri sızıntıları ve teknik çizim dosyalarının boyut sınırlarıyla mühendislik dünyasının ihtiyaçlarına yanıt verememektedir.

**KO|Apps Teknik Ressamlar**, merkezi sunucu modelini tamamen ortadan kaldırır. Tüm iletişim ve teklif alışverişi, kullanıcıların kendi cihazlarında yerel olarak üretilen kriptografik anahtarlarla şifrelenir; veriler yalnızca tarafların cihazlarında ve güvenilir P2P rölelerinde yaşar.

---

## ✨ Öne Çıkan Özellikler

### 🏛️ 1. Endüstriyel Blueprint Tasarım Dili
- Klasik teknik resim paftalarından ilham alan derin lacivert (`#0D1B2A`), kılavuz milimetrik ızgaralar, neon siyan aksiyon hatları (`#4CC9F0`) ve pirinç/çelik sarısı (`#FDB813`) kurumsal detaylar.
- Göz yormayan, yüksek kontrastlı ve teknik detayları ön plana çıkaran kompakt modüler kart mimarisi.

### 🔒 2. Askeri Düzeyde Uçtan Uca Şifreleme (E2EE)
- **X25519 & ChaCha20-Poly1305:** Gönderilen her teklif, revizyon ve dosya eki yalnızca alıcı teknik ressamın açık anahtarıyla şifrelenir.
- **Sıfır Sunucu Kaydı:** Mesajlar veya çizimler üçüncü taraf hiçbir şirketin veya bulut sağlayıcının veri tabanında saklanmaz.

### 📐 3. Kapsamlı CAD / BIM / 3D Proje Dosyası Yönetimi
Şirketler teklif oluştururken her türlü formatı doğrudan ekleyebilir:
- **2D CAD:** AutoCAD (`.dwg`, `.dxf`)
- **3D Katı Model:** SolidWorks, Inventor, STEP (`.sldprt`, `.sldasm`, `.ipt`, `.step`, `.stp`)
- **BIM & Mimari:** Revit, IFC, Navisworks (`.rvt`, `.ifc`, `.nwd`)
- **Şartname & Arşiv:** Dokümanlar ve arşivler (`.pdf`, `.zip`, `.rar`)
- Akıllı dosya tipi algılama ve tematik renkli dosya ikonları.

### 🎖️ 4. Resmi e-Devlet & GİB Doğrulama Entegrasyonu
- **Teknik Ressamlar:** YÖK e-Devlet mezuniyet ve mesleki yeterlilik belgelerini doğrudan PDF'ten barkod okuma ile doğrulayabilir.
- **Kurumsal Şirketler:** GİB e-Devlet barkodlu vergi levhalarını sisteme yükleyerek profillerine onay rozeti (`✓ GİB / e-Devlet Onaylı`) kazandırabilir.

### 👁️ 5. Gizlilik Korumalı Aday Vitrini
- Adayların telefon numarası, e-posta adresi, WhatsApp bağlantısı, LinkedIn ve Kariyer.net profilleri teklif öncesinde gizli tutulur.
- Şirket teklif gönderip aday onayladığı anda bu iletişim kanalları şifreli olarak anında açılır.

### 🔄 6. Canlı Teklif Revizyonu ve Düzenleme
- Bekleyen (`pending`) veya adayın revize istediği / reddettiği (`rejected`) teklifler silinmek zorunda kalmadan tek tıkla düzenlenebilir.
- Bütçe, teslimat süresi, açıklama ve CAD ekleri güncellenerek adaya anında yeniden iletilebilir.

---

## 🛠️ Mimari ve Teknoloji Yığını

| Katman | Teknoloji / Kütüphane | Açıklama |
| :--- | :--- | :--- |
| **Framework** | **Flutter 3.47.2 / Dart 3.13.2** | Çoklu platform (Android, iOS, Linux Desktop, Web) |
| **P2P İletişim** | **Nostr (NIP-01, NIP-04, NIP-44) + UDP** | Dağıtık WSS röle ağı ve yerel ağ multicast/broadcast |
| **Kriptografi** | **Cryptography (X25519, ChaCha20-Poly1305)** | Donanım hızlandırmalı modern asimetrik & simetrik şifreleme |
| **Yerel Veritabanı** | **Hive & Hive Flutter** | Cihaz üzerinde çalışan şifreli, yüksek performanslı NoSQL saklama |
| **Ağ & Medya** | **flutter_webrtc & file_picker** | P2P sesli iletişim ve sınırsız dosyası seçimi |
| **Belge Ayrıştırma**| **syncfusion_flutter_pdf & google_mlkit**| PDF barkod ve belge metni çıkarma motoru |

---


## 🛡️ Askeri Düzeyde Güvenlik ve Gizlilik

1. **Özel Anahtar Asla Cihazı Terk Etmez:** Nostr / DID gizli anahtarınız (`nsec`) yalnızca telefonunuzun güvenli alanında (Secure Storage) tutulur.
2. **Kişisel Veri Mahremiyeti:** Hiçbir pazarlama veya takip çerezi (telemetry / analytics) içermez.
3. **Şifreli Dosya Eki:** Gönderilen CAD ve PDF dosyaları aktarım öncesinde şifrelenir; ağ üzerindeki üçüncü taraflar çizim detaylarını göremez.

---

<div align="center">

**KO|Apps** tarafından Teknik Ressam dünyasına armağan edilmiştir.  
*Tüm hakları saklıdır © 2026*

</div>
