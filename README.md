# Muayenehane

Yalan söyleyerek kazanmaya çalıştığınız, komik tonlu, online çok oyunculu bir masaüstü blöf oyunu.
Esinlenilen oyunlar: Liar's Bar, Double Dealers, Scam With Your Friends.

Bekleme odasındaki herkes aynı hastalığı iddia ediyor ama yalnızca biri gerçekten hasta.
Doktor gerçek hastayı bulmaya çalışır; yanılırsa komplikasyon patlar.

- Tasarım belgesi: [docs/tasarim-belgesi.md](docs/tasarim-belgesi.md)
- Oyun projesi (Godot 4): [game/](game/)

## Şu anki durum: Kaotik klinik (v0.3)

Çizgi film görünümlü (kontur çizgili, toon gölgeli) mahalle kliniğinde üçüncü şahıs kamerayla dolaşırsın.
Her karakter rastgele görünümlü: kocaman sallanan kafa, oyuncak gözler, farklı burun/saç/bıyık,
hasta aksesuarları (sargı, boyunluk, buz torbası, göz bandı, alçı, termometre, gözlük).
Muz kabukları, kaygan zeminler, itilebilir eşyalar ve kendi kendine halay çekip hapşıran NPC'ler var.
Online ve oyun kuralları henüz 3D'ye taşınmadı (sıradaki adımlar).

## Nasıl oynarım?

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) indir (Windows için "Standard" sürüm yeterli, kurulum gerekmez, zip'ten çıkar).
2. Bu depoyu bilgisayarına indir (GitHub'da yeşil **Code** düğmesi → **Download ZIP**) ve zip'ten çıkar.
3. Godot'u aç → **Import** → `game/project.godot` dosyasını seç → **Import & Edit**.
4. Sağ üstteki **▶ (Play)** düğmesine bas veya **F5**.

### Kontroller

| Tuş | İşlev |
|-----|-------|
| W A S D | Yürü |
| Shift | Koş (kollar havada!) |
| Boşluk | Zıpla |
| Fare | Etrafa bak (önce oyun penceresine tıkla) |
| E | Hapşır: önündeki eşyalar ve insanlar savrulur |
| G | Halay çek (bitene kadar yürüyemezsin) |
| Q | El salla |
| 1-8 | Komplikasyon dene (balon kafa, uzayan kol, tavana yapışma, şişme, titreme, robot, uzun boyun, küçülme) |
| Esc | Fareyi serbest bırak |

Muz kabuklarına ve kaygan zemine basarsan kayıp düşersin. Diğer karakterler de ortalıkta dolaşıp
hapşırır, halay çeker ve muza basar.

### 2D kural prototipi

Oyunun kurallarını (roller, muayene, teşhis, puanlama) denemek için ilk 2D prototip hâlâ projede:
Godot editöründe `scenes/prototype_2d.tscn` dosyasını açıp **F6** ile çalıştır.
5-8 kişi aynı bilgisayarı sırayla kullanarak oynar.

## Geliştiriciler için

Testler (Godot komut satırından):

```
godot --headless --path game --import
godot --headless --path game -s res://tests/test_logic.gd   # kural testleri
godot --headless --path game -s res://tests/smoke_ui.gd     # 2D arayüzü baştan sona oynatan test
godot --path game -s res://tests/smoke_3d.gd                # 3D harita: yürüme, duvarlar, odalar
```

Klasörler:

- `game/scripts/game_logic.gd`: Oyun kuralları (arayüzden bağımsız, online sürümde host'ta çalışacak)
- `game/scripts/clinic.gd`: 3D klinik haritası (odalar, eşyalar, NPC'ler, ekran yazıları)
- `game/scripts/player.gd`: Üçüncü şahıs oyuncu kontrolü ve kamera
- `game/scripts/character_3d.gd`: Şekillerden 3D karakter, yürüme ve komplikasyon animasyonları
- `game/scripts/main.gd`, `character.gd`: 2D kural prototipi
- `game/data/diseases.json`: Hastalıklar, belirtiler, ilaçlar (yeni hastalık eklemek için burayı düzenle)
- `game/data/complications.json`: Komplikasyonlar ve ses efektleri
- `game/data/strings_tr.json`: Tüm Türkçe metinler
