# Belgeler

## Son kullanıcı

İlk kullanım için [kullanım kılavuzundan](kullanim-kilavuzu.md) başlayın.

| Belge | Ne zaman kullanılmalı? |
| --- | --- |
| [Kullanım kılavuzu](kullanim-kilavuzu.md) | Paket seçimi, kurulum, ilk bağlantı ve günlük kullanım |
| [EDA bağlantısını doğrulama](baglanti-dogrulama.md) | Altium/KiCad bağlantısını salt okunur isteklerle sınama ve sorun giderme |
| [MCP bağlam ayarı](mcp-context.md) | Minimal araç modu ve model bağlam sınırı sorunları |
| [Altium menü kullanımı](altium-menu-usage.md) | İsteğe bağlı, canlı Altium doğrulaması bekleyen korumalı menü modu |

## Çevrimdışı içerik ve belge sınırı

Son kullanıcı belgelerinin tek kaynağı `docs/` altındaki Markdown dosyalarıdır.
Depo köküne bu belgelerin Markdown veya PDF kopyalarını eklemeyin; kökteki
`README.md` belge indeksine yönlendiren depo girişidir.

Çevrimdışı paketlerde yalnız `docs/` kökündeki son kullanıcı Markdown belgeleri,
üretilen PDF'leri ve bu belgelerin görselleri bulunur. Geliştirici planları ve
canlı test listeleri `docs/gelistirici/` altında depoda tutulur; pakete eklenmez.
Bu yüzden aşağıdaki geliştirici bağlantıları web bağlantılarıdır ve internetsiz
bilgisayarda açılmayabilir. Kurulum için kullanım kılavuzu, tanılama için bağlantı
doğrulama rehberi esas alınır.

PDF'ler ilgili Markdown belgesiyle aynı klasörde aynı temel adla bulunur.
Güncel adımlar ve tıklanabilir belge bağlantıları için Markdown sürümlerini esas
alın; PDF bağlantıları üretimdeki dönüştürücünün yetenekleriyle sınırlıdır.

## Belgeleri üretme ve bağlantıları denetleme

Depo kökündeki `Build-Docs.ps1`, `docs/*.md` kapsamındaki **tüm** son kullanıcı
belgelerinin PDF'lerini üretir; bu indeks de dahildir, `docs/gelistirici/` dahil
değildir. Kaynak ortamda Node.js 20+, npm ve Windows Edge gerekir. Önce depo
kökünde sabitlenmiş araç bağımlılıklarını kurun:

```powershell
npm ci --prefix tools/docs
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Docs.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-Docs.ps1
```

Bu PowerShell komutları Windows PowerShell 5.1 ile kullanılabilir.
`Build-Docs.ps1` kurulu Edge'i headless çalıştırır; gerekirse `-EdgePath` ile
tarayıcı yolunu belirtin. npm hazırlığı internet gerektirebilir; son kullanıcının
hazır belgeleri okuması için Node.js/npm/Edge ile yeniden üretim yapması gerekmez.
`Test-Docs.ps1` yerel bağlantı hedeflerinin dosya olarak varlığını ve başlık
parçalarının (`#...`) geçerliliğini denetler; kullanıcı belgelerinin depo kökündeki
Markdown/PDF kopyalarını da hata sayar. Bu kaynak denetimi gerçek
OpenCode/Altium/KiCad bağlantısını veya web hedeflerinin erişilebilirliğini
doğrulamaz; canlı kontrol için bağlantı doğrulama rehberini kullanın.

## Geliştirici ve doğrulama ekibi — çevrimiçi

- [Altium menü entegrasyon planı](https://github.com/yasir-erkam/EdaAgentOfflineSetup/blob/main/docs/gelistirici/altium-menu-integration-plan.md)
- [Altium menü prototipi doğrulama listesi](https://github.com/yasir-erkam/EdaAgentOfflineSetup/blob/main/docs/gelistirici/altium-menu-prototype-checklist.md)
- [Paket üretimi ve depo kullanımı](https://github.com/yasir-erkam/EdaAgentOfflineSetup#tek-exe-paketini-üretme)
