# Altium menü prototipi — doğrulama adımları

Durum: Canlı Altium testleri kullanıcı isteğiyle ertelendi. Aşağıdaki adımlar
hazırlandı; hiçbir canlı test geçti olarak işaretlenmedi.

## Yerelde çalıştırılabilen kontrol

Standart Python ile depo kökünden:

```powershell
python tests/test_altium_connection_probe.py
```

Bu kontrol geçici workspace ve taklit yanıt kullanır. Altium'un kurulu olması gerekmez;
menü uyumluluğu, gerçek bağlantı veya tasarım işlemleri için kanıt değildir.

## Gerçek test ortamı hazırlanırken

- Lisanslı Altium'un tam sürüm/build numarası, Windows sürümü ve kullanılan backend
  commit'i kaydedilir. Ücretsiz deneme kurulumu şu an kapsam dışında bırakılmıştır.
- Disposable hesap ve tasarım kopyaları kullanılır. İki farklı klasörde aynı adlı
  iki proje hazırlanır; her birinde ayrı şematik ve PCB belgeleri bulunur.
- Hazır Altium paketi disposable ortamda kurulur. Gerçek OpenCode ayarları veya
  başka bir kullanıcıya ait ortak workspace işaretçisi testte kullanılmaz.
- Temel paket, yeni beş seçenekli menü uygulanmış gibi sunulmaz. Mevcut yardımcının
  Denetle düğmesi doctor çalıştırır ve belge kaydedebilir; bu testte kullanılmaz.
  Upstream application.stop_server da kaydedebilir; kaydetmeyen kesme testi yerine geçmez.

## En küçük Başlat menüsü prototipi

1. Disposable ortamda kurulan paketin scripts/Altium_API.PrjScr dosyasının bulunduğu
   doğrulanır. Otomatik profil düzenlemesi yapılmaz.
2. PCB belgesi açıkken View > Toolbars > Customize açılır. [Scripts] kategorisinde
   olmadan New seçilir; Process alanına ScriptingSystem:RunScript yazılır.
3. Parameters alanına gerçek kurulum yoluyla şu metin girilir:

   ```text
   ProjectName=<InstallDir>\scripts\Altium_API.PrjScr|ProcName=Dispatcher.pas>StartMCPServer
   ```

4. Caption olarak EDA Agent - Bağlantıyı başlat belirlenir; komut bir menüye veya
   araç çubuğuna sürüklenir. Customize kapatılıp komut çalıştırılır.
5. Aşağıdaki ping probuyla gerçek workspace kontrol edilir. Sıfır çıkış kodu,
   doğru oturum/proje veya OpenCode bağlantısının doğrulandığı anlamına gelmez.
6. Başlat komutu tekrar denenir; ikinci pompa/durum penceresi oluşmadığı kontrol edilir.
7. Altium kapatılıp yeniden açılır; menünün ve script yolunun kalıcılığı kontrol edilir.
   Şematik ve belge açık olmayan görünüm için erişim ayrıca denenir; PCB özelleştirmesinin
   diğer editörlerde otomatik bulunduğu varsayılmaz.
8. Kaldırma için Customize üzerinden yalnız oluşturulan komut/bağlantılar silinir.
   Restore kullanılmaz. Diğer özelleştirmelerin korunduğu kontrol edilir.

Yöntemin resmi kaynağı:
[Running Scripts](https://www.altium.com/documentation/altium-designer/scripting/running-scripts).
Bu adımların tamamı hâlâ canlı doğrulama bekler.

## Kaydetmeyen canlı ping probu

Gerçek test bilgisayarında, depo kökünden (yollar örnektir):

```powershell
& '<InstallDir>\runtime\python.exe' .\tests\probe_altium_connection.py --workspace '<InstallDir>\workspace' --timeout 10
```

Probe upstream'i import etmez, Altium'u başlatmaz ve proje seçmez. Var olan workspace'e
yalnız kendine ait IPC-v2 ping isteğini atomik yazar; yanıtı okuyup kendi dosyalarını
temizler. Protokol sabitlenmiş upstream commit'ine göre hazırlanmıştır. Canlı kullanımda
upstream günlükleri/son etkinlik zamanı değişebilir; “salt okunur” tasarım belgelerini
kaydetmeyen/değiştirmeyen komut anlamındadır.

| Çıkış kodu | Anlam |
| --- | --- |
| 0 | Geçerli IPC-v2 pong ve script sürümü alındı; kanal yanıt veriyor. |
| 1 | Workspace/erişim, geçersiz yanıt veya protokol hatası. |
| 2 | Süre doldu; köprünün çalışıp çalışmadığı bilinmiyor. |

Oturum ve proje doğrulama alanları bilinçli olarak false döner. Ping yanıtı script
sürümünü raporlar; kurulu kaynakla sürüm eşleşmesi ayrıca doğrulanmalıdır. Zaman
aşımından sonra geç yanıt dosyası oluşabilir; bunu temizlemek için workspace genelini
silen komut çalıştırılmaz. Bu araç ürünün son bağlantı durumu uygulaması değildir.

## Beş işlemin canlı doğrulama kayıtları

Her satır için tam sürüm/build, gözlenen sonuç ve kanıt kaydedilir. Kişisel/proje
yolları ve tasarım verileri paylaşılacak kayıtlardan çıkarılır.

| Senaryo | Beklenen sonuç | Durum |
| --- | --- | --- |
| Başlat, tekrar Başlat, yeniden açılış | Tek köprü; menü ve yol geçerli | Bekliyor |
| Bağlantı durumu, değiştirilmiş belge | Salt okunur sonuç; dosya kaydedilmez | Bekliyor |
| Hedef proje A; editörde B'ye geçiş | Seçim A kalır; B'ye değiştirici komut engellenir | Bekliyor |
| Aynı adlı iki proje | Tam yol gösterilir; doğru projeye yönlendirilir | Bekliyor |
| Hedefin kapanması, yeniden başlatma | Seçim geçersiz; eski hedef kullanılmaz | Bekliyor |
| Script projesi, projesiz ve bağımsız belge | Script hedef olmaz; belirsiz değiştirici işlem engellenir | Bekliyor |
| İki Altium oturumu | Doğru oturum veya belgelenmiş destek sınırı; mevcut köprü korunur | Bekliyor |
| Kes, değiştirilmiş belge | Köprü durur; proje/bellekteki değişiklikler korunur; disk kaydedilmez | Bekliyor |
| Komut sürerken kes/hedef değiştir | Yanlış hedefte devam veya yanlış başarı yok | Bekliyor |
| Yardım ve sorun giderme | Yardımcı açılır; yeniden bağlanma aynı güvenli kuralları uygular | Bekliyor |
| TR/EN, boşluk/Türkçe yol, offline | Beş işlem erişilebilir; ağ gerekmez | Bekliyor |
| Güncelleme/kaldırma | Başka özelleştirmeler ve yeni kurulumun kayıtları korunur | Bekliyor |

Disk kaydetmeme kontrolünde disposable belgelerin önce/sonra hash'i karşılaştırılır;
Altium'da değişmiş durumunun ve bellekteki değişikliğin korunduğu ayrıca gözlenir.
Proje hedefleme kontrolü, MCP üzerinden yürütülen işlemle yapılır; menü etiketini
görmek yeterli değildir. Henüz uygulanmamış seçenekler için sonuç “bekliyor” kalır.

Ürün uygulamasına geçiş koşulları ve kapsam:
[Altium menü entegrasyon planı](altium-menu-integration-plan.md).
