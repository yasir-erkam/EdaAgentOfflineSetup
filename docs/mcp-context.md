# EDA Agent sonrası context window hatası

EDA Agent'ın `full` modu tüm araç açıklamalarını ve parametre şemalarını MCP
istemcisine başlangıçta gönderir. Bunlar modelin bağlamını tüketir; konuşma
geçmişi ve modelin yanıtı için de yer gerekir.

0.1.4 ve sonraki paketlerin `launch.py` başlatıcısı, `EDA_AGENT_TOOLSET`
önceden tanımlanmamışsa varsayılan olarak `minimal` kullanır. Mevcut bir `full`
değerini otomatik değiştirmez.
Model yalnız `tool_catalog` ve `tool_invoke` araçlarını görür. Diğer araçlar
kaldırılmaz: model `tool_catalog(query="araç_adı", with_schema=true)` ile
gereken parametreleri öğrenir, ardından `tool_invoke` ile çağırır.

`app_ping`, `kicad_ping` veya diğer tasarım araçlarının istemcide ayrı ayrı
listelenmemesi bu modda beklenir. Modele gereken aracı `tool_catalog` ile
keşfedip `tool_invoke` üzerinden çalıştırmasını söyleyin. Gerçek EDA bağlantısı
için [bağlantı doğrulama rehberini](baglanti-dogrulama.md) izleyin. `full` moda
geçmek, isteğe bağlı Altium korumalı menü modunun araç kısıtlarını kaldırmaz.

## Mevcut kurulum için

OpenCode ayar dosyanızdaki mevcut EDA Agent MCP kaydına `environment` alanını
ekleyin; varsa mevcut ortam değişkenlerini koruyarak birleştirin:

```json
"environment": {
  "EDA_AGENT_TOOLSET": "minimal"
}
```

Altium kaydı `mcp.eda-agent`, KiCad kaydı `mcp.eda-agent-kicad` adındadır.
İkisi de etkinse her iki kayda da ekleyin. `command`, model ve sağlayıcı
ayarlarını koruyun. Bu ayar eski paketlerde de upstream'in minimal desteğini
etkinleştirir; yeniden kurulum gerekmez.

OpenCode'u tamamen kapatıp açın ve yeni bir sohbet başlatın. Eski konuşmadaki
büyük araç sonuçları geçmişte kalabilir. Hata sürerse tam hata mesajı, modelin
gerçek bağlam sınırı, istemcideki sınır ayarı ve diğer etkin MCP sunucuları
birlikte incelenmelidir. Buradaki değişiklik diğer MCP'lerin veya geçmişin
boyutunu azaltmaz.

Tüm şemaları başlangıçta isteyen istemcilerde `EDA_AGENT_TOOLSET=full`
ayarıyla tam moda dönülebilir.

Kaynak: [OpenCode MCP belgeleri](https://opencode.ai/docs/mcp-servers/).
