# Sürüm Notları

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
