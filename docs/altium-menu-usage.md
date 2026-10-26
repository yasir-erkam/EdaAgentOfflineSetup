# EDA Agent Altium menüsü — geliştirme sürümü

Canlı Altium doğrulaması, **26.7.1 dahil**, bekliyor; bu sürümün bulunmadığı veya
uyumsuz olduğu sonucu çıkarılamaz. Bu belge kaynak ağacının **0.1.8** varsayılan
kurulum sürümündeki isteğe bağlı özelliği anlatır; yayımlanmış paket veya
doğrulanmış sürüm uyumluluğu iddiası değildir. Özellik varsayılan olarak
kapalıdır; KiCad paketine Altium menü adaptörü veya denetleyicisi eklenmez.
[Sürüm kapsamı](kullanim-kilavuzu.md#sürüm-kapsamı-ve-doğrulama-durumu) ve temel
[kurulum adımları](kullanim-kilavuzu.md#2-kurulum) kullanım kılavuzundadır.

## Kurulum ve menüyü ekleme

1. Tüm Altium oturumlarını kapatın. Yeni Altium kurucusunda **Altium menü komutunu
   hazırla** seçeneğini seçin. Temel OpenCode bağlantısı ayrı bir seçenektir.
2. Kurulum dizinindeki **Altium-Menu-Commands.txt** dosyasını açın. Kurucu profil
   dosyalarına yazmaz; kayıt durumu `pending-user-registration` olarak kalır.
3. Altium'da kullanacağınız editörü açın. **View > Toolbars > Customize > New** ile
   her giriş için ayrı bir `ScriptingSystem:RunScript` komutu oluşturun. Aşağıdaki
   beş girişin Caption ve Parameters değerlerini kurulumun ürettiği
   **Altium-Menu-Commands.txt** dosyasından kopyalayın; menüye veya araç çubuğuna
   sürükleyin. Parameters içindeki kurulum yolunu elle tahmin etmeyin.

| Elle eklenecek giriş | `ConnectionAssistant.pas` prosedürü | Açılıştaki işlem |
| --- | --- | --- |
| EDA Agent | `ShowConnectionAssistant` | Yalnız yardımcıyı açar ve çağıran oturuma bağlar; bağlantıyı başlatmaz. Mevcut Customize girişini koruyabilirsiniz. |
| Bağlantıyı başlat | `StartConnectionAssistant` | Bağlama başarılı olduktan sonra Başlat işlemini bir kez çalıştırır. |
| Bağlantı durumu | `StatusConnectionAssistant` | Bir kez durum sorgular; durmuş köprüyü başlatmaz. |
| Bağlantıyı kes | `DisconnectConnectionAssistant` | Bir kez güvenli kesme ister; kaydetmez, Altium'u/projeleri kapatmaz. |
| Yeniden bağlan | `ReconnectConnectionAssistant` | Güvenli kesmenin onayından sonra yeniden başlatır. |

4. Beş giriş de Başlat menüsünden açılan aynı dış **Altium Bağlantı Yardımcısı**
   (`Connection-Assistant.ps1`) penceresini kullanır; ikinci bir native Altium
   kontrol arayüzü oluşturulmaz. Doğrudan işlem, çağıran script ve köprü oturumu
   doğrulandıktan sonra bir kez yürütülür; bağlama başarısızsa işlem yapılmaz.
   Şematik/PCB gibi her editör için gerekirse bu komutları ayrı ekleyin. Kurucu
   bu beş komutu otomatik kaydetmez; çoklu proje/oturum yönetimi eklenmez.

Yöntem [resmi Altium komut özelleştirmesine](https://www.altium.com/documentation/altium-designer/scripting/running-scripts)
dayanır. Sürüm uyumluluğu, yeniden açılışta kalıcılık ve ekran görüntüleri canlı
Altium ile henüz doğrulanmadı. Kurulum “menü otomatik eklendi” sonucu vermez.

## Beş işlem

| İşlem | Davranış |
| --- | --- |
| Bağlantıyı başlat | Tek açık Altium süreci doğrulandıktan ve çağıran script bağlamı denetlendikten sonra pompayı başlatır. Başlatma sonrası aynı çağıranın yeni oturum yanıtı doğrulanır. |
| Bağlantı durumu | Bağlı oturumun durumunu, seçili projeyi ve odaktaki belgeyi kaydetmeden gösterir. OpenCode istemcisinin bağlı olduğunu kanıtlamaz. |
| Hedef proje | Bağlı oturumdaki açık `.PrjPcb` projelerini tam yollarıyla listeler. Script projesi listelenmez. Tek hedef seçilir; seçim köprü oturumu süresince tutulur. |
| Bağlantıyı kes | Kaydetme komutu göndermeden bağlı pompayı durdurur ve aynı oturumun sonlandırılmasını bekler. Altium ve projeler açık kalır. |
| Yardım ve sorun giderme | Elle kayıt/kaldırma, desteklenen kapsam ve yeniden bağlanma adımlarını sunar. **Yeniden bağlan** burada görünür; güvenli kesme doğrulanmadan başlatmaz. |

Bağlantı yardımcısı artık `doctor` yerine salt okunur kontrol kullanır. Menü modu
kapalıysa yardımcıda Başlat/Durum/Yardım kullanılabilir; hedef seçme ve güvenli kesme
etkinleştirilmez. Upstream `doctor` ve `application.stop_server` komutlarının bağımsız
CLI kullanımı hâlâ belge kaydedebilir.

## Korumalı modun mevcut kapsamı

Bu ilk uygulama dar bir komut kümesiyle sınırlandırıldı. Sınırlama kurulum seçeneğinde
ve yardımcıda belirtilir; korumalı mod tüm EDA araçlarını desteklediği anlamına gelmez.

| MCP aracı | IPC komutu | Hedef kuralı |
| --- | --- | --- |
| `pcb_get_components` | `pcb.get_components` | Seçili projeye ait ve başka projeyle paylaşılmayan odaktaki PCB |
| `pcb_get_nets` | `pcb.get_nets` | Aynı PCB/odak/üyelik kontrolü |
| `pcb_move_components` | `pcb.batch_move_components` | Aynı PCB kontrolü; yalnız bu PCB'deki bileşenleri taşır/döndürür |
| `app_ping`, `app_get_version` | Ping/sürüm | Tasarım değiştirmez; proje seçimi gerekmez |
| `tool_catalog`, `tool_invoke`, `tool_guide` | Meta araçlar | Keşif açık; çağrılan tasarım aracı da aynı kapsam kontrolünden geçer |
| Diğer araçlar | Diğer komutlar | Hedef kapsamı incelenene kadar açık hata ile engellenir |

Python tarafındaki araç kaydı minimal ve full modda kapsam dışı işlemleri yürütmeden
engeller. Pascal dispatcher ayrıca seçili projenin açık olduğunu, istek seçim sürümünü,
odaktaki proje/belge üyeliğini ve gerçek PCB yolunu denetler. Sekme değiştirmek seçimi
değiştirmez; başka projeye odaklanıldığında işlem reddedilir. Yeni hedef seçimi önceki
bekleyen istekleri geçersiz kılar. Oturum yeniden başlayınca hedef seçimi sıfırlanır.
Korumalı modda Python UI otomasyonu ve web panosu kapatılır.

Yardımcıdan gelen kontrol istekleri pompa tarafından sıralı işlenir. Zaman aşımı
başarı veya bağlantının kesildiği anlamına gelmez; zorla süreç sonlandırılmaz.

Başlat menüsünden açılan yardımcı, korumalı modda önce tek Altium sürecini
doğrulayıp bu kurulumun scriptinden çağıran kimliğini edinir. Başlatma/yeniden
bağlanma süreç kimliği ve oluşturulma zamanı ile denetlenir; birden fazla Altium
süreci varsa görünür pencereye veya ilk sürece göre seçim yapılmaz. Başka workspace,
başka çağıran bağlamı veya yeniden başlamış bir köprü oturumu sessizce benimsenmez.
Eski yardımcı hata verirse doğru Altium oturumundaki menüden yeniden açın; durum
kontrolü eski pencereyi başka oturuma bağlamaz. Bu, çoklu proje/oturum yönetimi değildir.

## Oturum kilidi ve kurtarma

Pompa `workspace/eda-menu-session.lock` adlı boş klasörü atomik oluşturarak workspace'i
sahiplenir. İkinci korumalı pompa aynı workspace'i sahiplenemez. Normal kapanışta
klasör kaldırılır. Çökme sonrası kilit otomatik çalınmaz: tüm Altium oturumlarını
kapattıktan sonra yalnız bu boş klasörü kaldırın. Eski veya başka kurulumun korumasız
köprüsünü eşzamanlı çalıştırmayın; upstream işaretçisi hâlâ makine genelindedir.
Çoklu oturum canlı testleri bekliyor.

Başlatma onayı alınamazsa `workspace/eda-assistant-launch.lock` korunabilir.
Süresi geçmiş başlatma niyeti reddedilir; işlemi körlemesine yinelemeyin veya
çalışan Altium varken bu kilidi silmeyin. Yalnız **tüm Altium oturumları kapalıyken**
bu başlatma kilidini ve içindeki artık niyet/yanıt dosyalarını kaldırıp yardımcıyı
yeniden açın. Bu kilit, pompanın `eda-menu-session.lock` kilidinden ayrıdır.

## Güncelleme, kaldırma ve sessiz kurulum

`Start connection` sırasında bildirilen `variable <edamenucounter> not defined`
hatası için `offline-assistant1`, `EdaMenuCounter` tanımını üretilen `Main.pas` yerine
`StatusForm.pas` içine gömülen `MenuControl.pas` dosyasına taşır; tüm sayaç erişimleri
aynı birimde kalır. Önceki yalnız `Inc` yerine normal atama değişikliği birimler arası
sayaç erişimini kaldırmıyordu. Kök neden ve sonuç canlı Altium'da henüz doğrulanmadı.

Yalnız kaynak kod değişikliği kurulu scriptleri veya önceden üretilmiş EXE'leri
güncellemez; `offline-assistant1` içeren yeni paket kullanın. Yeniden üretmek için depo
kökünde `release-source.json` içindeki sabitlenmiş sürümleri kullanın:

```powershell
$config = Get-Content .\release-source.json -Raw | ConvertFrom-Json
.\Build-OfflineBundle.ps1 -Backend altium -SourceCommit $config.sourceCommit -PythonVersion $config.pythonVersion
.\Build-Installer.ps1 -Backend altium
```

Yeniden kurmadan önce tüm Altium oturumlarını kapatın. Ardından kurulu
`Altium_API.PrjScr` projesini kapatıp yeniden açın; eski derlenmiş birimler kullanılıyorsa
önbelleği temizlemek için Altium'u yeniden başlatın. Mevcut elle eklenmiş komutta
eski `MenuForm.pas>ShowEdaAgentMenu` yerine kurulumun güncel
`Altium-Menu-Commands.txt` Parameters değerini kullanın; yol değişmese de giriş
prosedürü değişmiştir. Eski workspace kilidi için
[Oturum kilidi ve kurtarma](#oturum-kilidi-ve-kurtarma) bölümüne bakın; yalnız tüm
Altium oturumları kapalıyken boş `workspace/eda-menu-session.lock` klasörünü kaldırın.

Kaldırmadan önce elle eklediğiniz EDA Agent girişlerini Customize üzerinden tek tek
silin; **Restore** kullanmayın. Kurucu profil kayıtlarını sahiplenmez veya otomatik silmez.
Korumalı menü kurulumu kaldırılırken açık Altium süreci varsa kaldırma durur.

Yeniden kurulum sahiplik kimliğini ve tanımadığı setup-state alanlarını korur.
Seçeneği sonraki kurulumda işaretlememek mevcut menü modunu kapatmaz. Menü modunu
kapatmak için tüm Altium oturumlarını kapatın, elle menü komutunu kaldırın ve yalnız
`workspace/eda-menu-enabled` dosyasını silin; sonra OpenCode'u yeniden başlatın.

Sessiz kurulumda `/TASKS=opencode,altiummenu` komut dosyasını hazırlar ve başarılı temel
kurulumda 0 döner; bu otomatik profil kaydı anlamına gelmez. Bekleyen elle kayıt
setup-state.json içinde tutulur. Temel yapılandırma hatası mevcut 10 çıkış kodunu
kullanır. Otomatik profil seçimi/yazımı olmadığından profil parametresi/yedeği oluşturulmaz.

Upstream kaynakları yalnız sabitlenmiş commit için hash kontrollü yerel overlay ile
değiştirilir. Kaynak dosyalarda değişiklik bildirimi ve farklı script sürümü bulunur;
`offline-menu-patch.json` öncesi/sonrası hash'leri kaydeder. LICENSE/NOTICE korunur.
Başka SourceCommit için menü overlay'i yeniden incelenmeden Altium paketi üretilmez.

Canlı testler: [depodaki prototip kontrol listesi](https://github.com/yasir-erkam/EdaAgentOfflineSetup/blob/main/docs/gelistirici/altium-menu-prototype-checklist.md)
(çevrimiçi geliştirici belgesi; çevrimdışı pakete dahil değildir).
