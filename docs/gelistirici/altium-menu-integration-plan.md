# Altium içinde EDA Agent menüsü — uygulama planı

Durum: İsteğe bağlı menü kontrol penceresi, yerel adaptör ve kurulum hazırlığı uygulandı;
canlı Altium doğrulaması bekliyor. Korumalı mod başlangıçta üç PCB aracıyla sınırlı.
Tarih: 16 Ekim 2026; depo kodu incelemesi sonrası güncellendi.

Canlı deneme kullanıcı isteğiyle ertelendi. Yerel IPC ping probu ve disposable ortamda
uygulanacak adımlar [prototip doğrulama listesinde](altium-menu-prototype-checklist.md)
hazırlandı. Uygulamanın kapsam sınırları [menü kullanım belgesinde](../altium-menu-usage.md).
Geçici workspace ile test edilen probe ürün entegrasyonu veya canlı
Altium doğrulaması yerine geçmez.

## Amaç ve dağıtım kararı

Kullanıcı Altium içinden bir EDA Agent menüsü veya araç çubuğu düğmesiyle mevcut
script köprüsünü başlatabilmeli ve bağlantıyı denetleyebilmelidir. Her oturumda
File > Run Script üzerinden fonksiyon seçme ihtiyacını azaltmak hedeflenir.
Kabul edilen ilk sürüm menüsü bağlantı yönetimi, görünür hedef proje seçimi ve yardım
sağlar. Proje hedefinin uygulanması yalnız kurucu değişikliği değildir; MCP komutlarının
yürütüldüğü katmanda da doğrulanmalıdır.

Dağıtım mevcut Altium Inno Setup EXE'si üzerinden yapılacaktır. İlk sürümde
bağımsız bir eklenti kurucusu hedeflenmez. Altium paketinin kurulum sihirbazına
**Altium menüsüne EDA Agent ekle / Add EDA Agent to the Altium menu** seçeneği
planlanır. Bu seçenek yalnız desteklenen kayıt yöntemi doğrulandıktan sonra
uygulanacaktır. Inno Setup dosyaları dağıtır; Altium içi menü kaydı ayrı bir
entegrasyon adımıdır. Yalnız dosyaları kopyalamak menüyü oluşturmaz.

İlk tercih mevcut script köprüsünü çağıran menü/düğmedir. Altium'un desteklediği
özelleştirme yöntemi yeterli olmazsa native eklenti gereksinimi ayrıca değerlendirilir;
Altium uzantısı olduğu henüz doğrulanmamış bir paket eklenti olarak sunulmaz.

## Mevcut yapı

- README.md: Altium_API.PrjScr Global Projects'e eklenir; Dispatcher.pas içindeki
  StartMCPServer çalıştırılır. Köprünün her Altium oturumunda başlatılması gerekir.
- installer/Connection-Assistant.ps1: Bağlan düğmesi launch.py relaunch, denetle
  düğmesi launch.py doctor çalıştırır; elle kurulum yönergeleri de sunulur.
- EdaAgentOfflineSetup.iss: Altium için yardımcıyı kurar, Başlat menüsü kısayolu
  ekler ve kurulum sonunda açılmasını sağlar.
- installer/Unregister-Integration.ps1: Bu kurulumun OpenCode kaydını ve Altium
  workspace işaretçisini temizler; KiCad için Altium temizliği yapılmaz.
- Script kaynağı upstream paketidir. release-source.json içindeki sourceCommit
  sabitlenir; yerel entegrasyon upstream dosyalarının bütünlüğünü gözetmelidir.

## İlk sürümün kullanıcı akışı

1. Kullanıcı mevcut Altium EXE'sini çalıştırır; menü entegrasyonu seçeneğini seçer.
2. Kurucu desteklenen Altium kurulumlarını/kullanıcı profillerini belirler.
   Birden fazla hedef varsa açık seçim sunar; tüm sürümlere sessizce yazmaz.
3. Gerekiyorsa kullanıcıdan Altium'u kapatmasını ister. Açık profil dosyaları
   üzerine zorla yazılmaz. Kaydı Altium içinde yapmak gerekiyorsa yardımcı bunu
   açıkça yönlendirir ve sonuç doğrulanana kadar bekliyor durumu gösterir.
