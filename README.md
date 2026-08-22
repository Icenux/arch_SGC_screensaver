# Omarchy SGC Screensaver

Vlastní screensaver pro [Omarchy](https://omarchy.org/) (Hyprland), nahrazující
výchozí `omarchy-launch-screensaver` smyčkovaným videem loga Stargate Command.
Běží fullscreen na všech monitorech, spuštění je mezi monitory synchronizované
a je odolný vůči přepsání při `omarchy update`.

## Požadavky

- Omarchy / Hyprland (`hyprctl`)
- `mpv`
- `socat` (synchronizace přehrávání mezi monitory přes mpv IPC)
- `jq`

```bash
sudo pacman -S mpv socat jq
```

## Struktura repozitáře → cílové umístění

| Soubor v repu                        | Cílová cesta                              |
|---------------------------------------|--------------------------------------------|
| `hypr/hypridle.conf`                  | `~/.config/hypr/hypridle.conf`              |
| `local-bin/sgc-launch-screensaver`    | `~/.local/bin/sgc-launch-screensaver`       |
| `local-bin/sgc-kill-screensaver`      | `~/.local/bin/sgc-kill-screensaver`         |
| `sgc-screensaver/sgc.mp4`             | `~/.local/share/sgc-screensaver/sgc.mp4`    |
| `sgc-screensaver/mpv-input.conf`      | `~/.local/share/sgc-screensaver/mpv-input.conf` |
| `omarchy-hooks/sgc-hypridle.conf`     | `~/.config/omarchy/hooks/sgc-hypridle.conf` |
| `omarchy-hooks/post-update`           | `~/.config/omarchy/hooks/post-update`       |

## Instalace

```bash
git clone https://github.com/Luquas95/omarchy-SGC-screensaver.git
cd omarchy-SGC-screensaver

mkdir -p ~/.local/bin ~/.local/share/sgc-screensaver ~/.config/omarchy/hooks

cp hypr/hypridle.conf ~/.config/hypr/hypridle.conf

cp local-bin/sgc-launch-screensaver ~/.local/bin/
cp local-bin/sgc-kill-screensaver ~/.local/bin/
chmod +x ~/.local/bin/sgc-launch-screensaver ~/.local/bin/sgc-kill-screensaver

cp sgc-screensaver/sgc.mp4 ~/.local/share/sgc-screensaver/
cp sgc-screensaver/mpv-input.conf ~/.local/share/sgc-screensaver/

cp omarchy-hooks/sgc-hypridle.conf ~/.config/omarchy/hooks/
cp omarchy-hooks/post-update ~/.config/omarchy/hooks/
chmod +x ~/.config/omarchy/hooks/post-update

omarchy-restart-hypridle
```

Pokud `~/.config/hypr/hypridle.conf` už máte upravený (jiné timeouty, vlastní
`lock_cmd` apod.), místo přepsání radši ručně zkopírujte jen tyhle dva řádky
do listeneru pro nečinnost:

```
listener {
    timeout = 150
    on-timeout = pidof hyprlock || sgc-launch-screensaver
    on-resume = sgc-kill-screensaver
}
```

a `omarchy-hooks/sgc-hypridle.conf` pak vytvořte jako kopii vašeho
výsledného `hypridle.conf` (na něj se `post-update` hook odkazuje).

## Jak to funguje

- `sgc-launch-screensaver` spustí na každém monitoru vlastní instanci `mpv`
  přes `hyprctl dispatch exec "[workspace <ID> silent] mpv ..."`, kde `<ID>`
  je aktuální workspace daného monitoru. Cílení přes `silent` workspace
  (místo `dispatch focusmonitor`) je záměrné — `focusmonitor` přesouvá
  kurzor, což hypridle vyhodnotí jako aktivitu a screensaver by tím sám
  sebe okamžitě zabil.
- Každá instance `mpv` startuje pozastavená s vlastním IPC socketem; jakmile
  jsou všechny sockety připravené, skript je odpauzuje v rychlém sledu, aby
  přehrávání na všech monitorech začalo prakticky ve stejný okamžik.
- Ukončení (klávesa/tlačítko myši/scroll/pohyb kurzoru) řeší `mpv-input.conf`
  a polling pozice kurzoru přímo ve skriptu, stejně jako to dělá výchozí
  Omarchy screensaver.
- `omarchy-hooks/post-update` je Omarchy hook (`~/.config/omarchy/hooks/post-update`),
  který se spustí po každém `omarchy update`. Omarchy migrace v minulosti
  `hypridle.conf` přepisovaly zpět na výchozí stav — hook porovná aktuální
  soubor s uloženou verzí (`sgc-hypridle.conf`) a v případě rozdílu ho obnoví
  a restartuje `hypridle`.

## Odinstalace

```bash
cp ~/.local/share/omarchy/config/hypr/hypridle.conf ~/.config/hypr/hypridle.conf
omarchy-restart-hypridle
rm ~/.local/bin/sgc-launch-screensaver ~/.local/bin/sgc-kill-screensaver
rm -rf ~/.local/share/sgc-screensaver
rm ~/.config/omarchy/hooks/post-update ~/.config/omarchy/hooks/sgc-hypridle.conf
```
