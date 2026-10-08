# FarmCraft — Oyun Tasarım & Geliştirme Planı

Birinci şahıs 3D çiftlik simülasyonu + hayvancılık. Godot 4.7 · GDScript · Forward+.

## Onaylanan kararlar
- **Grafik:** Gerçekçi stil. Zemin, ahşap, çatı, taş, ağaç kabuğu ve yapraklar için Poly Haven CC0 foto dokular
  (`tools/fetch_textures.py`, ~80 MB); modeller kodla üretilir (kart tabanlı ağaçlar, foto dokulu binalar).
  Eşya ikonları 3D modellerden render edilir (`tools/icon_studio.gd`).
- **Dil:** Türkçe + İngilizce (varsayılan Türkçe).
- **Hayvanlar:** Tavuk, Ördek (kümes) · Koyun, Keçi, İnek, Domuz (ahır). Kesim yok, canlı satış var.
- **Enerji/stamina:** Yok.
- **Kamera:** Birinci şahıs.

## Ana döngü
Çapala → Ek → Sula → Hasat → Sat → Hayvan al → Besle & büyüt → Ürün topla/işle → Sat → Çiftliği büyüt

## Kontroller
WASD hareket · Shift koş · Space zıpla · Fare bakış · Sol tık (basılı) alet kullan · E etkileşim ·
1–8 / tekerlek hotbar · Tab envanter · Q eşya at · R döndür · Esc menü · F12 ekran görüntüsü

---

## Hayvancılık sistemi
- Satın alma: yavru (ucuz, büyütülür) veya yetişkin (pahalı, hemen üretir); isim verme; binada yer şartı.
- Yaşam döngüsü: Yavru → Genç → Yetişkin; yalnızca doyurulduğu günler büyür; kilo artar.
- İhtiyaçlar: Açlık · Susuzluk · Mutluluk · Sağlık · Sevgi (0–5 kalp).
- Besleme: yemlik, elden besleme (+sevgi), merada otlatma (bedava, kışın yok), suluk (sulama kabıyla).
- Ürünler: yumurta, süt (kova), keçi sütü (kova), yün (makas), ördek tüyü, trüf (domuz dışarıda).
  Sevgi ↑ → gümüş/altın kalite.
- Bakım: sevme, fırçalama, ahır temizliği → gübre (tarlada kalite/hız bonusu).
- Sağlık: ihmal → hastalık → ilaç / veteriner (ücretli).
- Üreme: kuluçka makinesi, mutlu ahır hayvanlarında doğum.
- Besicilik: satış değeri = kilo × kondisyon (sağlık + mutluluk).
- AI: dolaşma, yemlik/suluğa gitme, otlama, akşam içeri dönme, uyku, elde yem varsa takip.
- UI: hayvan bilgi paneli + Çiftlik Yönetimi ekranı.
- Binalar: Kümes, Ahır (+yükseltme), Silo, çitli mera.

## Ekonomi
- Zaman: 1 oyun saati ≈ 30 sn → gün (06:00–02:00) 10 dk (ayarlardan 8/10/12). 4 mevsim × 10 gün. Yeni oyunun ilk günü 13:00'te başlar (hikâye sürerken saat biraz yavaşlar: 1. gün 13:00–20:00 ve 2. gün 06:00–19:30 onar gerçek dakika sürer; ilk gün ekilip sulanan buğday ertesi sabah olgun); sonraki her sabah 06:00. Hikâye takvimi değil oyuncuyu izler: ilk iki günün görevleri bu onar dakikadan uzun sürer (1. gün 25–40 dk, 2. gün ~25 dk), takvim hikâyenin önüne geçer. Hikâyenin "sabahı bekle" adımları (serbest akşam, horoz, gölet) takvim gününe bakmaz, görev geldikten sonraki ilk sabah açılır; pazar hasadında biçilecek ekin kalmadıysa yataklar bir kereliğine olgunlaşır, o da yoksa görev kendiliğinden geçer.
- Para birimi dolar; para yalnızca satıştan gelir (görevler ve başarımlar para vermez). Güncel fiyatlar: docs/BALANCE.md.
- Başlangıç: 150 dolar (ilk gün iki tavuk 2 × 50 dolar), temel aletler, 12 parselli tarla, 15 tohum.
- Satış = Taban × Kalite (1 / 1,25 / 1,5) × Günlük piyasa (0,85–1,15) × Doygunluk (≥0,6) × Mevsim (mevsim dışı +%20)
- Tüccar 08:00–18:00 açık; satış kutusu gece satar; her sabah gün sonu raporu.

