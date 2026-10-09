# Muayenehane

Yalan söyleyerek kazanmaya çalıştığınız, komik tonlu, online çok oyunculu bir masaüstü blöf oyunu.
Esinlenilen oyunlar: Liar's Bar, Double Dealers, Scam With Your Friends.

Bekleme odasındaki herkes aynı hastalığı iddia ediyor ama yalnızca biri gerçekten hasta.
Doktor gerçek hastayı bulmaya çalışır; yanılırsa komplikasyon patlar.

- Tasarım belgesi: [docs/tasarim-belgesi.md](docs/tasarim-belgesi.md)
- Oyun projesi (Godot 4): [game/](game/)

## Şu anki durum: Prototip v0.1

Tek bilgisayarda sırayla oynanan (hot-seat) prototip. Amaç: kuralların eğlenceli olup olmadığını denemek.
Karakterler basit şekillerden oluşuyor, online ve sesli sohbet henüz yok.

## Nasıl oynarım?

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) indir (Windows için "Standard" sürüm yeterli, kurulum gerekmez, zip'ten çıkar).
2. Bu depoyu bilgisayarına indir (GitHub'da yeşil **Code** düğmesi → **Download ZIP**) ve zip'ten çıkar.
3. Godot'u aç → **Import** → `game/project.godot` dosyasını seç → **Import & Edit**.
4. Sağ üstteki **▶ (Play)** düğmesine bas veya **F5**.

## Oyun akışı

1. Menüde oyuncu sayısını (5-8) ve isimleri gir.
2. Her oyuncu sırayla bilgisayarı alıp gizlice rolünü görür (Doktor / Gerçek Hasta / Simülant).
3. **Muayene:** Doktor 5 soru sorar. Sorular ve cevaplar sesli söylenir, ekranda kime sorulduğu ve süre görünür.
   Doktor "Tıp Kitabı" düğmesini basılı tutarak gerçek belirtileri görebilir (diğerleri bakmasın!).
4. **Tartışma:** 30 saniye suçlama ve ikna.
5. **Teşhis:** Doktor bir hasta ve bir ilaç seçer.
6. Yanlış teşhiste doktor ve seçilen simülant ilacın yan etkisini yaşar (balon kafa, uzayan kol, şişme...).
7. Herkes bir kez doktor olunca oyun biter, en çok puan alan kazanır.

## Geliştiriciler için

Testler (Godot komut satırından):

```
godot --headless --path game --import
godot --headless --path game -s res://tests/test_logic.gd   # kural testleri
godot --headless --path game -s res://tests/smoke_ui.gd     # arayüzü baştan sona oynatan test
```

Klasörler:

- `game/scripts/game_logic.gd`: Oyun kuralları (arayüzden bağımsız, online sürümde host'ta çalışacak)
- `game/scripts/main.gd`: Ekranlar ve oyun akışı
- `game/scripts/character.gd`: Şekillerden karakter ve komplikasyon animasyonları
- `game/data/diseases.json`: Hastalıklar, belirtiler, ilaçlar (yeni hastalık eklemek için burayı düzenle)
- `game/data/complications.json`: Komplikasyonlar ve ses efektleri
- `game/data/strings_tr.json`: Tüm Türkçe metinler