4. Kullanıcı Altium'u açar; doğrulanan özelleştirme yöntemine göre EDA Agent
   menüsü veya düğmesi görünür. İlk tercih menü, uygun değilse tek düğmedir.
5. Bağlantıyı başlat köprüyü çalıştırır; başarı salt okunur canlı kontrolle doğrulanır.
   Kullanıcı Hedef proje üzerinden açık tasarım projelerinden birini seçer. Seçilen proje,
   oturum ve geçerli belge Bağlantı durumu ekranında görünür. Seçim gerçekleşmeden
   tasarımı değiştiren komutlar yürütülmez. Modelle etkileşim mevcut OpenCode akışındadır.
6. Bağlantıyı kes köprüyü güvenli biçimde durdurur; Altium ve projeler açık kalır.
   Bekleyen/çalışan komut varsa durumu gösterir; belge kaydetme yan etkisi olmamalıdır.
7. Kaldırma yalnız sahipliği doğrulanan menü/kısayol kayıtlarını temizler; elle eklenen
   kayıtlar için aşağıda tanımlanan elle kaldırma yolu uygulanır.

Kullanıcının kabul ettiği ilk sürüm komutları:

| Türkçe | English | Davranış |
| --- | --- | --- |
| Bağlantıyı başlat | Start connection | Çağıran Altium oturumunda köprüyü başlatır; zaten çalışıyorsa korur. |
| Bağlantı durumu | Connection status | Salt okunur canlı kontrol, son kontrol zamanı, oturum, seçilen proje ve geçerli belgeyi gösterir. Mevcut doctor doğrudan kullanılmaz. |
| Hedef proje… | Target project… | Aynı oturumdaki açık tasarım projelerini tam yollarıyla listeler; seçimi gerçek komut hedeflemesine uygular. Script projesi tasarım hedefi olarak listelenmez. |
| Bağlantıyı kes | Disconnect | Yeni tasarım komutlarını durdurur ve köprüyü kaydetmeden kapatır; projeleri açık bırakır. Mevcut stop_server doğrudan kullanılmaz. |
| Yardım ve sorun giderme… | Help and troubleshooting… | Bağlantı yardımcısını, elle kurulum/kaldırma ve kurtarma adımlarını açar. Yeniden bağlan yalnız burada sunulur. |

Menü uygun değilse tek araç çubuğu düğmesi aynı beş işlemi içeren yardımcıyı açar.
Yeniden bağlan işlemi de kaydetmeyen güvenli kesme/başlatma kurallarına tabidir;
zaman aşımında zorla süreç sonlandırma veya koşulsuz --force kullanımı yapılmaz.

Bağlantı durumu istek üzerine yenilenir; sürekli bir gösterge değildir. Kopuk,
başlatılıyor, bağlı, kesiliyor, zaman aşımı ve hedef belirsiz durumları ayrılır.
Yanıt vermeyen köprü otomatik olarak durmuş sayılmaz. Bağlı durumu OpenCode'un
entegrasyonu yüklediğini kanıtlamaz; MCP istemcisi durumu ayrıca belirtilir.

Sohbet paneli, otomatik tasarım işlemleri, açılışta koşulsuz otomatik çalıştırma
ve sürekli durum göstergesi ilk sürüm kapsamına alınmaz. Başlat komutunun kabul
edilmesi tek başına bağlantı kurulduğu anlamına gelmez; başarı gerçek köprü
kontrolüyle gösterilir. Denetim tasarımı değiştiren bir komut çalıştırmaz.

### Oturum ve proje hedefi

Bir Altium oturumunda birden fazla proje açık olması ile aynı veya farklı Altium
sürümlerinde birden fazla uygulama oturumunun açık olması ayrı senaryolardır.
Kurulumda profil seçilmesi çalışma anındaki oturumu veya projeyi belirlemez.

- Başlat ve denetle işlemleri menünün çağrıldığı oturumu hedeflemelidir. Yardımcıdan
  yapılan işlemlerde hedef oturum doğrulanmalı; belirsizse seçim istenmeli veya işlem
  açıklayıcı bir sonuçla durdurulmalıdır. Başka oturumun köprüsü başarı sayılmamalıdır.
- Aynı oturumda birden fazla açık proje bulunması ilk sürümün doğrulama kapsamındadır.
  Köprünün başlaması herhangi bir projenin tasarım işlemleri için seçildiği anlamına gelmez.
