# EDA Agent — Çevrimdışı Windows Kurulumu

`salitronic/eda-agent` MCP sunucusunu internetsiz (air-gapped) Windows x64
bilgisayarlara taşınabilir bir paketle kurar. Python ve tüm Python bağımlılıkları
paketin içindedir; hedef bilgisayarda Python, pip, Git veya internet gerekmez.
Windows 10/11 x64 ve kurulu/lisanslı EDA uygulaması gerekir.

## Son kullanıcı için

Önce OpenCode'u ve kullanacağınız EDA uygulamasını ayrı kurun; çevrimdışı ortamda
erişilebilir yerel veya kurum içi model de gerekir. Altium için `-altium.exe`,
KiCad 9+ için `-kicad.exe` ile biten paketi seçin. İki paket birlikte kurulabilir.
EasyEDA Pro desteklenmez.

- **Kurulum ve ilk 5 dakika:** [Kullanım kılavuzu](docs/kullanim-kilavuzu.md).
- **Bağlantı kontrolü, hata çözümü ve tanı günlükleri:**
  [Bağlantı doğrulama rehberi](docs/baglanti-dogrulama.md).
- **Tüm kullanıcı belgeleri:** [Belge indeksi](docs/README.md).
- **İsteğe bağlı Altium menüsü:** [Kapsam ve kullanım](docs/altium-menu-usage.md).
  Varsayılan olarak kapalıdır; mevcut **EDA Agent** açma komutu korunur. Üretilen
  `Altium-Menu-Commands.txt` ile Customize üzerinden ayrıca Başlat/Durum/Kes/Yeniden
  bağlan girişleri elle eklenebilir. Beşi de aynı dış bağlantı yardımcısını kullanır;
  yalnız açma komutu bağlantıyı başlatmaz. Doğrudan işlem başarılı oturum bağlamasından
  sonra bir kez uygulanır. Canlı Altium 26.7.1 doğrulaması beklemektedir; otomatik menü
  kaydı, ikinci native arayüz veya çoklu proje yönetimi yoktur.