### Ürünler
| Ürün | Tohum | Büyüme | Tekrar | Verim | Satış | Mevsim | ~Kâr/parsel/gün |
|---|---|---|---|---|---|---|---|
| Buğday | 1 | 1 gün | – | 2 + saman | 2 | İ/Y/S | 3 + saman |
| Havuç | 2 | 1,5 gün | – | 2 | 4 | İ/S | 4 |
| Patates | 2 | 2 gün | – | 2–4 | 3 | İ/S | 3,5 |
| Domates | 5 | 3 gün | 1,5 gün | 3 | 3 | Y | 6 |
| Mısır | 4 | 3,5 gün | 2 gün | 2 | 4 | Y/S | 4 |
| Patlıcan | 6 | 2,5 gün | 2 gün | 2 | 5 | Y/S | 5 |
| Çilek | 10 | 4 gün | 2 gün | 3 | 5 | İ | 7,5 |
| Balkabağı | 12 | 6 gün | – | 1 | 45 | S | 5,5 |

### Hayvanlar
| Hayvan | Yavru / Yetişkin | Yetişkinlik | Günlük yem | Ürün | Ham → İşlenmiş |
|---|---|---|---|---|---|
| Tavuk | 20 / 50 | 3 gün | 1 yem | Yumurta, her gün | 5 |
| Ördek | 180 / 450 | 4 gün | 1 yem | Ördek yumurtası 2 günde 1 + tüy | 45 → 110 |
| Koyun | 360 / 900 | 5 gün | 1 saman | Yün, 3 günde 1 | 120 → Kumaş 280 |
| Keçi | 400 / 1.000 | 5 gün | 1 saman | Keçi sütü, 2 günde 1 | 70 → Keçi peyniri 170 |
| İnek | 600 / 1.500 | 6 gün | 2 saman | Süt, her gün | 50 → Peynir 120 / Tereyağı 105 |
| Domuz | 640 / 1.600 | 7 gün | 2 saman / sebze | Trüf (dışarıda) | 80 → Trüf yağı 150 |

- Hayvan tüccarı: Yem 5 · Saman 12 · İlaç 80 · Fırça 150 · Yaba 200 · Süt kovası 300 · Makas 350
- Satış değeri (tam kondisyon yetişkin) = yetişkin fiyatının %80'i.

### İşleme makineleri
Mayonez makinesi · Peynir makinesi · Yayık · Dokuma tezgâhı · Yağ presi ·
Değirmen (3 buğday → un) · Yem makinesi (buğday + mısır → 6 yem) · Kavanoz (turşu/reçel, 2× + 20)

### Yapılar & genişleme
| Yapı | Maliyet | Etki |
|---|---|---|
| Kümes / yükseltme | 1.000 + 100 odun, 50 taş / 4.000 + 20 demir | 4 → 8 kanatlı, kuluçka |
| Ahır / yükseltme | 4.500 + 200 odun, 100 taş / 10.000 + 50 demir | 4 → 8 hayvan, otomatik suluk |
| Silo | 1.000 + 100 taş | 240 saman, yemlikleri doldurur |
| Tarla genişletme I/II/III | 1.000 / 3.000 / 8.000 | +12 parsel |
| Sera | 25.000 + malzeme | 24 parsel, her mevsim |
| Alet yükseltme Demir/Usta | 1.000 + 10 demir / 4.000 + 25 demir | hız, kapasite, alan |

---

## Yol haritası

