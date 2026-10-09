# Muayenehane — Tasarım Belgesi (Taslak v0.1)

> Çalışma adı: **Muayenehane** (alternatifler: *Sahte Doktor*, *Hasta Numarası*, *Raporlu*)
> Durum: Fikir aşaması. Bu belgedeki her şey oyun denendikçe değişebilir.

## 1. Tek cümlelik özet

Bekleme odasındaki herkes aynı hastalığı iddia ediyor ama **sadece biri gerçekten hasta**. Doktor, doğru hastayı bulmaya çalışırken diğerleri bedava rapor ve ilaç için yalan söylüyor. Doktor yanılırsa ortaya çıkan komplikasyonlar (balon kafa, uzayan kol, değişen ses) oyunun en komik anlarını yaratır.

Esinlendiğimiz oyunlar: *Liar's Bar*, *Double Dealers*, *Scam With Your Friends*.

## 2. Hedefler

- **Komik:** Oyun kazanmaktan çok, ortaya çıkan anlar için oynanır.
- **Yayıncı dostu:** 30 saniyede anlatılır, her turda klip çıkar, izleyici kimin yalan söylediğini yayından izleyerek eğlenir.
- **Online:** 5-8 kişi, oda kodu ile katılım.
- **Türkçe:** Metinlerin tamamı çeviri dosyasından okunur (ileride İngilizce eklenebilsin).
- **Masaüstü** (Windows önce), sonra Steam.

## 3. Oyuncu sayısı ve süre

| Oyuncu | Doktor | Gerçek hasta | Simülant (sahte hasta) |
|--------|--------|--------------|------------------------|
| 5      | 1      | 1            | 3                      |
| 6      | 1      | 1            | 4                      |
| 7      | 1      | 1            | 5                      |
| 8      | 1      | 1            | 6                      |

- Her tur ~3-4 dakika.
- Herkes bir kez doktor olur. Oyun uzunluğu = oyuncu sayısı kadar tur (~20-30 dk).

## 4. Roller ve bildikleri

| Rol | Bildiği |
|-----|---------|
| **Doktor** | Hastalığın adı **ve** 3 gerçek belirtisi (Tıp Kitabı) |
| **Gerçek Hasta** | Hastalığın adı ve 3 belirtisi |
| **Simülant** | Sadece hastalığın adı |

Herkes kimin doktor olduğunu bilir. Hastalar birbirlerinin rolünü bilmez.

**Herkesin hedefi doktor tarafından seçilmek.** Gerçek hasta iyileşmek, simülantlar bedava rapor almak ister. Doktor ise doğru kişiyi bulmak ister.

## 5. Tur akışı

1. **Hazırlık (10 sn):** Roller dağıtılır, herkes kendi kartını görür.
2. **Muayene (~2 dk):** Doktor 5 soru hakkıyla hastalara soru sorar. Her soru tek bir hastaya yöneltilir ama **herkes cevabı duyar**. Hasta 20 saniye içinde cevap verir.
3. **Tartışma (30 sn):** Hastalar birbirini suçlayabilir, doktora telkin yapabilir.
4. **Teşhis (15 sn):** Doktor bir hasta seçer ve bir ilaç yazar.
5. **Açıklama:** Roller açılır. Doğruysa kutlama, yanlışsa **komplikasyon**.
6. **Puan tablosu** ve sıradaki doktor.

### Neden gerilimli?

- Doktor belirtileri bilir ama soruyu belirtiyi ele verecek şekilde sorarsa simülantlara ipucu verir ("Peynir görünce tavuk gibi mi ötüyorsun?" gibi). Bu yüzden **açık uçlu sorular** sormalıdır.
- Gerçek hasta doktora güven vermek ister ama aşırı ayrıntı vererek simülantlara yol göstermek istemez.
- Simülantlar sonra cevap verenlerden kopyalayabilir, ama kopya çok belli olur.

## 6. Puanlama

| Durum | Puan |
|-------|------|
| Doktor doğru hastayı seçti | Doktor +2, Gerçek Hasta +1 |
| Doktor bir simülantı seçti | Seçilen simülant +2 (doktoru kandırdı), Doktor −1 |

Oyun sonunda en çok puan alan kazanır. Denge, oynanış testlerinde ayarlanacak.

## 7. Komplikasyonlar (yanlış teşhis)

Doktor yanlış kişiyi seçince:

- **Doktor** "mesleki hata" komplikasyonu yaşar.
- **Seçilen simülant** yazılan ilacın yan etkisini yaşar (ödül gibi, komik).

Komplikasyonun türü **yazılan ilaca** göre belirlenir:

| Komplikasyon | Görsel (2D) | Ses efekti |
|--------------|-------------|------------|
| Balon Kafa | Kafa 3 kat büyür, sallanır, "pop" | Hafif helyum sesi |
| Uzayan Kol | Kol ekran dışına uzar, geri sekerek döner | Tiz, titrek ses |
| Tavana Yapışma | Karakter yukarı fırlar, ters döner | Ters çevrilmiş (yankılı) ses |
| Şişme | Gövde balon gibi şişer, havalanır | Pes, boğuk ses |
| Titreme Krizi | Karakter hızlı titrer, gözler ayrı yönlere döner | Titreşimli (tremolo) ses |
| Robot Sendromu | Parçalar köşeli hareket eder | Robot sesi |
| Boyun Uzaması | Boyun yaylanarak uzar | Hızlandırılmış ses |
| Küçülme | Karakter minik olur | Cırtlak ses |

Ses efekti **sonraki turun sonuna kadar** sürer. Efekt dinleyen tarafta uygulanır (sunucuya yük binmez).

