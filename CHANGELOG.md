# Sürüm Notları

## 0.1.8

- Belge denetimi ve PDF üretimi PATH üzerindeki ilk Node.js uygulamasını kullanır; birden fazla `node.exe` bulunduğunda PowerShell 5.1'in yolları tek geçersiz komutta birleştirmesi giderildi.
- 0.1.7 kaynak kapsamı bu sürüme dahildir. `v0.1.7` etiketi değiştirilmeden korunur; CI belge aşamasında başarısız olduğundan 0.1.7 Release'i yayımlanmadı. Yerel iki paket derlemesi ve otomatik kontrollerin geçmesi canlı Altium 26.7.1 native çalışma doğrulaması değildir; bu doğrulama hâlâ bekliyor.

## 0.1.7

- Mevcut `ShowConnectionAssistant` Customize girişi korunarak aynı dış yardımcıya doğrudan Başlat/Durum/Kes/Yeniden bağlan girişleri eklendi. Beş elle kayıt komutu `Altium-Menu-Commands.txt` içinde üretilir; otomatik profil/menü kaydı yapılmaz. Doğrudan işlem başarılı çağıran/oturum bağlamasından sonra bir kez çalışır; bağlama hatasında çalışmaz. Durum durmuş köprüyü başlatmaz; güvenli kesme/yeniden bağlanma belge kaydetmez. UIAutomation fixture'ı gerçek PowerShell/Python akışını, native callback taklidiyle sınar; Pascal veya canlı Altium 26.7.1 uyumluluğunu kanıtlamaz.
- Altium menüsü ve Başlat menüsü artık aynı TR/EN `Connection-Assistant.ps1` penceresini açar; ayrı native kontrol formu kaldırıldı. Elle menü komutunun yeni girişi `ConnectionAssistant.pas>ShowConnectionAssistant` oldu. Pencereyi açmak bağlantıyı başlatmaz; otomatik menü kaydı veya çoklu proje yönetimi eklenmedi.
- Korumalı yardımcı çağıran script bağlamına ve köprü oturumuna bağlanır; farklı/eski oturum sessizce devralınmaz. Başlatma ve güvenli kesme sonrası yeniden bağlanma tek Altium süreci, süreç oluşturulma zamanı ve tek kullanımlık başlatma niyetiyle denetlenir. Canlı Altium 26.7.1 menü/başlatma doğrulaması bekliyor; çevrimdışı kontroller sürüm uyumluluğu kanıtı değildir.
- Altium ve KiCad kaldırıcıları artık yalnız boş `workspace` klasörünü ve ardından boş kalan kurulum klasörünü siler. Kullanıcı dosyaları, gizli dosyalar ve alt klasörler korunur; çalışma alanı topluca silinmez. `tests/Test-UninstallWorkspace.ps1`, gerçek Inno kaldırma kurallarını ürün kaydı oluşturmayan yalıtılmış kurulumlarla iki paket için sınar.
- Altium `Start connection` işleminde bildirilen `variable <edamenucounter> not defined` hatası için `offline-assistant1`, `EdaMenuCounter` tanımını üretilen `Main.pas` dosyasından `StatusForm.pas` içine gömülen `MenuControl.pas` dosyasına taşır; tüm sayaç erişimleri aynı birimde kalır. Önceki yalnız `Inc` yerine normal atama değişikliği birimler arası erişimi kaldırmıyordu. Kök neden ve sonuç canlı Altium'da doğrulanmadı. Yalnız kaynak kod değişikliği kurulu scriptleri veya önceden üretilmiş EXE'leri güncellemez; `offline-assistant1` içeren yeni paket Altium kapalıyken kurulmalıdır. Sabitlenmiş sürümlerle yeniden üretim, yeniden açma/önbellek ve güvenli kilit kurtarma adımları için [menü kılavuzuna](docs/altium-menu-usage.md#güncelleme-kaldırma-ve-sessiz-kurulum) bakın.

## 0.1.6

- Türkçe kullanıcı belgeleri tek kurulum kılavuzu, kısa “İlk 5 dakika” rotası ve yetkili bağlantı/tanılama rehberi etrafında düzenlendi; sürüm kapsamı ile canlı EDA doğrulamasının sınırları açıklandı. Çevrimdışı belgeler yalnız kullanıcı içeriği ve görselleriyle sınırlandı; geliştirici bağlantıları depo web adreslerine taşındı. Kök `Build-Docs.ps1` tüm kullanıcı Markdown belgeleri için PDF üretir; `Test-Docs.ps1` yerel dosya ve başlık bağlantılarını denetler.
- Kullanıcı belgelerinin depo kökündeki yinelenen Markdown/PDF kopyaları kaldırıldı; tek kaynak `docs/` oldu. Belge denetimi bu kopyaların yeniden eklenmesini hata olarak bildirir.
- Her iki paket için kurulum/kaldırma aşamaları ve hata kodları kalıcı, tarihli tanı loglarına yazılır. Başlat menüsüne log klasörü kısayolu; Altium yardımcısına klasörü açma ve logları masaüstüne kopyalama düğmeleri eklendi. Loglar kaldırma sonrası korunur; yapılandırma içeriği ve API anahtarları kaydedilmez.
- Altium yanıt dosyası henüz yazılıyorsa geçici JSON/UTF-8 okuma hataları zaman aşımına kadar yeniden denenir; kalıcı bozuk yanıtlar da zaman aşımıyla sonlanır.
- Altium menü desteği seçiliyken çalışan Altium oturumları sihirbazın dosyaları kopyalamasından önce denetlenir.

- Altium için isteğe bağlı menü komutu hazırlığı ve beş işlemli TR/EN kontrol penceresi eklendi. Altium Customize kaydı elle yapılır; profil dosyaları otomatik değiştirilmez. Canlı Altium doğrulaması bekliyor.
- Yeni bağlantı yardımcısı asenkron çalışır; durum kontrolü doctor kullanmaz. Korumalı modda hedef proje seçimi, eski isteklerin geçersiz kılınması ve kaydetmeyen bağlantı kesme yolu eklendi.
- İlk korumalı kapsam yalnız pcb_get_components, pcb_get_nets ve pcb_move_components araçlarını içerir. Diğer tasarım araçları Python ve Pascal katmanlarında engellenir; mevcut tüm araçlarla uyumluluk iddiası yoktur.
- Sabitlenmiş Altium kaynaklarına hash kontrollü yerel overlay, kaynak değişiklik bildirimi ve patch manifesti eklenir. Yeniden kurulum menü sahipliğini ve tanımadığı durum alanlarını korur. KiCad yerel Altium adaptörünü içermez.
- Türkçe kurulum yollarının ANSI çıktı/işaretçi kodlamasında kaybolması giderildi: başlatıcı UTF-8 çıktı üretir; ANSI ile temsil edilemeyen Altium workspace yolları BOM'lu UTF-8 ve uyumlu Pascal okuyucuyla aktarılır.

## 0.1.5

- Altium menü entegrasyonu için kapsam, beş menü işlemi, çoklu proje/oturum kuralları ve kurulum/kaldırma kabul ölçütleri belgelendi. Menü entegrasyonu henüz uygulanmadı ve bu EXE'ler Altium'a yeni menü eklemez.
- Depodaki `tests/probe_altium_connection.py`, mevcut workspace'e yalnız IPC-v2 ping göndererek belge kaydetmeden kanal yanıtını kontrol eder. Oturum/proje kimliğini veya OpenCode bağlantısını doğrulamaz; kurulum paketine dahil değildir.
- Ping probunun geçici workspace üzerinde çalışan dört regresyon testi yayın akışına eklendi; canlı Altium prototipi için doğrulama listesi hazırlandı. Gerçek Altium denemesi ertelendi.
- Mevcut upstream `doctor` ve `application.stop_server` komutlarının belge kaydedebildiği belgelendi. Bağlantı yardımcısının mevcut davranışı bu sürümde değiştirilmedi.
- README'deki kurulum dosyası adları ve sürüm örnekleri güncellendi. Sabitlenmiş upstream ve Python sürümü değişmedi.

## 0.1.4

- Altium ve KiCad paketleri varsayılan olarak `minimal` MCP araç modunda başlar; yüzlerce araç şeması model bağlamına başlangıçta yüklenmez.
- Tüm araçlar `tool_catalog` ile keşfedilip `tool_invoke` ile çağrılabilir. `EDA_AGENT_TOOLSET=full` seçeneği korunur.
- Sabitlenmiş upstream ile Altium başlangıç verisi 778.233 bayttan 6.943 bayta, KiCad başlangıç verisi 82.259 bayttan 5.152 bayta düşer. Bunlar token sayısı değil, yönerge ve araç tanımlarının JSON boyutlarıdır.
- Çevrimdışı MCP kontrolleri araç kataloğu, parametre keşfi, çağrı yönlendirmesi ve Altium/KiCad ayrımını doğrular.
- Kurulumdan sonra OpenCode'u yeniden başlatıp yeni sohbet açın. Önceki konuşmanın geçmişi otomatik olarak küçülmez.

## 0.1.3

- Özgün kurulum ve paketleme kodu MIT lisansı ile sunulur; üçüncü taraf lisansları korunur.
- LICENSE dosyası çevrimdışı paketlere ve kurulum dizinine dahil edilir.
- EXE derlemesi, paketteki lisansın kaynak depodaki güncel lisansla eşleştiğini doğrular.

## 0.1.2

- GitHub Release yüklemeleri Windows PowerShell 5.1 yerine PowerShell 7 ile yapılır.
- Geçici bağlantı ve sunucu hatalarında dosya yüklemesi en fazla üç kez denenir; yarım kalan aynı adlı dosya taslaktan temizlenir.
- Dosya adı, boyutu, deneme sayısı ve tamamlanma süresi yayınlama loguna yazılır; HTTP istekleri zaman aşımıyla sınırlandırılır.
- Yeniden deneme, yetki hataları ve taslak koruması senaryoları PowerShell 7 üzerinde yayın öncesinde test edilir.

## 0.1.1

- Altium ve KiCad için ayrı kurulum paketleri üretildi; iki paket birlikte kurulabilir.
- Kurulum ve kaldırma işlemleri diğer paketin OpenCode bağlantısını ve kullanıcı dosyalarını korur.
- Altium bağlantı yardımcısı yalnız Altium paketinde bulunur.
- GitHub Actions, iki paketi derleyip otomatik kontrollerden sonra aynı Release altında yayımlar.