### Faz 0 — Kurulum
- [x] Godot projesi, klasör yapısı, git
- [x] Girdi haritası, autoload iskeletleri, TR/EN çeviri altyapısı
- [x] Otomatik ekran görüntüsü + headless test araçları

### Faz 1 — Dünya & Karakter
- [x] FPS karakter (yürü/koş/zıpla, fare bakışı, kafa sallanması)
- [x] Etkileşim sistemi ("E (UYU)" tarzı ipuçları)
- [x] Arazi, yollar, gölet, ağaçlar, kayalar, rüzgârlı çim
- [x] Gökyüzü, ışık, sis, post-process
- [x] Çiftlik evi (yatak), çitler, kuyu
- [x] HUD iskeleti (nişangâh, para, gün/saat)

### Faz 2 — Eşya & Envanter
- [x] Eşya veritabanı + 3D modellerden render edilen ikon seti
- [x] Envanter modeli (yığınlama, bölme, dayanıklılık, kalite)
- [x] 8'li hotbar (1–8/tekerlek, dayanıklılık çubuğu)
- [x] Envanter (6×6) & sandık (4×4) ekranları, sürükle-bırak
- [x] Yere düşen eşyalar + "+4x Odun" bildirimleri
- [x] Elde tutulan alet modelleri + sallama animasyonları

### Faz 3 — Tarım
- [x] Parsel durumları: çim → çapalı → ıslak
- [x] Basılı tut + ilerleme çubuğu (Çapalanıyor / Ekiliyor / Hasat ediliyor)
- [x] Ekim, sulama (kapasite, kuyudan doldurma, su partikülü)
- [x] Zamana bağlı büyüme (4 aşama), kuruma → solma
- [x] Hasat, tekrar veren ürünler, verim aralığı
- [x] Parsel üstü göstergeler (su / hasat)
- [x] 8 ürünün 4'er aşamalı modelleri

### Faz 4 — Zaman, Hava, Mevsim
- [x] Gün/gece döngüsü (güneş, ay, yıldızlar)
- [x] Yatak & uyku (06:00, gün sonu raporu), 02:00'de bayılma, uyanınca otomatik kayıt
- [x] Hava: güneşli, bulutlu, yağmur, fırtına, kar, sis + hava tahmini
- [x] Mevsimler: sonbahar yaprakları, kar örtüsü

### Faz 5 — Kaynaklar & Aletler
- [x] Ağaç kesme (devrilme animasyonu, kütük), taş/demir kırma (ocak), ot biçme → saman
- [x] Kaynakların yeniden oluşması (ağaç 4, kaya 5, ot 2 gün)
- [x] Alet dayanıklılığı & tüccarda tamir

### Faz 6 — Ekonomi & Tüccar
- [x] Tüccar: AL/SAT sekmeleri, adet seçimi, fiyat trendi okları
- [x] Dinamik fiyat motoru (piyasa dalgası, doygunluk, mevsim dışı prim)
- [x] Satış kutusu (gece satılır), gün sonu raporu, günlük defter

### Faz 7 — Hayvancılık
- [x] 4 hayvan (tavuk, koyun, inek, at): yavru/yetişkin, renk varyantları, iskelet animasyonu
- [x] Gerçekçi modeller: Sketchfab CC-BY foto dokulu inek, at, koyun, tavuk (PhotoRig: ölçek, yön, renk varyantları, ıslaklık, kırkma, atın kendi animasyonları)
- [x] Açık ağıl/kümes (seviye 1) → kapalı ahır/kümes (seviye 2), yemlik & suluk, kapıdan giriş-çıkış rotası
- [x] Hayvan pazarı (alım/satım, isim), malzeme (yem, ilaç, süt kovası, kırkma makası)
- [x] Hayvan AI + ihtiyaçlar (tokluk, su, mutluluk, sağlık), otlama, gece uyuma, barınağa kaçma
- [x] Yağmur/fırtına/kar ve soğuk: açıktaki hayvan hasar alır, kapalı ahır korur; veteriner cezası
- [x] Besleme, büyüme, ürünler (yumurta, süt, yün), sevme/fırçalama, hastalık & ilaç
- [x] Ata binme (dörtnala), hayvan paneli (F), sabah raporunda hayvan notları
- [x] Gübre (torba gübre + ahırın gübre yığınından yabayla hayvan gübresi; daha hızlı büyüme, daha iyi kalite), üreme (bakımlı iki yetişkinden gece doğum), sesler (hayvan sesleri, horoz sabahı)

