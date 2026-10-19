# EDA Bağlantısını Doğrulama

Hedef bilgisayarda **OpenCode → MCP → açık EDA uygulaması** zincirini
doğrulamak için aşağıdaki adımları izleyin. OpenCode'da MCP'nin bağlı görünmesi
tek başına EDA bağlantısını doğrulamaz.

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
3. **Altium'a bağlan** düğmesine basın. Ek tanılama gerekiyorsa aşağıdaki
   kaydetme davranışını dikkate alıp **Bağlantıyı denetle** seçeneğini kullanın.

**Tanılama ve kaydetme:** Yardımcıdaki **Bağlantıyı denetle** seçeneği ve
`doctor` komutu, `application.save_all` kontrolünü de çalıştırır; açık Altium
belgelerini kaydedebilir. Kaydedilmemiş değişikliklerin korunması gerekiyorsa
bu adımı atlayıp aşağıdaki `app_ping` ve `get_board_info` kontrollerini kullanın.

PowerShell'den de tanılama yapabilirsiniz. EXE ile varsayılan kurulum için:

```powershell
& "$env:LOCALAPPDATA\Programs\EdaAgent\Start-EdaAgent.cmd" doctor
```

Özel bir kurulum dizini seçtiyseniz komuttaki yolu değiştirin. Sonuçta
**`DelphiScript polling loop responsive`** kontrolünün geçmesini bekleyin.

Bağlantı kurulmazsa Altium'da şu adımları uygulayın:

1. **DXP → Preferences → Scripting System → Global Projects → Install from file**
   üzerinden `<kurulum>\scripts\Altium_API.PrjScr` dosyasını tanıtın.
2. **File → Run Script → Dispatcher.pas → StartMCPServer → Run** çalıştırın.
   Bu adımı her Altium oturumunda uygulayın.
3. Tanılamayı yeniden çalıştırın.

OpenCode'u yeniden başlatıp şu isteği gönderin:

> `eda-agent` üzerinden `app_ping` aracını çalıştır. Ardından `get_board_info`
> ile açık PCB'nin bilgilerini oku. Tasarımı değiştirme.

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
- Dönen kart adı ve bileşen sayıları açık PCB ile eşleşmeli.
- `app_ping`, `kicad_ping` ve `get_board_info` kontrolleriyle tasarımı
  değiştirmeden doğrulama yapılmalı. `doctor` için yukarıdaki kaydetme davranışını
  dikkate alın.

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
2. Bu kuruluma ait `scripts\Altium_API.PrjScr` projesini kullanarak
   **Dispatcher.pas → StartMCPServer → Run** çalıştırın.
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
açın. Bu kurulumun `scripts` klasöründeki projeyi yükleyip `StartMCPServer`
çalıştırın. Yalnızca aynı eski projede scripti tekrar başlatmak derleme
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
- Doğru MCP bağlantısını kullanın; gerekirse `get_board_info` çağrısında
  `backend` değerini `altium` veya `kicad` olarak açıkça belirtin.
- Dönen kart adını açık belgeyle karşılaştırın. Sayıların eşleşmemesi durumunda
  tasarımı değiştiren araçları çalıştırmadan önce bağlantı seçimini düzeltin.

### MCP bağlı, ancak OpenCode model hatası veriyor

Model sunucusunun erişilebilirliğini ve OpenCode sağlayıcı ayarlarını kontrol
edin. Çevrimdışı bilgisayarda internet tabanlı model veya parça/datasheet arama
işlemleri çalışmayabilir. Model hatasını EDA bağlantı hatasından ayırın;
Altium'da salt okunur `app_ping` yerine model kullanmadan ek tanılama yapmak
isterseniz `doctor` komutunun kaydetme davranışını dikkate alın.

## Sorun Devam Ederse

Hata alırsanız kullanılan backend'i, başarısız aracın adını ve hata mesajını
kaydedin. Kurulum sürümünü, Altium/KiCad sürümünü, ping yanıtını ve varsa
`doctor` çıktısını da ekleyin. Paylaşmadan önce çıktılardaki API anahtarlarını,
kişisel yolları ve tasarım bilgilerini ayıklayın.
