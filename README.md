# Lily58 ZMK yapılandırması

Kablosuz Lily58 (nice!nano v2, ZMK v0.3) için keymap ve onu macOS'ta tamamlayan araçlar: katman göstergesi, pil göstergesi ve klavyeye göre otomatik giriş kaynağı.

Sistem dört parçadan oluşur:

| Parça | Dosyalar | Ne yapar |
|---|---|---|
| Firmware | `config/` | Keymap ve ZMK ayarları |
| Yerel derleme | `scripts/build-local.sh` | Firmware'i Docker ile bu Mac'te derler |
| Hammerspoon betiği | `hammerspoon/lily58_layers.lua` | Katman şeması, pil göstergesi, düşük pil bildirimi, otomatik düzen geçişi |
| Pil okuyucu | `battery/` | İki yarının pilini Bluetooth'tan okuyup bir dosyaya yazar |

## Katmanlar

macOS'ta giriş kaynağı **ABC** olmalıdır; tuş başlıkları ve semboller buna göre dizilidir.

| Katman | Nasıl açılır | İçerik |
|---|---|---|
| Base | — | QWERTY |
| Semboller | sol iç başparmak | solda semboller, sağda numpad |
| Gezinme | sağ iç başparmak | solda oklar, masaüstü ve pencere tuşları; sağda medya |
| Ayarlar | iki iç başparmak birlikte | F tuşları, Bluetooth, bootloader |
| Fare | sağ dış başparmak | solda imleç, sağda kaydırma |

Bütün katmanlar basılı tutma tipindedir; tuşu bırakınca Base'e dönülür. İki Shift'e birlikte basmak caps word'ü açar.

### Base

```
ESC   1  2  3  4  5                 6  7  8  9  0  `
TAB   Q  W  E  R  T                 Y  U  I  O  P  -
SHIFT A  S  D  F  G                 H  J  K  L  ;  '
CTRL  Z  X  C  V  B  [           ]  N  M  ,  .  /  SHIFT
           ALT CMD SEMB SPACE   ENTER GEZ BSPC FARE
```

### Semboller (sol iç başparmak)

```
`   !  @  #  $  %                 ^  &  *  (  )  ~
~   |  \  {  }  &                 *  7  8  9  +  -
    <  >  (  )  =                 /  4  5  6  =  '
    !  _  -  +  *                 0  1  2  3  .
                 [basılı]                DEL
```

Backspace bu katmanda Delete olur.

### Gezinme (sağ iç başparmak)

```
    ⌃←    ↑     ⌃→    PgUp  Üst½               ⏮     ⏯     ⏭
    ←     ↓     →     PgDn  Alt½               Mute  Vol−  Vol+
    Sol½  Büyüt Sağ½  Ortala Geri al  Ekran→   Bri−  Bri+
                       Raycast            [basılı]
```

