# Sürüm Notları

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