### Faz 8 — İnşaat, Üretim, İşleme
- [x] Çalışma tezgâhı + tarifler (seviyeyle açılır; gübre, değirmen taşı, fıskiye, peynir presi, turşu fıçısı, çıkrık, reçel kazanı)
- [x] Yerleştirme sistemi (yeşil/kırmızı önizleme, 25 cm ızgara, R ile 45° döndürme, yalnız çiftlik arazisi, F ile geri alma)
- [x] İnşaat panosu: tarla genişletme (SATILIK tabelaları), ev büyütme (3 seviye: mutfak/kiler, yatak odası/gardırop), ahır & kümes
- [x] İşleme makineleri (peynir, yün iplik, turşu, reçel, salça, un; zamanla çalışır, gece de), fıskiyeler (her sabah çevresini sular), alet yükseltmeleri (+1/+2: %20 hızlı, %50 dayanıklı)

### Faz 9 — Menüler & Kayıt
- [x] Ana menü (canlı çiftlik kamerası), duraklatma menüsü, ayarlar (dil, grafik kalitesi, tam ekran, v-sync, çözünürlük ölçeği, FOV, ses, fare, tuşlar)
- [x] Arayüz yenilemesi: buzlu cam paneller, altın vurgu, Barlow yazı tipi, çizgi ikonlar, tuş ikonlu ipuçları, ilerleme halkası
- [x] Gerçekçi aletler: balta, kazma, sulama kabı, süt kovası (Poly Haven CC0), çapa, tırpan, yaba (Sketchfab CC-BY), kırkma makası (müze taraması); elde, yerde ve ikonlarda; tımar fırçası foto dokulu ahşap, deri kayış ve kıl demetleriyle
- [x] Gerçekçi ekinler: mısır, buğday ve domates taranmış/sanatçı bitkileri (aşamalara göre parça parça büyür); patates ve patlıcan domates yapraklarından çalı; havuç, çilek, balkabağı foto yapraklı; tarlada hasat edilen ürünün kendi taraması görünür; yatak başına MultiMesh (dolu tarla 103–112 FPS)
- [x] Gerçekçi ürünler ve eşyalar: havuç, patates, domates, patlıcan, çilek, balkabağı, buğday demeti, yumurta, peynir, iplik, turşu/reçel/salça kavanozları, un/yem/tezek çuvalları, gübre torbası, süt güğümü, saman balyası (Sketchfab CC-BY, Poly Haven CC0); pikap kasası ve market raflarındaki kasalar da bunların sadeleştirilmiş sürümleriyle dolu — mısır koçanı henüz el yapımı
- [x] 13 dil: Türkçe, İngilizce, Almanca, İspanyolca, Fransızca, İtalyanca, Portekizce (Brezilya), Rusça, Lehçe, Japonca, Korece, Çince (Basit/Geleneksel); ilk açılışta sistem dili, ayarlarda anında geçiş; Noto yazı tipleri (docs/LOCALIZATION.md)
- [x] Kaydet/Yükle: 3 yuva + her sabah otomatik kayıt, kayıt kartlarında o anın görüntüsü, gün/mevsim, para, oynama süresi, tarih; sürümleme ve yarım yazmaya karşı güvenli dosya; başlıkta "Kaldığın yerden devam et", duraklatmada Kaydet/Yükle; kayıtta saat, para, hava, yapılar, depolar, tarlalar, yemlikler, hayvanlar, pikap (kasa dahil), oyuncunun yeri