## 8. Örnek hastalıklar (ilk 12)

Her hastalığın 3 belirtisi vardır. Hedef: 30-40 hastalık.

| # | Hastalık | Belirtiler | İlaç |
|---|----------|------------|------|
| 1 | Peynir Titremesi | Peynir görünce tavuk gibi ötüyor • Sağ ayağı kendi kendine dans ediyor • Rüyasında hep aynı fırıncıyla kavga ediyor | Ekşi Mayalı Şurup |
| 2 | Ayna Korkusu | Aynada kendine selam veriyor • Aynayı görünce "Pardon" deyip yol veriyor • Fotoğrafta hep gözleri kapalı çıkıyor | Parlak Damla |
| 3 | Ceket Alerjisi | Ceket giyince hapşırıyor • Hapşırınca tavana bakıyor • Yağmurda kendini şemsiye sanıyor | Pamuklu Pastil |
| 4 | Çay Hummalı Nöbet | Her 3 dakikada "demlik nerede" diyor • Konuşurken kaşıkla karıştırma hareketi yapıyor • İnce belli bardak görünce selam duruyor | Soğuk Çay Pomadı |
| 5 | Simit Kokusu Krizi | Sabahları kollarını martı gibi açıyor • Kimseyle konuşmadan "susam" diye mırıldanıyor • Parmak uçları hep sıcak | Susamlı Merhem |
| 6 | Servis Kaçırma Sendromu | Her sabah 7.30'da nereye gittiğini bilmeden koşuyor • Durak görünce el sallıyor • Kimse yokken "şoför abi" diyor | Duraklı Damla |
| 7 | Cumartesi Temizlik Nöbeti | Misafir gelecek hissedince halıyı kaldırıyor • Cam silerken ağlıyor • Evde kimse yokken terlik kontrolü yapıyor | Deterjanlı Tonik |
| 8 | Wi-Fi Çekmeme Hastalığı | Ayakta durunca sinyali artıyor • Elini havaya kaldırıp odayı geziyor • Oturunca "bağlanıyor..." diyor | Modem Şurubu |
| 9 | Kuaför Pişmanlığı | Saçına dokunurken iç çekiyor • Şapkasını hiç çıkarmıyor • "Sadece uçlardan" lafını duyunca titriyor | Saç Boyası Hapı |
| 10 | Pazar Pazarlığı Nöbeti | Her fiyata "son fiyat ne" diyor • Cebinde hep poşet taşıyor • Komşuyu görünce fiyat soruyor | Pazarcı Pastili |
| 11 | Düğün Halayı Zehirlenmesi | Davul sesi duyunca ayakları kendiliğinden oynuyor • Mendil yoksa çorabını sallıyor • Asansörde bile halay başı olmaya çalışıyor | Halay Şurubu |
| 12 | Bayat Ekmek Duygusallığı | Ekmek atılırken gözleri doluyor • Kuru ekmek görünce kuşlarla konuşuyor • Evinde "hatıra" diye ekmek torbası saklıyor | Kuru Ekmek Kapsülü |

## 9. Teknik yaklaşım (özet)

- **Motor:** Godot 4 (ücretsiz, masaüstü ve Steam desteği).
- **Görsel:** 2D. İlk sürümde karakterler basit **şekillerden** (daire, kutu) oluşur. Komplikasyonlar kodla ölçek/konum/açı değiştirilerek üretilir. Çizimler sonradan değiştirilebilir.
- **Ağ mimarisi:** Oyun mantığı tek bir yerde (host) çalışır, her oyuncuya sadece görmesi gereken veri gönderilir (örn. simülant belirtileri hiç görmez).
- **Ağ katmanı değiştirilebilir olacak:**
  - Erken yayıncı sürümü: Steam olmadan çalışır, oda kodu ile bağlanır (küçük bir sunucu).
  - Steam çıkışı: Steam lobi ve davet sistemi eklenir.
- **Sesli sohbet:** Ses efektleri için oyun içi sesli sohbet gerekir. Erken sürümde Discord'a güvenilir, ses efekti özelliği ayrı bir deneyle geliştirilir (en riskli parça).
- **Dil:** Tüm metinler tek bir çeviri dosyasında, Türkçe ile başlar.

## 10. Yol haritası

1. ✅ Tasarım belgesi (bu belge)
2. ✅ Tek bilgisayarda oynanan prototip (şekillerle): rol dağıtımı, tur akışı, teşhis ve komplikasyon
3. Online lobi: oda kodu, rollerin gizli dağıtımı
4. Ses deneyi: mikrofon + ses efekti
5. Komplikasyon animasyonları ve cila
6. **Yayıncı sürümü:** indirilebilir test sürümü, yayıncılara dağıtım
7. Steam entegrasyonu, mağaza sayfası, çıkış

## 11. Yayıncı dağıtım planı

- Steam çıkışından önce, seçilmiş yayıncılara indirilebilir sürüm (Steam gerektirmeyen).
- Yayıncı modu: oda kodunu gizleme, telifsiz müzik.
- Yayıncının izleyicileri için ileride: sohbetten oylama ya da ilaç seçimi.
- Klip anlarını kolay yakalamak için komplikasyon animasyonlarının uzunluğu ve kamera vurgusu özenle ayarlanacak.

## 12. Açık sorular

- Puanlama dengeli mi? (Simülantlar çok avantajlı olabilir.)
- 5 soru hakkı yeterli mi, fazla mı?
- Gerçek hasta sayısı büyük odalarda (7-8) 2 olmalı mı?
- "Sahte Doktor" gibi ek roller eklenmeli mi (ikinci aşama)?
- Oyunun nihai adı.
