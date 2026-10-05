# Şerit · Touch Bar Post

**Touch Bar’ına not bırak, hatırlatma kur veya duyuru geçir.** Tek pencere, tek mesaj alanı, tek Kaydet düğmesi. Swift/AppKit ile geliştirilmiş, macOS 11+ için Intel ve Apple Silicon Universal uygulama.

[Uygulamayı indir](https://github.com/metealpkarvan/touch-bar-post/releases/latest) · [English](README.md)

![Şerit’in gerçek macOS arayüzü](docs/desktop.png)

## Üç basit iş

- **Not:** Mesajını yaz ve kaydet. Başka mesaj seçene veya bir hatırlatmanın vakti gelene kadar şeritte kalır. Ortasına dokunarak düzenle; Kopyala ile metni panoya al.
- **Hatırlatıcı:** Mesajını yaz, tarih/saat seç veya +5, +15, +60 dakika düğmelerini kullan, kaydet. Vakti gelince şeritte öne çıkar. ✓ ile tamamla veya beş dakika ertele.
- **Duyuru:** Mesajını yaz ve kaydet. Uzun duyurular kayar; notlar ve hatırlatmalar sabit kalır. macOS’un Hareketi Azalt tercihi dikkate alınır.

Kayıtlı mesajların tek listede görünür. Birini seçerek düzenle veya şeritte göster; **Yeni** ile başka mesaj yaz, **Sil** ile seçtiğini kaldır. Ekrandaki şerit ile Touch Bar aynı işlevleri sunar: önceki, mesaj, eylem ve sonraki. **+** yeni bir not başlatır.

Seçtiğin mesaj yeniden açılışta hatırlanır. Geçerli değişiklikler mesaj değiştirirken, pencereyi kapatırken veya uygulamadan çıkarken de kaydedilir. Kayıt başarısız olursa taslağın korunur ve gezinme durur. Alanı boşaltmak kayıtlı mesajı silmez; silmek için **Sil** düğmesini kullan.

![Duyuru şeridi](docs/touchbar-announcement.png)
![Hatırlatma şeridi](docs/touchbar-reminder.png)

## Kur ve kullan

1. `TouchBarPost-v1.1.0-universal.zip` dosyasını indir, aç ve **Şerit.app** uygulamasını Applications klasörüne taşı.
2. Uygulamayı aç. **Not**, **Hatırlatıcı** veya **Duyuru** seç, kısa mesajını yaz ve **Kaydet** düğmesine bas. Hatırlatıcı için tarih/saat de belirt.
3. Sistem bildirimlerini istersen menüden aç. Yedekleme ve Türkçe/İngilizce seçimi de yerel macOS menülerindedir.

Yeni sürümü açmadan önce eski Şerit’i kapat. Sürüm 1 kayıtları uyumludur: eski mesajlar, başlıkları, açıklamaları ve bilgileri korunur. Önceki bütün sahnelerdeki mesajlar tek listede görünür; eski sabitlenmiş mesajların önceliği korunur. Sade arayüz mesajları otomatik dolaştırmaz.

Paket bütünlüğü için ad-hoc imzalıdır; Apple Developer ID imzası ve noter onayı yoktur. Gatekeeper ilk açılışı engellerse uygulamayı açmayı denedikten sonra **Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç** yolunu kullan. macOS sürümüne göre adlar değişebilir. Güvenlik ayarlarını tüm sistem için kapatman gerekmez. Kaynak kodunu ve SHA256 checksum’unu inceleyebilirsin.

## Touch Bar ve hatırlatmalar

Resmi AppKit Touch Bar’ı, uygulama **öndeyken** gösterir. Şerit başka uygulamaların Touch Bar’ını değiştirmez. Pencereyi kapatmak uygulamayı kapatmaz; menü çubuğundaki simgeden geri açabilirsin. **⌘Q / Çık** uygulamayı kapatır. Fiziksel Touch Bar destekleyen bir MacBook Pro gerekir; ekrandaki şerit, Touch Bar’sız Intel ve Apple Silicon Mac’lerde de çalışır.

Sistem bildirimleri isteğe bağlıdır. İzin yalnızca menüden açmayı seçtiğinde istenir. Açıkken gelecekteki en yakın **60 aktif hatırlatma** tek seferlik yerel bildirim olarak planlanır; Şerit kapalı olsa da bu istekleri macOS yönetir. Sonraki kayıtlar uygulama yeniden çalışırken planlamaya alınır. Gösterim macOS izinleri, odak modu, uyku ve sistem davranışına bağlıdır. Geçmiş tarihli kayıtlar yeniden sistem uyarısı üretmez; uygulamada vakti gelmiş olarak kalır. Hatırlatmalar otomatik tekrarlanmaz. Yerel tarih/saat bir zaman anı olarak kaydedilir.

**Şerit → Touch Bar metnini gizle**, şeritteki ve menüdeki mesaj başlıklarını gizler; uygulamanın gösterilmiş bildirimlerini kaldırır, yeni bildirimlerde genel içerik kullanır. Editör görünür kalır. Eski kaydındaki gizlilik tercihi korunur; mesajları tekrar göstermek için menüdeki işareti kaldır.

## Kayıtların ve yedeklerin

Mesajlar `~/Library/Application Support/TouchBarPost/archive.json` içinde tutulur; şifreli değildir. Hesap, sunucu, analiz, AI API’si veya arka planda ağ çağrısı yoktur. En fazla 200 mesaj; JSON yedek sınırı 1 MB.

Veriler menüsünden JSON yedeğine, yedek yüklemeye, önceki kaydı kurtarmaya, Markdown çıktısına ve kayıt klasörüne ulaşabilirsin. Normal kayıt bir önceki geçerli sürümü `archive.previous.json` olarak saklar. Yedek yüklemeden veya önceki kaydı kurtarmadan önce orijinalin ayrı kurtarma kopyası alınır. Bozuk arşive yazılmaz; orijinalini olduğu gibi dışa aktarabilirsin. Yedek veya önceki kayıt yüklendikten sonra bildirimleri yeniden açman gerekir. Kurtarma kopyaları sen silene kadar tutulur.

## Geliştirme

```bash
swift run --disable-sandbox -j 2 PostRulesTests
swift build --disable-sandbox -j 2 --product TouchBarPost
.build/debug/TouchBarPost --smoke-test --screenshots output/verification
bash scripts/package.sh 1.1.0
```

Xcode Command Line Tools ve Swift 5.7+ gerekir. Paketleme, UTF-8 dosya adlarını ve çalıştırma izinlerini korumak için Python 3’ün standart ZIP kütüphanesini kullanır; uygulamayı kullananların Swift veya Python kurması gerekmez. Sistem bildirimleri için paketlenmiş `.app` çalıştır. Harici paket bağımlılığı yoktur.

CI native Intel ve arm64 kural/AppKit kontrollerini, ardından Universal paketi doğrular. Testler kurgusal mesajlar ve geçici dosyalar kullanır; panoya yazmaz, bildirim izni istemez. Fiziksel Touch Bar ve gerçek bildirim teslimi için [cihaz kontrol listesi](docs/HARDWARE-CHECKLIST.md) bulunur.

[Tasarım](docs/DESIGN.md) · [Mimari](docs/ARCHITECTURE.md) · [Doğrulama](docs/VERIFICATION.md) · [Yol haritası](docs/ROADMAP.md)

MIT © 2026 Mete Alp Karvan