Bu belgeler kaynakta varsayılan kurulum sürümü **0.1.8** için hazırlanmıştır;
bu bilgi bir Release'in yayımlandığını veya canlı EDA bağlantısının doğrulandığını
göstermez. [Sürüm kapsamı ve doğrulama durumu](docs/kullanim-kilavuzu.md#sürüm-kapsamı-ve-doğrulama-durumu).
Kurulumun çevrimdışı çalışması, internet gerektiren modellerin veya arama
araçlarının çevrimdışı çalışacağı anlamına gelmez.

Aşağıdaki bölümler paket hazırlayan geliştiriciler ve bakım ekibi içindir.

## Tek EXE paketini üretme

İnternetli hazırlama bilgisayarında önce aşağıdaki bölümdeki
`Build-OfflineBundle.ps1` komutuyla paketi hazırlayın. Ardından Inno Setup 6
derleyicisiyle çalıştırın:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Installer.ps1 -Backend altium
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Installer.ps1 -Backend kicad
```

Seçilen backend için en yeni hazırlanmış paket seçilir; varsayılan backend
`altium`'dur. `-BundlePath`,
`-SetupVersion 0.1.8` ve `-IsccPath 'C:\Tools\Inno Setup 6\ISCC.exe'` ile
özelleştirilebilir. Kaynak scriptler değiştiyse eski paket reddedilir; yeniden
hazırlayın. EXE ve `.sha256` dosyası `dist` altında üretilir. Derleme sürümü
upstream EDA Agent/Python sürümlerinden ayrıdır. EXE üretme adımı indirme yapmaz.

Aşağıdaki PowerShell adımları elle kurulum veya bakım içindir.

## GitHub Actions ile otomatik yayın

`.github/workflows/release.yml`, `v*` etiketi gönderildiğinde GitHub'ın geçici Windows
sunucusunda Altium ve KiCad paketlerini ayrı ayrı hazırlar. Çevrimdışı kurulum,
ayar koruma, sihirbaz ve iki paketin birlikte kurulup kaldırılması testleri geçerse
iki EXE'yi, SHA256 dosyalarını, `bundle.json` metadata dosyalarını ve çözümlenen
`packages.lock.txt` listelerini aynı GitHub Release'e yükler. GitHub CLI veya kişisel
erişim anahtarı gerekmez; otomatik `GITHUB_TOKEN` ile [GitHub API](https://docs.github.com/en/rest/releases/releases)
kullanılır. Yükleme adımı PowerShell 7 ile çalışır; dosya bazında ilerlemeyi yazar
ve geçici bağlantı hatalarında en fazla üç kez dener. Yeniden denemeden önce yarım
kalan aynı adlı dosyayı taslaktan temizler. Yayımlama yarıda kalırsa **Re-run jobs** taslağı tamamlar; yayımlanmış
sürümler değiştirilmez.

İlk yayın için bu otomasyonu içeren commit'ten sonra Eda deposunda etiket oluşturup gönderin:

```powershell
git tag -a v0.1.8 -m "Release EDA installers 0.1.8"
git push --atomic origin main refs/tags/v0.1.8
```

Sonraki yayınlarda paket sürümlerini ve CHANGELOG'u güncelleyin, commit ve yeni
etiket oluşturun. GitHub'da **Actions → Release EDA installers → Run workflow**
üzerinden mevcut bir etiketi girerek de çalıştırabilirsiniz. Seçilen etiketin
otomasyon dosyalarını içermesi gerekir. OpenCode deposunun `v1.1.3` etiketi Eda
deposuna ait değildir; Eda'nın mevcut kurulum sürümü `0.1.8`'dir.

`release-source.json` upstream EDA Agent commit'ini ve Python sürümünü sabitler;
iki backend aynı kaynakla derlenir. Python bağımlılıkları her hazırlamada yeniden
çözümlenir; aynı etiketle sonradan yapılan derleme birebir aynı paketleri garanti
etmez. Dağıtımda yayımlanan EXE'yi ve beraberindeki metadata/bağımlılık listesini
saklayın; yeni dağıtım için yeni sürüm kullanın. Doğrulanmış çıktılar ayrıca
Actions artifact'i olarak 14 gün tutulur.

Hedef bilgisayardaki kurulum yine internetsiz çalışır. GitHub testleri gerçek
Altium/KiCad tasarım bağlantısını doğrulamaz; bu kontrol hedef EDA ortamında yapılır.

## 1. İnternetli bilgisayarda paketi hazırlayın

Windows PowerShell 5.1 veya üzeriyle bu klasörde çalıştırın:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-OfflineBundle.ps1
```

Varsayılan backend Altium'dur. Her iki ayrı paketi hazırlamak için:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-OfflineBundle.ps1 -Backend altium
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-OfflineBundle.ps1 -Backend kicad
```

Python 3.13.16 embeddable sürümü resmi Python sitesinden; kaynak kod GitHub'dan,
bağımlılıklar PyPI'dan indirilir. İnternetli bilgisayarda da Python gerekmez.
Yerel kaynak wheel'i oluşturulur; üçüncü taraf bağımlılıklarda yalnız hazır
Windows wheel'leri kabul edilir. Render ve yerel dashboard bağımlılıkları dahildir.

Kaynak sürümünü sabitlemek için `-SourceCommit <40-karakter-commit>` kullanın.
Belirtilmezse o andaki `main` commit'i alınır; `bundle.json` içine kaydedilir.
`packages.lock.txt` çözümlenen paket sürümlerini kaydeder. Sonraki hazırlamalarda
bağımlılıklar değişebilir; aynı dağıtım için üretilen paketi saklayın.

## 2. Paketi internetsiz bilgisayara taşıyın

`dist\EdaAgent-...` klasörünün **tamamını** kurumunuzun aktarım yöntemiyle taşıyın.
Dosya bütünlüğü kurulumdan önce SHA256 ile kontrol edilir. Bu kontrol taşıma
bozulmalarını yakalar; dağıtıcı imzası yerine geçmez. Lisanslar `runtime` içindeki
paket metadata dizinlerinde, upstream LICENSE/NOTICE ise `upstream` altındadır.

## 3. Hedef bilgisayarda kurun

`Install.cmd` dosyasını çalıştırın veya PowerShell kullanın:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Offline.ps1 -ConfigureOpenCode
```

`Install.cmd` dosyasına çift tıklamak yalnız EDA Agent'ı kurar ve MCP ayar örneğini
oluşturur. OpenCode'a otomatik kaydetmek için yukarıdaki komutu veya
`Install.cmd -ConfigureOpenCode` kullanın. Önce OpenCodeSetup'ı, ardından EDA
Agent'ı kurun; OpenCodeSetup yapılandırma şablonunu yeniden kopyalayabilir.

Elle kurulumda varsayılan dizin Altium için `%LOCALAPPDATA%\EdaAgent`, KiCad için
`%LOCALAPPDATA%\EdaAgentKiCad` olur. EXE sihirbazı bunları sırasıyla
`%LOCALAPPDATA%\Programs\EdaAgent` ve `%LOCALAPPDATA%\Programs\EdaAgentKiCad`
altına kurar. `-InstallDir 'D:\Tools\EdaAgent'`
ile değiştirilebilir. Var olan kurulum dizini üzerine yazılmaz; güncellemede yeni
bir dizin seçin. Kurulum indirme veya paket çözümleme yapmaz, sistem PATH'ini değiştirmez.

`-ConfigureOpenCode` mevcut `%USERPROFILE%\.config\opencode\opencode.jsonc`
(yoksa mevcut `opencode.json`) dosyasına pakete göre yalnız `mcp.eda-agent` veya
`mcp.eda-agent-kicad` bağlantısını ekler.
API anahtarları ve diğer ayarlar korunur; dosyanın tarihli `.bak` yedeği alınır.
JSONC yorumları/biçimi JSON olarak yeniden yazılır. Geçersiz ayarlar değiştirilmez.
Geçersiz ayarlar dosya kopyalamadan önce reddedilir. Sonraki bir adım başarısız
olursa yeni kurulum dizini temizlenir ve bu kurulumun değiştirdiği Altium işaretçisi
eski haline getirilir. Geri alma başarısız olursa hata mesajındaki dizini inceleyin.
Özel dosya için `-OpenCodeConfig 'D:\config\opencode.jsonc'` kullanılabilir.
Bu seçenek verilmezse yalnız `opencode.mcp.json` ayar örneği oluşturulur.
MCP bağlantısında yavaş ilk açılışlar için `timeout: 60000` (60 saniye) kullanılır.
OpenCode'u yeniden başlatın. Diğer MCP istemcilerinde komut:
`<kurulum>\runtime\python.exe`, argüman: `<kurulum>\launch.py`.

OpenCode kaydını onarmak, MCP araç modunu anlamak veya gerçek EDA bağlantısını
doğrulamak için [bağlantı doğrulama rehberini](docs/baglanti-dogrulama.md) ve
[MCP bağlam ayarını](docs/mcp-context.md) kullanın. Elle kurulumda bu rehberlerdeki
EXE varsayılan yollarını kendi kurulum dizininizle değiştirin. Tanılama ve
`doctor` komutunun belge kaydetme uyarıları için de bağlantı rehberi esas alınır.

## Geliştirme ve doğrulama

`python tests/test_altium_connection_probe.py` ping probunu geçici workspace ve taklit
yanıtlarla sınar; Altium gerektirmez. Gerçek test ortamındaki yalnız ping kontrolü ve
menü prototipi adımları [doğrulama listesinde](docs/gelistirici/altium-menu-prototype-checklist.md)
bulunur. Bu depo aracı kurulum paketine dahil değildir.

Hedef bilgisayardaki Altium/KiCad bağlantısını sınamak için
[bağlantı doğrulama rehberini](docs/baglanti-dogrulama.md)
izleyin.

`tests\Test-OfflineBundle.ps1 -BundlePath '...\dist\EdaAgent-...'` geçici dizinde
kurulum, ayar birleştirme, hata durumunda geri alma, CMD başlatıcı ve bozuk paket
reddi kontrollerini çalıştırır. MCP bağlantısı dış ağ soketleri ve DNS erişimi
engellenerek sınanır; araçlar listelenir, tasarım araçları çağrılmaz. Gerçek
OpenCode ayarlarını veya makinenin Altium işaretçisini değiştirmez.
Gerçek EDA bağlantısı hedef ortamda ayrıca doğrulanmalıdır.
Bu test paketi Altium backend'i içindir. Gerçek OpenCode istemcisiyle ayrıca
`tests\Test-OpenCodeClient.ps1 -InstallDir '<test-kurulumu>' -OpenCodePath '<opencode.exe>'`
çalıştırılabilir; geçici istemci ayarları kullanılır, model çağrısı yapılmaz.

Kaynaklar: [eda-agent](https://github.com/salitronic/eda-agent),
[Python Windows](https://www.python.org/downloads/windows/),
[OpenCode MCP](https://opencode.ai/docs/mcp-servers/).

## Lisans

Bu depodaki özgün kurulum ve paketleme kodu [MIT lisansı](LICENSE) ile sunulur.
EDA Agent, Python, Inno Setup ve diğer üçüncü taraf bileşenler kendi lisanslarına
tabidir. Dağıtılan paketlerde upstream LICENSE/NOTICE dosyaları `upstream/`
altında, Python bağımlılıklarının lisansları runtime paket metadata dizinlerinde
korunur.
