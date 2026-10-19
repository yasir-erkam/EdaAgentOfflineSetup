# EDA Agent Altium menüsü — geliştirme sürümü

Canlı Altium doğrulaması bekliyor. Bu belge kaynak ağacının **0.1.6** varsayılan
kurulum sürümündeki isteğe bağlı özelliği anlatır; bu, yayımlanmış paket veya
doğrulanmış Altium sürüm uyumluluğu iddiası değildir. Özellik varsayılan olarak
kapalıdır; KiCad paketine yerel menü adaptörü veya denetleyicisi eklenmez.
[Sürüm kapsamı](kullanim-kilavuzu.md#sürüm-kapsamı-ve-doğrulama-durumu) ve temel
[kurulum adımları](kullanim-kilavuzu.md#2-kurulum) kullanım kılavuzundadır.

## Kurulum ve menüyü ekleme

1. Tüm Altium oturumlarını kapatın. Yeni Altium kurucusunda **Altium menü komutunu
   hazırla** seçeneğini seçin. Temel OpenCode bağlantısı ayrı bir seçenektir.
2. Kurulum dizinindeki **Altium-Menu-Commands.txt** dosyasını açın. Kurucu profil
   dosyalarına yazmaz; kayıt durumu `pending-user-registration` olarak kalır.
3. Altium'da kullanacağınız editörü açın. **View > Toolbars > Customize > New** ile
   `ScriptingSystem:RunScript` komutu oluşturun. Dosyadaki Parameters değerini
   kopyalayın; Caption olarak **EDA Agent** girip menüye veya araç çubuğuna sürükleyin.
4. Komut `MenuForm.pas>ShowEdaAgentMenu` prosedürünü çalıştırır ve beş işlemi içeren
   TR/EN kontrol penceresini açar. Şematik/PCB gibi her editör için gerekirse aynı
   komutu ayrı ekleyin. Menü düğmesi/kısayol da aynı pencereyi açar.

Yöntem [resmi Altium komut özelleştirmesine](https://www.altium.com/documentation/altium-designer/scripting/running-scripts)
dayanır. Sürüm uyumluluğu, yeniden açılışta kalıcılık ve ekran görüntüleri canlı
Altium ile henüz doğrulanmadı. Kurulum “menü otomatik eklendi” sonucu vermez.

## Beş işlem

| İşlem | Davranış |
| --- | --- |
| Bağlantıyı başlat | Çağıran oturumda pompayı başlatır. Dış yardımcıdan başlatmak için tek açık Altium oturumu gerekir; başlatma sonrası yanıt kontrol edilir. |
| Bağlantı durumu | Belge kaydetmeden durumu, seçili projeyi ve odaktaki belgeyi gösterir. OpenCode istemcisinin bağlı olduğunu kanıtlamaz. |
| Hedef proje | Aynı oturumdaki açık `.PrjPcb` projelerini tam yollarıyla listeler. Script projesi listelenmez. Seçim oturum süresince tutulur. |
| Bağlantıyı kes | Kaydetme komutu göndermeden pompayı durdurur. Altium ve projeler açık kalır. Dış yardımcı sonlandırmanın tamamlandığını bekler. |
| Yardım ve sorun giderme | Elle kayıt/kaldırma, desteklenen kapsam ve yeniden bağlanma adımlarını sunar. Dış yardımcıda Yeniden bağlan yalnız bu bölümde görünür. |

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

Native pencerede çalışan handler sırasında hedef değiştirme/kesme isteği reddedilir;
dış yardımcıdan gelen kontrol isteği pompa tarafından sıralı işlenir. Zaman aşımı
başarı veya bağlantının kesildiği anlamına gelmez; zorla süreç sonlandırılmaz.

## Oturum kilidi ve kurtarma

Pompa `workspace/eda-menu-session.lock` adlı boş klasörü atomik oluşturarak workspace'i
sahiplenir. İkinci korumalı pompa aynı workspace'i sahiplenemez. Normal kapanışta
klasör kaldırılır. Çökme sonrası kilit otomatik çalınmaz: tüm Altium oturumlarını
kapattıktan sonra yalnız bu boş klasörü kaldırın. Eski veya başka kurulumun korumasız
köprüsünü eşzamanlı çalıştırmayın; upstream işaretçisi hâlâ makine genelindedir.
Çoklu oturum canlı testleri bekliyor.

## Güncelleme, kaldırma ve sessiz kurulum

Kurulum yolu değişirse Altium Customize içindeki Parameters yolunu güncelleyin.
Kaldırmadan önce yalnız EDA Agent komutunu Customize üzerinden silin; **Restore**
kullanmayın. Kurucu elle oluşturulan profil kaydını sahiplenmez veya otomatik silmez.
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