- Upstream'in proje ve belge seçme davranışı incelenerek hedef belirleme kuralı
  belgelenmelidir. Aktif proje/belge değiştiğinde ve hedef proje kapandığında davranış
  doğrulanmalı; eski hedefe sessizce devam edilmemelidir. Hedef kesin belirlenemiyorsa
  tasarım komutu çalıştırılmadan önce açık seçim istenmeli veya komut durdurulmalıdır.
- Seçilen proje oturum süresince açık bir hedef olarak tutulur; editörde sekme değişimi
  seçimi sessizce değiştirmez. Belge hedefi bu projeyle eşleşmelidir. Açık project_path
  veya belge yolu seçime aykırıysa tasarım komutu durur ve hedef değiştirme yönlendirmesi
  gösterilir. Proje kapanınca veya Altium yeniden başlayınca seçim geçersizleşir.
- Seçim MCP komutlarının yürütüldüğü yerde uygulanmalıdır; yalnız UI etiketi veya editör
  odağını bir kez değiştirmek yeterli değildir. Dosya yolu alan araçlar, aktif belgeye
  dayanan araçlar ve tüm workspace'i etkileyen komutlar için kapsam tablosu hazırlanır.
  Hedeflemesi doğrulanmayan değiştirici komutlar seçili proje modunda engellenir.
  Projeye ait olmayan belgeler, paylaşılan belgeler ve kütüphaneler için davranış ayrıca
  tanımlanır; ilk sürümde belirsiz hedefler engellenir. Projesiz durumda bağlantı/durum/
  yardım kullanılabilir, değiştirici tasarım komutları kullanılamaz.
- Mevcut ortak workspace işaretçisinin oturumlar arasında yönlendirme etkisi araştırılmalıdır.
  Güvenilir oturum ayrımı doğrulanamazsa ilk sürüm tek açık Altium oturumuyla sınırlanmalı;
  ikinci oturumda başlatma/yeniden bağlanma açık uyarıyla durmalı ve mevcut köprü korunmalıdır.
  Bu sınırlama aynı oturumdaki çoklu proje senaryosunun yerine geçmez.

### Eşzamanlı işlemler ve kullanıcıya gösterilecek sonuç

Başlat/kes/yeniden bağlan/proje değiştir işlemleri aynı oturumda sıraya alınır;
tekrarlı tıklama ikinci bir işlem başlatmaz. Kesme veya hedef değişiminden önce yeni
değiştirici komut kabulü durdurulur, çalışan komutun sonucu beklenir. İşlem güvenli
biçimde tamamlanamıyorsa hedef değiştirilmez ve kesildiği iddia edilmez. Bekleyen
eski proje komutları yeni hedefte tekrar oynatılmaz. Sayısal zaman aşımı sınırları
ve iptal davranışı prototip sonucunda belirlenip uygulama öncesinde belgelenir.

## Aşama 1 — Teknik yapılabilirliği doğrula

Bu aşama desteklenen sürüm/çalışan ürün iddiasının ön koşuludur. Kullanıcının uygulama
talebiyle canlı test beklerken geliştirme yapıldı; otomatik profil kaydı uygulanmadı.
Henüz doğrulanmamış menü API'si, kayıt anahtarı veya sürüm uyumluluğu varsayılmamalıdır.

- Hedefte kullanılan Altium sürümlerini ve profil düzenini kaydet.
- Resmi Altium belgelerinden script fonksiyonuna menü/araç çubuğu komutu bağlama,
  özelleştirmeyi kalıcılaştırma ve geri kaldırma yöntemlerini incele.
- Sabitlenmiş upstream kaynağında StartMCPServer, relaunch ve doctor davranışlarını
  incele. Zaten çalışan köprü, yeniden çağırma, kapanış ve hata davranışlarını belirle.
- Kesme ve yeniden bağlanmada kaydetme yan etkilerini, çalışan komutla çakışmayı ve
  upstream durum penceresi/kapanma davranışını incele. Kaydetmeyen durdurma yolu doğrulanır.
- Hedef proje seçiminin MCP komutlarına uygulanabileceği katmanı belirle; desteklenen
  araçlar için hedef/kapsam tablosu ve odak değişimine karşı doğrulama prototipi hazırla.
  Bunun için upstream değişikliği gerekiyorsa ayrı patch veya yeni sabitlenmiş commit
  kullanımı seçilir; paketlenen upstream kaynakları belgesiz değiştirilmez.