### Faz 11 — Kasaba, Depo & Araçlar
- [x] Harita genişletme: çiftlik vadisinin doğusunda kasaba vadisi, tepeden yumuşak eğimle geçen asfalt yol
- [x] Kasaba: Market (tohum, hammadde, yem al; ürün sat), Benzinlik (yakıt), Galeri (araç al), sokak lambaları, kaldırımlar
- [x] Pazar ve hayvan pazarı kasabaya taşınır (çiftlikte satış kutusu kalır, %25 komisyonla)
- [x] Çiftlik deposu (ambar): odun, sebze, meyve, süt, yumurta… adet olarak stoklanır; kapasite yükseltmesi (400 → 1200)
- [x] Araç sistemi: sür (WASD, Space el freni, E bin/in), sürücü/takip kamerası (V), farlar (L), hız & yakıt göstergesi, yakıt tüketimi
- [x] Başlangıç aracı: Lightbody '90 MD pikap (Sketchfab CC-BY, Daniel Zhabotinsky) — galeriden 550 dolara alınır
- [x] Pikap kasası: depodan yükle, markette kasadaki ürünleri sat
- [x] Benzinlikte depo doldurma (litre fiyatı 0,50 dolar)
- [x] Kasaya yükleme: yük kasada paket paket görünür (sandık, çuval, balya, süt/yumurta kasası, odun, balkabağı); arkadan E ile eldekini yükle, F kasa, "Kasayı boşalt"; yükün ağırlığı ve ağırlık merkezi aracı etkiler; modeldeki gömülü yük kesildi
- [x] Süspansiyon ayarı (sönüm, alçak ağırlık merkezi, viraj demiri) ve inerken aracın fırlaması düzeltildi
- [x] Performans: büyüyen dünyada ölçüldü (başlangıçta 50 → 115 FPS); uzak tepe ormanı gerçek ağaçların fotoğrafından impostor kartlarla, market ürünleri yakında görünen hafif kasalarla; geometri bütçesi testi
- [x] Cila: detaylı yakıt pompası (ekran, tuş takımı, tabanca ve hortum), kaldırım derzleri ve bordür taşları, gece farları (uzun + geniş kısa huzme, gösterge ışığı), gece hava durumu simgesi (ay; açık gecede "Açık")

### Faz 10 — Cila & Yayın
- [x] Hikâye: Deden Osman'dan kalan bakımsız çiftlik; yeni oyunda dedenin mektubu, 7 bölümlük ödüllü görev zinciri (Toprak, Kasaba, Atölye, Kümes, Ahır, Süthane, Dedenin evi), her bölüm dedenin defterinden bir notla açılır, sonunda dededen yeni bir mektup
- [x] Seviyeyle açılan çiftlik (UnlockTable): ekinler mevsimine yetişecek şekilde (Sv.1 buğday/havuç/patates → 2 çilek/domates → 3 mısır → 4 patlıcan/balkabağı), hayvanlar (tavuk 2, koyun 3, inek 4, at 6), binalar (2–8), tezgâh tarifleri, alet yükseltmeleri (3, 6), 9–10'da sipariş avantajları; seviye atlayınca "Yeni açılanlar" penceresi; mağaza, inşaat panosu ve hayvan pazarında kilit rozetleri
- [x] Kasabada sipariş panosu (açık siparişler tahtada tebeşirle yazılı; her sabah yenilenir, piyasanın 1,6 katı öder, pikaptan teslim), çiftlik seviyesi ve deneyim (1–10)
- [x] Ses efektleri (adımlar zemine göre, aletler, hayvanlar, araç motoru, arayüz), ortam sesleri (kuşlar, cırcır böcekleri, rüzgâr, yağmur, gök gürültüsü, ahır; içeride boğuk), müzik (gündüz/gece); Müzik/Efekt/Ortam/Arayüz ses ayarları
- [x] Denge (tools/balance_sim.gd, docs/BALANCE.md), performans (115 FPS)
- [x] macOS (universal, ad-hoc imzalı .app) / Windows (x86_64 .exe + .pck) dışa aktarımı: build/
