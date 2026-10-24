<div align="center">

```
  ██████╗ ██████╗       █████╗ ██████╗ ██████╗ ███████╗
  ██╔══██╗██╔══██╗     ██╔══██╗██╔══██╗██╔══██╗██╔════╝
  ██████╔╝██████╔╝     ███████║██████╔╝██████╔╝███████╗
  ██╔═══╝ ██╔═══╝      ██╔══██║██╔═══╝ ██╔═══╝ ╚════██║
  ██║     ██║    ██╗   ██║  ██║██║     ██║     ███████║
  ╚═╝     ╚═╝    ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝
   TEKNİK RESSAMLAR • DECENTRALIZED CAD & BIM NETWORK
```

# 📐 KO|Apps - Teknik Ressamlar
### *Teknik Ressamların Dijital Vitrini & Doğrudan Teklif Ekosistemi*

[![Platform](https://img.shields.io/badge/Platform-Android%20APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/KOApps-ui/teknikressamlar/raw/main/KO_Apps_TeknikRessam.apk)
[![Architecture](https://img.shields.io/badge/P2P-Nostr%20%2B%20UDP-FF9900?style=for-the-badge&logo=rss&logoColor=white)](https://nostr.com)
[![Encryption](https://img.shields.io/badge/Security-X25519%20%2B%20ChaCha20-00C853?style=for-the-badge&logo=lock&logoColor=white)](https://en.wikipedia.org/wiki/Curve25519)
[![License](https://img.shields.io/badge/Lisans-Proprietary-D32F2F?style=for-the-badge)](README.md)

<br/>

**Teknik Ressamlar**, imalat, makine, mimari, çelik yapı, mobilya ve elektrik alanlarındaki teknik ressamlar ile çizime ihtiyacı olan atölye, fabrika ve işverenleri **aracı komisyonu olmadan doğrudan (P2P)** buluşturan bağımsız bir vitrin uygulamasıdır.

[📥 Android APK İndir (97 MB)](https://github.com/KOApps-ui/teknikressamlar/raw/main/KO_Apps_TeknikRessam.apk) • [✨ Temel Özellikler](#-öne-çıkan-özellikler) • [📱 Kurulum](#-android-kurulum-rehberi) • [🛡️ Güvenlik](#%EF%B8%8F-askeri-düzeyde-güvenlik-ve-gizlilik)

---

</div>

## 💡 Neden Teknik Ressamlar?

Geleneksel aracı platformlar yüksek komisyon oranları, merkezi veri havuzları ve CAD dosyalarının boyut sınırlarıyla teknik çizim sektörünün dinamiklerine yanıt verememektedir.

**KO|Apps Teknik Ressamlar**, aracı sunucuları ortadan kaldırır. Teknik ressamlar yetkinliklerini, sertifikalarını ve çizimlerini özgürce sergiler; işverenler ise ihtiyaç duydukları teknik ressamı vitrinde seçip doğrudan teknik şartname ve CAD dosyası ekli iş teklifleri iletir.

```mermaid
graph LR
    subgraph Isveren ["🏢 İŞVEREN"]
        C_Key["DID / Şifreli Kimlik"]
        C_Offer["Teklif + DWG / STEP Paftaları"]
    end

    subgraph Ag ["⚡ ŞİFRELİ P2P DAĞITIM AĞI"]
        Relay["Nostr WSS Röleleri"]
        UDP["Yerel Ağ Doğrudan Keşif"]
    end

    subgraph Ressam ["📐 TEKNİK RESSAM"]
        D_Key["DID / Şifreli Kimlik"]
        D_Vault["Şifreli Çizim Vitrini & Portföy"]
    end

    C_Offer -->|Uçtan Uca Şifreli (X25519)| Relay
    C_Offer -->|Yerel Ağ Keşfi| UDP
    Relay -->|Doğrudan Teslimat| D_Vault
    UDP -->|Anında Bildirim| D_Vault
```

---

## ✨ Öne Çıkan Özellikler

### 🏛️ 1. Endüstriyel Blueprint Tasarım Dili
- Klasik teknik resim paftalarından ilham alan derin lacivert (`#0D1B2A`), kılavuz milimetrik ızgaralar, neon siyan aksiyon hatları (`#4CC9F0`) ve pirinç/çelik sarısı (`#FDB813`) kurumsal detaylar.
- Göz yormayan, yüksek kontrastlı ve teknik detayları ön plana çıkaran kompakt modüler kart mimarisi.

### 🔒 2. Askeri Düzeyde Uçtan Uca Şifreleme (E2EE)
- **X25519 & ChaCha20-Poly1305:** Gönderilen her teklif, revizyon ve dosya eki yalnızca alıcı teknik ressamın açık anahtarıyla şifrelenir.
- **Sıfır Sunucu Kaydı:** Mesajlar veya çizimler üçüncü taraf hiçbir şirketin veya bulut sağlayıcının veri tabanında saklanmaz.

### 📐 3. Kapsamlı CAD / BIM / 3D Proje Dosyası Yönetimi
İşverenler teklif oluştururken her türlü teknik çizim formatını doğrudan ekleyebilir:
- **2D CAD:** AutoCAD (`.dwg`, `.dxf`)
- **3D Katı Model:** SolidWorks, Inventor, STEP (`.sldprt`, `.sldasm`, `.ipt`, `.step`, `.stp`)
- **BIM & Mimari:** Revit, IFC, Navisworks (`.rvt`, `.ifc`, `.nwd`)
- **Şartname & Arşiv:** Dokümanlar ve arşivler (`.pdf`, `.zip`, `.rar`)
- Akıllı dosya tipi algılama ve tematik renkli mühendislik ikonları.

### 🎖️ 4. Resmi e-Devlet & GİB Doğrulama Entegrasyonu
- **Teknik Ressamlar:** YÖK e-Devlet mezuniyet ve mesleki yeterlilik belgelerini doğrudan PDF'ten barkod okuma ile doğrulayabilir.
- **Kurumsal İşverenler:** GİB e-Devlet barkodlu vergi levhalarını sisteme yükleyerek profillerine onay rozeti (`✓ GİB / e-Devlet Onaylı`) kazandırabilir.

### 👁️ 5. Gizlilik Korumalı Aday Vitrini
- Ressamların telefon numarası, e-posta adresi, WhatsApp bağlantısı, LinkedIn ve Kariyer.net profilleri teklif öncesinde gizli tutulur.
- İşveren teklif gönderip teknik ressam onayladığı anda bu iletişim kanalları şifreli tünel üzerinden güvenle açılır.

### 🔄 6. Canlı Teklif Revizyonu ve Düzenleme
- Bekleyen (`pending`) veya ressamın revize istediği / reddettiği (`rejected`) teklifler silinmek zorunda kalmadan tek tıkla düzenlenebilir.
- Bütçe, teslimat süresi, açıklama ve CAD ekleri güncellenerek ressama anında yeniden iletilebilir.

---

## 📱 Android Kurulum Rehberi

Uygulamanın güncel release sürümü bu depoda doğrudan dağıtılmaktadır:

1. **APK Dosyasını İndirin:**  
   👉 [**KO_Apps_TeknikRessam.apk İndir (97 MB)**](https://github.com/KOApps-ui/teknikressamlar/raw/main/KO_Apps_TeknikRessam.apk)
2. İndirilen `.apk` dosyasına dokunarak cihazınıza yükleyin (gerekirse *"Bilinmeyen kaynaklardan yüklemeye izin ver"* seçeneğini onaylayın).
3. Uygulamayı açarak **"Teknik Ressam"** veya **"İşveren Şirket"** rolünüzü seçip kendi vitrininizi oluşturun.

> ℹ️ *Xiaomi / Samsung / Huawei kullanıcıları için:* Ekran kapalıyken teklif bildirimlerinin gecikmemesi adına uygulama içerisindeki **"Pil Optimizasyonunu Devre Dışı Bırak"** uyarısını onaylamanız önerilir.

---

## 🛡️ Askeri Düzeyde Güvenlik ve Gizlilik

1. **Özel Anahtar Asla Cihazı Terk Etmez:** Nostr / DID gizli anahtarınız (`nsec`) yalnızca telefonunuzun güvenli alanında (Secure Storage) tutulur.
2. **Kişisel Veri Mahremiyeti:** Hiçbir pazarlama veya takip çerezi (telemetry / analytics) içermez.
3. **Şifreli Dosya Eki:** Gönderilen CAD ve PDF dosyaları aktarım öncesinde şifrelenir; ağ üzerindeki üçüncü taraflar çizim detaylarını göremez.

---

<div align="center">

**KO|Apps Teknoloji Çözümleri** tarafından teknik ressamlara ve sektöre armağan edilmiştir.  
*Tüm hakları saklıdır © 2026*

</div>
