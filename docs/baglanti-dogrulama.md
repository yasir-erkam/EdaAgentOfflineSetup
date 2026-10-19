# EDA Bağlantısını Doğrulama

Hedef bilgisayarda **OpenCode → MCP → açık EDA uygulaması** zincirini
doğrulamak için aşağıdaki adımları izleyin. OpenCode'da MCP'nin bağlı görünmesi
tek başına EDA bağlantısını doğrulamaz.

Kurulum ve paket seçimi için [kullanım kılavuzunu](kullanim-kilavuzu.md) izleyin;
bu belge kurulumun yerine geçmez. [Sürüm kapsamı ve doğrulama durumu](kullanim-kilavuzu.md#sürüm-kapsamı-ve-doğrulama-durumu)
orada açıklanır. Aşağıdaki adımlar hedef bilgisayarda uygulanacak kontrollerdir;
başarılı bir canlı Altium/KiCad denemesi yapıldığı iddiası değildir.


## Ön Koşullar

- OpenCode ve kullandığınız EDA uygulamasına uygun EDA Agent paketi kurulu olmalı.
- Kurulumda **EDA Agent'ı OpenCode'a otomatik ekle** seçeneği etkin olmalı;
  elle yapılandırdıysanız ilgili MCP kaydı mevcut olmalı.
- Çevrimdışı ortamda OpenCode, erişilebilir bir yerel veya kurum içi modele
  bağlı olmalı. Model bağlantısı, EDA bağlantısından ayrı yapılandırılır.

## Altium Designer

1. Altium'u açıp bir PCB belgesi yükleyin.
2. Başlat menüsünden **EDA Agent for Altium → Altium Bağlantı Yardımcısı**
   uygulamasını açın.
3. **Bağlantıyı başlat** düğmesine basın. Ardından **Bağlantı durumu** ile
   köprünün yanıt verdiğini kontrol edin. Bu kontrol belge kaydetmez; tek başına
   OpenCode bağlantısını doğrulamaz.
4. İsteğe bağlı Altium menü desteği etkinse **Bağlantı durumu** ile proje
   listesini yenileyin, hedef `.PrjPcb` projesini seçip **Hedef proje…** düğmesine
   basın. Bu projeye ait PCB belgesini odakta tutun. Menü desteği kapalıysa
   hedef seçimi etkin değildir.

**Tanılama ve kaydetme:** Bağımsız `doctor` komutu, `application.save_all`
kontrolünü de çalıştırır; açık Altium belgelerini kaydedebilir. Kaydedilmemiş
değişikliklerin korunması gerekiyorsa bu komutu atlayıp yardımcının
**Bağlantı durumu** kontrolünü ve aşağıdaki salt okunur MCP isteklerini kullanın.

PowerShell'den de tanılama yapabilirsiniz. EXE ile varsayılan kurulum için:

```powershell
& "$env:LOCALAPPDATA\Programs\EdaAgent\Start-EdaAgent.cmd" doctor
```

Özel bir kurulum dizini seçtiyseniz komuttaki yolu değiştirin. Sonuçta
**`DelphiScript polling loop responsive`** kontrolünün geçmesini bekleyin.

Korumalı menü modu kapalıyken bağlantı kurulmazsa Altium'da şu adımları uygulayın:

1. **DXP → Preferences → Scripting System → Global Projects → Install from file**
   üzerinden `<kurulum>\scripts\Altium_API.PrjScr` dosyasını tanıtın.
2. **File → Run Script → Dispatcher.pas → StartMCPServer → Run** çalıştırın.
   Bu adımı her Altium oturumunda uygulayın.
3. Yardımcıdaki **Bağlantı durumu** kontrolünü yeniden çalıştırın.

Korumalı menü modu etkinse eski veya korumasız bir köprüyü ayrıca başlatmayın;
[menü kullanım rehberindeki](altium-menu-usage.md) bağlantı ve kurtarma adımlarını
izleyin. Canlı Altium doğrulaması hâlâ beklemektedir.

OpenCode'u yeniden başlatın. **Korumalı menü modu kapalıysa** şu isteği gönderin:

> `eda-agent` üzerinden `app_ping` aracını çalıştır. Ardından `get_board_info`
> ile açık PCB'nin bilgilerini oku. Tasarımı değiştirme.

**Korumalı menü modu etkinse** `get_board_info` kapsam dışında olduğundan
engellenir. Hedef proje seçili ve bu projenin PCB belgesi odaktayken şu isteği
gönderin:

> `eda-agent` üzerinden `app_ping` aracını çalıştır. Ardından
> `pcb_get_components` ve `pcb_get_nets` ile seçili projenin odaktaki PCB'sinin
> bileşenlerini ve netlerini oku. Tasarımı değiştirme.

Varsayılan minimal araç modunda model bu araçları `tool_catalog` ile keşfedip
`tool_invoke` ile çağırır; ayrı araçlar olarak listelenmemeleri bağlantı hatası
değildir. Ayrıntılar: [MCP bağlam ayarı](mcp-context.md).

## KiCad

1. KiCad 9+ PCB Editor'da bir kart açın.
2. **Preferences → Plugins → KiCad API server** seçeneğini etkinleştirin.
3. OpenCode'u yeniden başlatıp şu isteği gönderin:

> `eda-agent-kicad` üzerinden `kicad_ping` aracını çalıştır. Ardından
> `get_board_info` ile açık kartın bilgilerini oku. Tasarımı değiştirme.

KiCad paketi için Altium bağlantı yardımcısı veya DelphiScript kurulumu gerekmez.

## Başarı Ölçütleri

- Ping başarılı olmalı; KiCad için `kicad_ping` yanıtındaki `ok` değeri `true`
  olmalı.
- Dönen kart bilgileri ve bileşenler açık PCB ile eşleşmeli. Korumalı modda
  bileşen ve net listelerini seçili projenin odaktaki PCB'siyle karşılaştırın.
- Yukarıdaki salt okunur MCP kontrolleriyle tasarımı değiştirmeden doğrulama
  yapılmalı. `doctor` için kaydetme davranışını dikkate alın.

## Sorun Giderme

### OpenCode'da MCP görünmüyor veya başlatılamıyor

1. OpenCode'u tamamen kapatıp yeniden açın.
2. Altium için `eda-agent`, KiCad için `eda-agent-kicad` kaydını kontrol edin.
   Varsayılan yapılandırma `%USERPROFILE%\.config\opencode\opencode.jsonc`
   dosyasındadır; `.jsonc` yoksa mevcut `opencode.json` kullanılır. Özel bir
   yapılandırma seçtiyseniz o dosyayı kontrol edin.
3. Kaydın `enabled` değeri `true` olmalı. `command` dizisi, aynı kuruluma ait
   `runtime\python.exe` ve `launch.py` dosyalarını göstermeli; bu dosyalar
   diskte bulunmalı.
4. Kayıt eksikse mevcut kurulumun yardımcısıyla yeniden ekleyin. PowerShell'de
   aşağıdaki örneği kullanın; KiCad için ilk satırdaki dizini
   `Programs\EdaAgentKiCad` olarak değiştirin:

```powershell
$edaDir = Join-Path $env:LOCALAPPDATA 'Programs\EdaAgent'
$configPath = Join-Path $env:USERPROFILE '.config\opencode\opencode.jsonc'
if (-not (Test-Path -LiteralPath $configPath)) {
    $jsonPath = Join-Path $env:USERPROFILE '.config\opencode\opencode.json'
    if (Test-Path -LiteralPath $jsonPath) { $configPath = $jsonPath }
}
& "$edaDir\runtime\python.exe" "$edaDir\configure_opencode.py" $configPath "$edaDir\opencode.mcp.json"
```

Özel kurulum veya yapılandırma yolunuz varsa değişkenleri uyarlayın. Yardımcı,
mevcut ayarları birleştirir ve değiştirmeden önce yedek alır. Geçersiz JSON/JSONC
hatası verirse belirtilen dosyanın sözdizimini düzeltin; diğer MCP veya model
ayarlarını silmeyin. Ardından OpenCode'u yeniden başlatın.

### Altium: `app_ping` başarısız veya zaman aşımına uğruyor

1. Altium'un açık olduğunu kontrol edin. Bekleyen iletişim kutularını inceleyip
   uygun şekilde kapatın; script bunların arkasında bekliyor olabilir.
2. Korumalı menü modu kapalıysa bu kuruluma ait `scripts\Altium_API.PrjScr`
   projesinden **Dispatcher.pas → StartMCPServer → Run** çalıştırın. Korumalı
   modda yardımcının **Bağlantıyı başlat** işlemini ve
   [menü kullanım rehberini](altium-menu-usage.md) kullanın.
3. `%ProgramData%\eda-agent\workspace-path.txt` dosyasını salt okunur kontrol edin.
   İçindeki yol, kullandığınız kurulumun `workspace` klasörünü göstermeli.
   Yanlış yolu geçici olarak elle değiştirmek yerine doğru kurulumun bağlantı
   yardımcısını kullanın.
4. İşaretçi dosyasına erişim/yazma hatası varsa ilgili klasörün izinleri için
   sistem yöneticinize başvurun. Aynı makinede farklı kullanıcı veya kurulumların
   Altium köprülerini eşzamanlı çalıştırmayın.
5. OpenCode'u yeniden başlatıp `app_ping` isteğini tekrarlayın.

### Altium: eski script veya sürüm uyuşmazlığı bildiriliyor

`app_ping` yanıtında `version_match: false`, `script_location_match: false`
veya dolu bir `stale_units` listesi varsa yüklenen script kopyasını kontrol edin.
Eski `Altium_API.PrjScr` projesini kapatın, Altium'dan tamamen çıkın ve yeniden
açın. Bu kurulumun `scripts` klasöründeki projeyi kullanın. Korumalı menü modu
kapalıysa `StartMCPServer`, etkinse yardımcının **Bağlantıyı başlat** işlemiyle
bağlantıyı başlatın. Yalnızca aynı eski projede scripti tekrar başlatmak derleme
önbelleğini yenilemeyebilir.

`health` çıktısındaki `deployed scripts current` uyarısı, bu upstream sürümünde
kurulumun eklediği `UnitStamp` değerlerinden kaynaklanabilir. EasyEDA eklentisinin
derlenmemiş olması da bu pakette beklenir. Bunlar tek başına bağlantının bozuk
olduğunu göstermez; `app_ping` ve açık kart bilgilerini ayrıca doğrulayın.

### KiCad: `cannot reach KiCad's API server` veya `ok: false`

1. KiCad 9+ kullandığınızı ve **Preferences → Plugins → KiCad API server**
   seçeneğinin açık olduğunu kontrol edin.
2. KiCad'i tamamen kapatıp yeniden açın; PCB Editor'da kartı tekrar yükleyin.
3. OpenCode'u yeniden başlatın ve `eda-agent-kicad` üzerinden `kicad_ping`
   çalıştırın. Yanıttaki `reason` alanını inceleyin.
4. `kicad-python (kipy) is not installed` hatası varsa doğru KiCad paketini
   kullandığınızı kontrol edin. Paket bu bağımlılığı içerir; hasarlı veya eksik
   kurulum için KiCad kurulum EXE'siyle yeniden kurun.

### Ping başarılı, ancak kart bilgisi alınamıyor veya yanlış kart geliyor

- Yalnızca proje yöneticisi ya da şematik editörü yerine PCB belgesini açın
  ve hedef kartı etkinleştirin. KiCad'deki `no board is available` hatasında
  kartın PCB Editor'da yüklendiğini kontrol edin.
- Birden fazla kart/uygulama oturumu açıksa test için tek hedef kartla tekrar
  deneyin.
- Doğru MCP bağlantısını kullanın; korumalı menü modu kapalıysa gerekirse
  `get_board_info` çağrısında `backend` değerini `altium` veya `kicad` olarak
  açıkça belirtin. Altium korumalı modunda hedef projeyi yardımcıdan seçin;
  `get_board_info` yerine yukarıdaki bileşen/net kontrollerini kullanın.
- Dönen kart adını açık belgeyle karşılaştırın. Sayıların eşleşmemesi durumunda
  tasarımı değiştiren araçları çalıştırmadan önce bağlantı seçimini düzeltin.

### MCP bağlı, ancak OpenCode model hatası veriyor

Model sunucusunun erişilebilirliğini ve OpenCode sağlayıcı ayarlarını kontrol
edin. Çevrimdışı bilgisayarda internet tabanlı model veya parça/datasheet arama
işlemleri çalışmayabilir. Model hatasını EDA bağlantı hatasından ayırın;
Altium'da model kullanmadan kontrol için yardımcının **Bağlantı durumu**
işlemini kullanın. Bağımsız `doctor` komutuyla ek tanılama yapmak isterseniz
kaydetme davranışını dikkate alın. Bağlam sınırı hataları için
[MCP bağlam ayarını](mcp-context.md) inceleyin.

## Sorun Devam Ederse

Hata alırsanız kullanılan backend'i, başarısız aracın adını ve hata mesajını
kaydedin. Kurulum sürümünü, Altium/KiCad sürümünü, ping yanıtını ve varsa
`doctor` çıktısını da ekleyin. Kurulum/kaldırma sorunlarında günlükler
`%LOCALAPPDATA%\EdaAgentOfflineSetup\Logs` klasöründedir. Altium yardımcısındaki
**Log klasörünü aç** ile erişebilir veya **Logları masaüstüne kopyala** ile
kurulum/kaldırma günlüklerini dışa aktarabilirsiniz. Bu günlükler canlı EDA
bağlantısının kanıtı değildir; başarısız bağlantı kontrolünün çıktısını ayrıca
kaydedin. Paylaşmadan önce çıktılardaki API anahtarlarını, kişisel yolları ve
tasarım bilgilerini ayıklayın.

Her iki paketin Başlat menüsündeki **Logs** kısayolu da günlük klasörünü açar.
Ana konum yazılamazsa günlükler `%TEMP%\EdaAgentOfflineSetup\Logs` altına
yazılır; hata mesajında gösterilen yolu kullanın. Kurulum ve kaldırma için ayrı,
tarihli günlükler kaldırma sonrasında korunur. Günlükler aşama ve sayısal hata
kodlarını içerir; yapılandırma içeriği, API anahtarları ve alt süreç çıktısı
kaydedilmez. **Logları masaüstüne kopyala** yalnız bu tanı günlüklerini yeni bir
klasöre kopyalar; EDA tasarımını veya tüm çalışma alanını toplamaz.