- Aynı oturumdaki iki açık projede hedef proje/belge seçimini, aktif hedefin değişmesini
  ve kapanmasını incele. Aynı sürümün iki oturumu ile farklı sürümlerin eşzamanlı açık
  olduğu durumlarda köprü ve denetim hedefinin nasıl ayrıldığını doğrula. Ortak workspace
  işaretçisi ve diğer paylaşılan kaynakların etkisini kaydet; destek sınırını belirle.
- Lisanslı, disposable bir Windows hesabında en küçük menü/düğme prototipini dene.
  Altium yeniden açıldığında kaydın ve script yolunun geçerli kaldığını doğrula.
- Altium içinden dış yardımcı başlatma ve çıktı gösterme yöntemini dene. UI'nin
  kilitlenmemesi, zaman aşımı ve boşluk/Türkçe karakter içeren yolları sınama kapsamına al.
- Native eklenti gerekiyorsa SDK, derleyici, sürüm uyumluluğu ve çevrimdışı dağıtım
  gereksinimlerini belgeleyerek kapsam kararını ver.

Çıktı: Bu belgeye desteklenen sürümler, resmi belge bağlantıları, prototip sonucu,
kayıt/kaldırma yöntemi ve seçilen yaklaşım eklenir. Otomatik menü ekleme mümkün
olmazsa Inno Setup dosyaları kurar, yardımcı Altium içindeki tek seferlik elle
menü ekleme adımlarını sunar. Bu durumda kurulum otomatik menü eklendiğini söylemez.
Elle eklenen kayıt için sahipliğin doğrulanması da ayrıca değerlendirilir. Güvenilir
otomatik temizlik mümkün değilse elle kaldırma ve güncellemede script yolunu düzeltme
adımları sunulur; otomatik kaldırma taahhüdü bu kayıtları kapsamaz.

### 16 Ekim 2026 — Belge ve sabitlenmiş kaynak incelemesi

İncelenen commit: `f552f69175bea93c6f53571021852de43f05447f` (release-source.json).
Kaynak arşivi yalnız ignored .work/altium-menu-research altında açıldı;
SHA256: `c2f99681bee1ecb1517d149601dc95d44b8fc41001adb1339f68c00768e8d6bb`.
Bu sonuçlar statik incelemedir; desteklenen Altium sürümü veya çalışan prototip kanıtı değildir.

**Resmi belgelerden doğrulanan yöntem:**

