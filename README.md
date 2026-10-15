# EDA Agent — Çevrimdışı Windows Kurulumu

`salitronic/eda-agent` MCP sunucusunu internetsiz (air-gapped) Windows x64
bilgisayarlara taşınabilir bir paketle kurar. Python ve tüm Python bağımlılıkları
paketin içindedir; hedef bilgisayarda Python, pip, Git veya internet gerekmez.
Windows 10/11 x64 ve kurulu/lisanslı EDA uygulaması gerekir.

## 1. İnternetli bilgisayarda paketi hazırlayın

Windows PowerShell 5.1 veya üzeriyle bu klasörde çalıştırın:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-OfflineBundle.ps1
```

Varsayılan backend Altium'dur. KiCad için `-Backend kicad` ekleyin.
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

Varsayılan dizin `%LOCALAPPDATA%\EdaAgent` olur. `-InstallDir 'D:\Tools\EdaAgent'`
ile değiştirilebilir. Var olan kurulum dizini üzerine yazılmaz; güncellemede yeni
bir dizin seçin. Kurulum indirme veya paket çözümleme yapmaz, sistem PATH'ini değiştirmez.

`-ConfigureOpenCode` mevcut `%USERPROFILE%\.config\opencode\opencode.jsonc`
(yoksa mevcut `opencode.json`) dosyasına yalnız `mcp.eda-agent` bağlantısını ekler.
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

OpenCodeSetup yeniden kurulduğunda veya OpenCode ayarları sıfırlandığında EDA'yı
yeniden kurmadan mevcut bağlantıyı kaydetmek için (varsayılan dizinlerde):

```powershell
$edaDir = Join-Path $env:LOCALAPPDATA 'EdaAgent'
& "$edaDir\runtime\python.exe" "$edaDir\configure_opencode.py" "$env:USERPROFILE\.config\opencode\opencode.jsonc" "$edaDir\opencode.mcp.json"
```

`opencode.json` kullanıyorsanız komutta bu dosyayı belirtin.

## 4. EDA bağlantısını etkinleştirin

**Altium Designer:** DXP → Preferences → Scripting System → Global Projects →
Install from file ile `<kurulum>\scripts\Altium_API.PrjScr` dosyasını tanıtın.
Her Altium oturumunda File → Run Script → Dispatcher.pas → StartMCPServer → Run.
Köprü `%ProgramData%\eda-agent\workspace-path.txt` dosyasını kullanır; yazma izni
yoksa Bilgi İşlemden bu dizine erişim isteyin. Aynı anda farklı kullanıcıların
veya kurulumların Altium köprülerini çalıştırmayın; işaretçi makine genelindedir.

**KiCad:** KiCad 9+ içinde Preferences → Plugins → KiCad API server'ı açın.
EasyEDA Pro bu pakette desteklenmez.

```powershell
& "$env:LOCALAPPDATA\EdaAgent\Start-EdaAgent.cmd" health
& "$env:LOCALAPPDATA\EdaAgent\Start-EdaAgent.cmd" doctor
```

`doctor` Altium açık ve köprü çalışıyorken kullanılır. MCP sunucusu stdio üzerinden
istemci tarafından başlatılır; Windows servisi değildir. AI model erişimi ayrıdır:
internetsiz ortamda yerel veya kurum içi erişilebilir model sunucusu gerekir.
İnternet isteyen parça arama/datasheet indirme işlemleri çevrimdışı çalışmaz.
Başlatıcı `health`, `doctor`, `relaunch` ve `install-scripts` komutlarının script
konumunu da bu kurulumun `scripts` dizinine yönlendirir.

Sabitlenen upstream sürümünde `health`, kurulumun eklediği `UnitStamp` değerlerini
kaynak farkı sayarak temiz kurulumda da `deployed scripts current` uyarısı verebilir.
Doğrulama testimiz scriptleri beklenen damgalarla karşılaştırır. EasyEDA eklentisi
bu pakette derlenmediğinden onunla ilgili uyarı da beklenir; kritik bir Altium
hatası anlamına gelmez. Gerçek tasarım üzerinde çalışmadan önce `doctor` sonucunu
ve açık Altium oturumunu ayrıca kontrol edin.

## Geliştirme ve doğrulama

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
# EdaAgentOfflineSetup