- `Q` / `E`: önceki / sonraki masaüstü (Ctrl+Sol / Ctrl+Sağ).
- Alt sıra ve `T` / `G`: [Rectangle](https://rectangleapp.com)'ın varsayılan kısayolları (Ctrl+Option+…). `[` pencereyi sonraki ekrana taşır.
- Space: Cmd+Space (Raycast).

### Ayarlar (iki iç başparmak)

```
F1        F2      F3   F4   F5   F6          F7  F8  F9  F10  F11    F12
BT sil    BT 0    BT 1 BT 2 BT 3 BT 4
Tümü sil  USB/BT
Boot      Reset                                                Reset  Boot
```

`Boot` ve `Reset`, basıldıkları yarıyı etkiler. **"Tümü sil" `Boot`'un hemen üstündedir** ve bütün Bluetooth eşleşmelerini siler; yanlışlıkla basılırsa aşağıdaki [Bluetooth bağlanmıyor](#bluetooth-bağlanmıyor) adımları gerekir.

### Fare (sağ dış başparmak)

```
          ▲                          Kay↑
    ◀     ▼     ▶             Kay←   Kay↓   Kay→

                Sol tık    Sağ tık         [basılı]
```

İmleç `W A S D`, sol tık Space, sağ tık Enter.

## Firmware'i derlemek

Docker (OrbStack) çalışırken:

```bash
scripts/build-local.sh            # yalnızca sol yarı
scripts/build-local.sh left right # iki yarı
```

Çıktı `firmware/lily58_left.uf2` ve `firmware/lily58_right.uf2` olur. İlk çalıştırma ZMK ve Zephyr'i `~/.cache/lily58-zmk` altına indirir (yaklaşık 10 dakika); sonrakiler bir iki dakika sürer.

GitHub Actions da her push'ta iki yarıyı derler; `firmware` artifact'i Actions sayfasından indirilebilir.

**Hangi yarıya yüklemeli?** Keymap sol yarıda (Mac'e bağlanan taraf) durur; keymap değişikliklerinde yalnızca sol yarı yeterlidir. `config/lily58.conf` içindeki bir ayar değiştiyse iki yarı da yüklenmelidir.

## Firmware'i yüklemek

1. Yarıyı USB ile Mac'e bağla.
2. İki iç başparmak basılıyken o yarının alt dış köşesindeki tuşa (`Boot`) bas. Klavye yanıt vermiyorsa karttaki reset düğmesine iki kez hızlıca bas.
3. `NICENANO` diski açılınca dosyayı kopyala:

```bash
cp firmware/lily58_left.uf2 /Volumes/NICENANO/
```

Kopyalama sonunda çıkan `could not copy extended attributes … Device not configured` hatası normaldir; kart dosyayı alınca kendini yeniden başlatır.

Sol dosyayı sağ yarıya (ya da tersini) yüklemek klavyeyi çalışmaz hale getirir; düzeltmek için her yarıya kendi dosyasını yeniden yükle.

## Mac kurulumu

Yeni bir Mac'te sırasıyla:

1. **Giriş kaynağı:** Sistem Ayarları → Klavye → Giriş Kaynakları'na **ABC** ve **Türkçe Q** ekle.
2. **Hammerspoon:**

   ```bash
   brew install --cask hammerspoon
   ```

   `~/.hammerspoon/init.lua` içine şunu yaz (yol, deponun klonlandığı yere göre):

   ```lua
   Lily58Layers = dofile(os.getenv("HOME") .. "/personal/projects/lily-58-keymap-zmk/hammerspoon/lily58_layers.lua")
   ```

   Hammerspoon'a Sistem Ayarları → Gizlilik ve Güvenlik → **Erişilebilirlik** iznini ver, ayarlarından "Launch Hammerspoon at login"i aç, bildirimlerine izin ver.
3. **Pil okuyucu:**

   ```bash
   battery/install.sh
   ```

   İlk çalıştırmada macOS'un Bluetooth izni sorusuna izin ver. Kaldırmak için `battery/install.sh --remove`.

Betikte bir değişiklikten sonra menü çubuğundaki Hammerspoon simgesinden **Reload Config** yeterlidir.

## Mac tarafı nasıl çalışır

**Katman göstergesi.** ZMK hangi katmanda olduğunu bilgisayara bildirmez. Bu yüzden katman tuşları basılı oldukları sürece görünmez bir işaret tuşu da gönderir: Semboller F16, Gezinme F17, Fare F18. Hammerspoon bunları yakalar, uygulamalara geçirmez ve 0,3 saniye sonra o katmanın şemasını ekranın altında gösterir. Hammerspoon kapalıyken bu tuşlar uygulamalara ulaşır; terminalde anlamsız karakter olarak görünebilir.

**Pil.** Sol yarı, sağ yarının pilini okuyup Mac'e ikinci bir pil servisi olarak sunar. macOS kendi menüsünde yalnızca ilkini gösterdiği için `lily58-battery` aracı ikisini de okur ve `~/.cache/lily58-battery.json` dosyasına yazar (15 dakikada bir, LaunchAgent `io.lily58.battery`). Hammerspoon bu dosyayı menü çubuğunda `sol · sağ` olarak gösterir ve bir yarı %20'nin altına inince bildirim verir. Araç Hammerspoon'dan değil LaunchAgent'tan çalışır, çünkü macOS Bluetooth iznini yalnızca kendi adına çalışan bir sürece verir.

**Otomatik düzen.** Lily58'de yazarken giriş kaynağı ABC'ye, başka bir klavyede Türkçe Q'ya geçer. Betik Lily58'i işaret tuşlarından tanır; yeni bir Mac'te ilk kez bir katman tuşuna basmak gerekir.

**Ayarlanabilir değerler** (`hammerspoon/lily58_layers.lua`): `M.showDelay` (şemanın gecikmesi), `M.batteryLow` ve `M.batteryRearm` (bildirim eşikleri).

## Keymap'i değiştirirken

- Göstergedeki tuş etiketleri keymap'ten üretilmez. `config/lily58.keymap` değişince `hammerspoon/lily58_layers.lua` içindeki `layers` tablosu da elle güncellenmelidir; her katmanda tam 58 etiket olmalıdır.
- Yalnızca merkez (sol) yarıya özgü ayarlar `config/lily58_left.conf` dosyasına yazılır; bu ayarlar sağ yarıda tanımlı olmadığı için ortak dosyaya yazılmamalıdır.
- ZMK ve derleme iş akışı birlikte `v0.3`'e sabitlidir (`config/west.yml`, `.github/workflows/build.yml`); biri güncellenirse diğeri de güncellenmelidir.

## Sorun giderme

### Bluetooth bağlanmıyor

Firmware yükledikten ya da "Tümü sil"e bastıktan sonra klavye bağlanmıyorsa eşleşme bozulmuştur:

1. Sistem Ayarları → Bluetooth → Lily58 → **Bu Aygıtı Unut**.
2. Sol yarıda bir tuşa bas; Lily58 "Yakındaki Aygıtlar"da görününce bağlan.

Sol yarının sağlam olup olmadığını anlamak için USB ile bağlayıp yazmayı dene.

### Fare tuşları çalışmıyor

Fare desteği klavyenin kendini tanıtma biçimini değiştirir; macOS bunu ancak yeniden eşleşince görür. Yukarıdaki adımları uygula.

### Menü çubuğunda pil `–` görünüyor

Veri bir saatten eskidir ya da hiç okunamamıştır. Klavye bağlı mı ve görev çalışıyor mu bak:

```bash
launchctl list | grep lily58
cat ~/.cache/lily58-battery.json
```

### Semboller yanlış çıkıyor

Giriş kaynağı ABC değildir. Otomatik geçiş için Hammerspoon'un çalıştığından ve hem ABC hem Türkçe Q'nun ekli olduğundan emin ol.