- [Running Scripts](https://www.altium.com/documentation/altium-designer/scripting/running-scripts)
  script komutunu `ScriptingSystem:RunScript` ile tanımlar. Parametreler proje dosyası,
  script birimi ve prosedürü belirtir. Global Projects kaydı bu yöntem için zorunlu değildir.
  Komut editöre özgüdür; PCB komutu şematik editörde kendiliğinden görünmez. Dış uygulama
  başlatmak için `RunApplication` örneği de bulunur; çıktı toplama ve zaman aşımı doğrulanmış değildir.
- [Configuration & Customization](https://www.altium.com/documentation/altium-designer/configuration-customization)
  Customize üzerinden komut/menü oluşturma ve kaldırmayı açıklar; özelleştirmelerin
  profil altındaki `DXP.rcs` dosyasında tutulduğunu belirtir. Bu konumun belgelenmesi,
  kurucunun dosyayı güvenle birleştirebildiğinin veya otomatik kayıt API'sinin kanıtı değildir.
  Kullanıcının diğer özelleştirmelerini silen Restore yöntemi kaldırma için kullanılmayacak.

Başlat için prototip komutu (yer tutucu gerçek kurulum yoluyla değiştirilir):

```text
Process: ScriptingSystem:RunScript
Parameters: ProjectName=<InstallDir>\scripts\Altium_API.PrjScr|ProcName=Dispatcher.pas>StartMCPServer
```

Bu örnek henüz Altium'da denenmedi. PCB, şematik ve belge açık olmayan görünüm için
komut erişimi; yeniden açılışta kalıcılık; Türkçe/boşluk içeren yollar ayrı denenmeli.

**Sabitlenmiş upstream bulguları:**

- [cli.py](https://github.com/salitronic/eda-agent/blob/f552f69175bea93c6f53571021852de43f05447f/src/eda_agent/cli.py#L110):
  relaunch yanıt veren köprüyü `--force` olmadan tekrar başlatmaz. Başlatma isteğini
  X2 üzerinden iletir; sıfır çıkış kodu yeni köprünün çalıştığını doğrulamaz.
- [process_manager.py](https://github.com/salitronic/eda-agent/blob/f552f69175bea93c6f53571021852de43f05447f/src/eda_agent/bridge/process_manager.py#L280):
  süreç seçimi adayları, köprü durum penceresini ve görünür pencereleri değerlendirir;
  belirsiz durumda seçim yapmaz. Bu mantık dosya kanalının doğru oturuma bağlı olduğunu
  tek başına kanıtlamaz; aynı sürümün iki oturumuna X2 yönlendirmesi ayrıca sınanmalı.
- [Dispatcher.pas](https://github.com/salitronic/eda-agent/blob/f552f69175bea93c6f53571021852de43f05447f/scripts/altium/Dispatcher.pas#L39)
  StartMCPPump çağırır. [StatusForm.pas](https://github.com/salitronic/eda-agent/blob/f552f69175bea93c6f53571021852de43f05447f/scripts/altium/StatusForm.pas#L1538)
  çalışan pompa için erken döner. Bu koruma gerçek oturumda tekrarlı tıklama testiyle doğrulanmalı.
- [doctor.py](https://github.com/salitronic/eda-agent/blob/f552f69175bea93c6f53571021852de43f05447f/src/eda_agent/diag/doctor.py#L138)
  `application.save_all` çağrısını denetimlere dahil eder.
  [Application.pas](https://github.com/salitronic/eda-agent/blob/f552f69175bea93c6f53571021852de43f05447f/scripts/altium/Application.pas#L779)
  bunu SaveAllDirty işlemine yönlendirir. Mevcut yardımcı doctor kullandığından yeni ortak
  denetim akışı ayrıca değişmelidir. Menü denetimi kaydetme çağrısı yapmayan ping/sürüm
  kontrolü olarak tasarlanmalı; çevrimdışı health tek başına canlı bağlantı kanıtı sayılmamalı.
- [Project.pas](https://github.com/salitronic/eda-agent/blob/f552f69175bea93c6f53571021852de43f05447f/scripts/altium/Project.pas#L7)
  isteğe bağlı project_path bulunmayan ilgili işlemlerde DM_FocusedProject kullanır.
  Projeyi açmak odaklamayı garanti etmez; odak belgeyi izler. Bu nedenle köprü başlatılırken
  seçilmiş kalıcı bir proje olduğu varsayılmamalı; her aracın hedef davranışı ayrı değerlendirilmelidir.
- [Application.pas: App_StopServer](https://github.com/salitronic/eda-agent/blob/f552f69175bea93c6f53571021852de43f05447f/scripts/altium/Application.pas#L766)
  durmadan önce SaveAllDirty çağırır. Bu nedenle kabul edilen kaydetmeyen Bağlantıyı kes
  davranışı için doğrudan kullanılamaz. Alternatif durdurma yolu çalışan komut ve sonlandırma
  temizliğiyle birlikte doğrulanmalıdır; kaydetmeme şartı sağlanmadan özellik hazır sayılmaz.

**Geçici yaklaşım kararı ve kalan doğrulama:**

İlk prototip, mevcut upstream dosyalarını değiştirmeden Customize üzerinden elle
eklenen Başlat komutu olacak. Otomatik DXP.rcs yazımı ve kurucuda otomatik menü eklendiği
iddiası şu aşamada uygulanmayacak. Salt okunur denetim ve yardımcı açma adaptörü,
dış uygulama başlatma prototipi doğrulandıktan sonra tasarlanacak.
Bu başlangıç prototipi beş seçenekli ürünün tamamlandığı anlamına gelmez; hedef proje
uygulaması ve kaydetmeyen kesme, ilk sürümün ayrıca geçmesi gereken teknik koşullardır.

Bu inceleme sırasında çalışan X2/DXP süreci bulunmadı; lisanslı disposable test hesabı
ve sürüm matrisi doğrulanmadı. Gerçek profil değiştirilmedi veya tasarım komutu çalıştırılmadı.
Aşama 1 tamamlanmış sayılmaz: yeniden açılış, kayıt/kaldırma, çoklu proje/oturum,
UI yanıt verebilirliği ve dış yardımcı prototipi sonuçları hâlâ gereklidir.

## Aşama 2 — Entegrasyon ve kurulum

- Menü komutları için ince bir yerel adaptör oluştur; mevcut upstream köprüsünü
  tekrar kullan. Başlatma ve tanı işlemlerini tek ortak uygulamaya yönlendir.
- Bağlantı yardımcısını aynı komutları kullanan geri dönüş yolu olarak koru.
  Kurulum durumu, köprü durumu ve MCP istemcisi durumunu birbirine karıştırma.
- Beş kabul edilmiş işlemi menüde ve yardımcıda ortak davranışla sun. Hedef proje
  durumu ile MCP yürütme katmanını bağla; seçimin geçersizleşmesini ve eşzamanlı komutları
  yönet. Bu koşullar sağlanmadan yalnız menü başlıklarıyla proje seçimi sunma.
- Inno Setup'a yalnız Altium backend'inde görünen TR/EN seçeneği ve sonuç mesajları ekle.
  KiCad paketine Altium menü dosyası veya kaydı ekleme.
- Profil değişikliklerini kullanıcı kapsamıyla sınırla; Altium'un program dizinine
  veya ortak ayarlarına gereksiz yazma. Yönetici yetkisi gereksinimi varsa doğrula
  ve gerekçesini belgeleyerek alternatif kullanıcı kapsamını değerlendir.
- Mevcut özelleştirmeleri koru. Kayıttan önce doğrulanabilir yedek ve sahiplik
  bilgisi tut; aynı kurulumun yeniden çalışması çift menü oluşturmamalı.
- Sahiplik durumuna hedef profil/sürüm, kurulum kimliği, eklenen kayıt kimlikleri
  ve geri alma için gerekli bilgileri ekle. Mevcut setup-state.json yapısıyla
  uyumlu, sürümlenebilir bir şema seç.
- Install-Offline.ps1 şu anda setup-state.json dosyasını yalnız configPath alanıyla
  yeniden oluşturur. Durum yazımını yeni sahiplik alanlarını koruyacak şekilde değiştir;
  eski şemadan geçişi ve başarısız yeniden kurulumda önceki durumun geri yüklenmesini tanımla.
- Güncellemede değişen kurulum yolunu işle; eski sürüm kaldırılırken yeni sürümün
  menüsünü silme. Kullanıcı sonradan kaydı değiştirmişse üzerine yazma/silme.
- Menü seçeneğinin sonraki kurulumda kapatılması yeni kayıt oluşturmama anlamındadır;
  mevcut kaydı sessizce kaldırmaz. Mevcut kaydı koruma/kaldırma sonucu kullanıcıya
  gösterilir. Kayıt sahipliği ve yedekler kaldırma başarısızsa yeniden deneme için korunur;
  genel UninstallDelete temizliğinin bunları koşulsuz silmesi engellenir.
- Kayıt yarıda kesilirse yalnız o işlemin değişikliklerini geri al. Menü eklenemese
  de çalışan temel kurulum ve bağlantı yardımcısı kullanılabilir kalmalı; uyarıyı göster.
- Sessiz kurulumda menü seçeneğinin varsayılanını ve hedef profilin nasıl verileceğini
  tanımla. Hedef belirsizse rastgele profil seçme veya etkileşim bekleme. Temel kurulum
  hatası, menü entegrasyonu uyarısı ve Altium içinde tamamlanması beklenen kayıt için
  ayrı durumlar belirle; çıkış kodu, günlük ve kalıcı durum kaydını belgeleyip tutarlı uygula.

İlgili dosyalar ve olası değişiklikler:

| Dosya/alan | Planlanan sorumluluk |
| --- | --- |
| EdaAgentOfflineSetup.iss | TR/EN seçenek, dosya dağıtımı ve entegrasyon adımının çağrılması |
| installer/Invoke-Setup.ps1 | Kurulum akışına kayıt/durum yönetiminin bağlanması |
| Install-Offline.ps1 | Durum alanlarının korunması, şema geçişi ve kurulum hatasında önceki durumun geri yüklenmesi |
| installer/Connection-Assistant.ps1 | Menü kurulumu yönergeleri ve ortak bağlantı komutları |
| installer/Unregister-Integration.ps1 | Sahip olunan menü kayıtlarının güvenli temizliği |
| payload/ ve gerekirse installer/ altında yeni yardımcılar | Doğrulanan Altium adaptörü ve kayıt işlemleri |
| Sabitlenmiş upstream veya açıkça izlenen yerel patch | MCP hedef proje uygulaması ve kaydetmeyen kesme için gerekli değişiklikler; lisans/NOTICE ve patch doğrulaması |
| Build-OfflineBundle.ps1 ve Build-Installer.ps1 | Yeni dosyaların paketlenmesi, bütünlük ve eski paket kontrolü |
| tests/ ve .github/workflows/release.yml | Uygun otomatik kontrollerin mevcut doğrulamalara eklenmesi |
| README.md | Kurulum, desteklenen sürümler, menü kullanımı ve elle geri dönüş yolu |

Dosya adları ve kayıt biçimi Aşama 1 sonucunda kesinleştirilir. Paketlenen yardımcılar
değiştiğinde offline bundle yeniden üretilir; upstream LICENSE/NOTICE korunur.

## Aşama 3 — Doğrulama

Otomatik kontroller geçici profil ve dosyalarla çalışır; gerçek Altium ayarlarını
ve makine genelindeki workspace işaretçisini değiştirmez.

- Menü seçeneği açık/kapalı kurulum, olmayan/bozuk profil, birden fazla sürüm,
  tekrar kurulum, güncelleme, kayıt hatasında rollback ve kaldırma sahipliğini sınama.
- Var olan menülerin korunması, çift kayıt oluşmaması ve kullanıcı tarafından
  değiştirilmiş kaydın silinmemesi için regresyon kontrolleri ekle.
- Eski setup-state.json şemasından geçişi, menü alanlarının yeniden kurulumda korunmasını
  ve başarısız güncellemede geri yüklenmesini sına. Elle kayıt için seçilen kaldırma ve
  yol güncelleme davranışını doğrula.
- Sessiz kurulumda seçenek açık/kapalı, belirtilmiş/belirsiz hedef, menü hatası ve
  bekleyen kayıt durumlarını sına; çıkış kodu, günlük ve kalıcı durumun uyumunu doğrula.
- Komut yönlendirmesinde seçili proje ile açık yolun çelişmesi, hedefin kapanması,
  belge/sekme değişimi, kuyruktaki eski komutlar ve eşzamanlı hedef değiştirme/kesme
  durumlarını sına. Denetim ve kesmenin kaydetme komutu üretmediğini doğrula.
- Yeni adaptörlerin bundle kopyalama listesine, checksum manifestine, eski bundle
  denetimine ve kaldırma dosya listesine girdiğini doğrula. KiCad testleri Altium
  scriptlerini veya proje seçimi durumunu dağıtmadığını da kontrol etsin.
- Test-SetupWizard.ps1 ve Test-SeparatePackages.ps1 kapsamını uygun şekilde genişlet;
  KiCad paketinin Altium entegrasyonuna dokunmadığını doğrula.
- Etkilenen paket/başlatıcı davranışları için Test-OfflineBundle.ps1 ve mevcut
  yapılandırma regresyonlarını çalıştır. Her iki backend için build kontrollerini yap.

Gerçek Altium doğrulaması disposable Windows hesabında ayrıca yapılır:

- Desteklenecek her sürümde kurulum, menüden başlatma, denetim ve Altium'u yeniden
  açma; açık proje yokken ve köprü zaten çalışıyorken davranış.
- Aynı oturumda iki proje açıkken başlatma ve denetim; aktif proje/belge değişimi,
  hedef projenin kapanması ve belirsiz hedefte komutun durdurulması. Hedef doğrulamasında
  salt okunur sorgular kullan; tasarım işlemlerini ayrıca disposable örneklerde sına.
- Aynı adlı iki farklı yoldaki projeyi seçme, yanlış projeye ait belgeyi hedefleme,
  script projesinin listelenmemesi ve projesiz kullanım. Bağlantı durumundaki seçimin
  OpenCode üzerinden yürütülen işlemin gerçek hedefiyle eşleştiğini doğrula.
- Değiştirilmiş disposable belgelerle durum kontrolü ve bağlantı kesme; disk içeriğinin
  kaydedilmediğini ve bellekteki değişikliklerin/projelerin korunduğunu doğrula. Çalışan
  uzun komut sırasında kesme/yeniden bağlanma ve hedef değiştirmeyi ayrıca sına.
- Aynı sürümün iki oturumu ve farklı sürümlerin eşzamanlı açık olması: doğru oturumun
  seçildiğini veya belgelenmiş tek oturum sınırında işlemin güvenli durduğunu doğrula.
  İkinci oturumdaki işlem mevcut köprüyü ve workspace yönlendirmesini bozmamalıdır.
- Altium kapalıyken yardımcı, açıkken kayıt denemesi, zaman aşımı ve hata mesajları.
- TR/EN arayüz, boşluk/Türkçe karakter içeren kurulum yolu ve çevrimdışı kullanım.
- Güncelleme ve kaldırma sonrası kullanıcının diğer menü/kısayollarının korunması.
- Gerçek OpenCode bağlantısını ayrı doğrula; MCP araç listeleme testi gerçek EDA
  bağlantısının kanıtı olarak sunulmaz.
- Menü/düğme ve sihirbazın TR/EN ekran görüntülerini inceleme için kaydet.

## Kabul ölçütleri

- [ ] Desteklenen Altium sürümleri ve resmi menü kayıt yöntemi belgelenmiş.
- [ ] Mevcut Inno Setup Altium EXE'si entegrasyonu çevrimdışı dağıtıyor.
- [ ] Kullanıcı Altium içinden köprüyü başlatıp bağlantıyı denetleyebiliyor.
- [ ] Beş kabul edilmiş menü işlemi TR/EN mevcut; düğme alternatifi aynı işlemleri sunuyor.
- [ ] Bağlantı durumu ve bağlantıyı kes belgeleri kaydetmiyor; kesme projeleri açık tutuyor.
- [ ] Tekrarlı tıklama/kurulum çift köprü veya çift menü oluşturmuyor.
- [ ] Aynı oturumdaki çoklu projede hedef proje/belge kuralı belgelenmiş; hedef değişimi,
  kapanması ve belirsizliği sınanmış, yanlış projede işlem yapılmıyor.
- [ ] Hedef proje seçimi MCP yürütme katmanında uygulanıyor; odak değişimi seçimi
  değiştirmiyor, çelişkili ve doğrulanmayan değiştirici komutlar engelleniyor.
- [ ] Çalışan/bekleyen komutlarla kesme, yeniden bağlanma ve hedef değişimi güvenli;
  zaman aşımında bağlantı veya proje hedefi hakkında yanlış başarı gösterilmiyor.
- [ ] Çoklu Altium oturumunda doğru hedef doğrulanıyor veya belgelenmiş tek oturum
  sınırı güvenle uygulanıyor; başka oturumun köprüsü başarı olarak gösterilmiyor.
- [ ] Başarısız kayıt anlaşılır sonuç ve çalışan elle kurulum yolu sunuyor.
- [ ] Elle eklenen menü için kaldırma ve değişen script yolunu güncelleme yolu belgelenmiş.
- [ ] Güncelleme, geri alma ve kaldırma kullanıcı özelleştirmelerini koruyor.
- [ ] Durum şeması geçişi ve yeniden kurulum sahiplik alanlarını koruyor; başarısız
  güncelleme önceki durumu geri yüklüyor.
- [ ] Sessiz kurulumun hedef seçimi, kısmi başarı ve bekleyen kayıt durumları için
  çıkış kodu/günlük/durum kaydı sözleşmesi belgelenmiş ve sınanmış.
- [ ] KiCad ve diğer OpenCode MCP kayıtları etkilenmiyor.
- [ ] Otomatik kontroller ve gerçek Altium doğrulaması sonuçları kaydedilmiş.

## Uygulama sırası

1. Teknik prototip ve yaklaşım kararı.
2. Hedef proje uygulaması ve kaydetmeyen kesme prototipi; gerekirse upstream/patch kararı.
3. Beş işlem için menü/düğme adaptörü ve bağlantı yardımcısıyla ortak davranış.
4. Inno Setup seçeneği, kayıt, rollback ve kaldırma.
5. Regresyonlar, gerçek Altium doğrulaması ve ekran görüntüleri.
6. README güncellemesi, yeni bundle/EXE üretimi ve normal sürüm süreci.
