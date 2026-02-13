# wallpaper (macOS) + wallust + kitty

Small CLI tool to:

- Pick or randomise desktop wallpapers from two folders  
- Generate a colour palette using Wallust  
- Apply colours to Kitty live (no restart required)  

---

## Folder Layout

Expected directories:

~/.config/utilities/  
├── wallpaper  
├── Wallpapers/  
└── Wallpapers-Full/  

Put your images inside the two wallpaper folders.

---

## Requirements

- macOS  
- wallust installed and available in PATH  
- Kitty terminal emulator  
- Optional: fzf for interactive selection  
- Optional: coreutils (provides gshuf if shuf is missing)

Kitty configuration must contain:

allow_remote_control yes  
include current-theme.conf  

---

## Install

Make the script executable (if needed):

chmod +x ~/.config/utilities/wallpaper

Optional: add to PATH via Homebrew prefix:

ln -sf ~/.config/utilities/wallpaper /opt/homebrew/bin/wallpaper

---

## Usage

Set active wallpaper folder:

wallpaper dir 1   → Wallpapers  
wallpaper dir 2   → Wallpapers-Full  

Random wallpaper (from active folder):

wallpaper random  

Random from specific folder:

wallpaper random 1  
wallpaper random 2  

Interactive picker:

wallpaper pick  
wallpaper pick 1  
wallpaper pick 2  

Show current macOS wallpaper path:

wallpaper current  

---

## Wallpapers Included

### Wallpapers

> wallhaven-zpy8wg.png  
> wallhaven-yxlwyd.jpg  
> wallhaven-mld9d9.jpg  
> wallhaven-kxmxom.jpg  
> wallhaven-k8wjx7.jpg  
> wallhaven-e8xzrk.png  
> wallhaven-768zy3.jpg  
> wallhaven-5gq629.jpg  
> wallhaven-3q9qky.png  
> space_suit.png  
> retro.jpg  
> retro-room.png  
> mountain_dragon_pink.jpg  
> mazda.png  
> Lofi_Cat.png  
> blue.jpg  
> blue-mushroom.jpg  
> birdandcat.jpg  
> BG1.png  
> aishot-1011.jpeg  
> aesthetic_deer.png  

### Wallpapers-Full

> Yae_miko.jpg  
> witch.jpg  
> wallhaven-zpy8wg.png  
> wallhaven-zpx3xw.png  
> wallhaven-z8l37o.jpg  
> wallhaven-yxlwyd.jpg  
> wallhaven-x6r1el.png  
> wallhaven-x619o3.jpg  
> wallhaven-w5q8px.jpg  
> wallhaven-w5o7r6.png  
> wallhaven-v9v3r5.jpg  
> wallhaven-qr9987.jpg  
> wallhaven-po3z8m.jpg  
> wallhaven-p9qpyp.jpg  
> wallhaven-p9op59.jpg  
> wallhaven-p9dp7p.jpg  
> wallhaven-ogxk55.png  
> wallhaven-og9wlm.jpg  
> wallhaven-og5165.jpg  
> wallhaven-o5zx65.jpg  
> wallhaven-mld9d9.jpg  
> wallhaven-m3rdj1.jpg  
> wallhaven-ly8j3p.jpg  
> wallhaven-l81r22.jpg  
> wallhaven-kxmxom.jpg  
> wallhaven-k8x2kd.png  
> wallhaven-k8wjx7.jpg  
> wallhaven-k8w3wd.jpg  
> wallhaven-jx6g7q.jpg  
> wallhaven-je866m.jpg  
> wallhaven-je5j65.jpg  
> wallhaven-gwzqjl.png  
> wallhaven-exkzzo.jpg  
> wallhaven-exjy6w.jpg  
> wallhaven-exdx5l.jpg  
> wallhaven-e8xzrk.png  
> wallhaven-d8633m.jpg  
> wallhaven-d69rq3.jpg  
> wallhaven-9dpdj1.png  
> wallhaven-8o139o.jpg  
> wallhaven-8gokqy.png  
> wallhaven-7p7yoe.png  
> wallhaven-768zy3.jpg  
> wallhaven-6oog7q.jpg  
> wallhaven-6lkw7l.jpg  
> wallhaven-6dvkpl.jpg  
> wallhaven-5gq629.jpg  
> wallhaven-3q9qky.png  
> wallhaven-3lqj1d.jpg  
> wallhaven-3lgxx3.jpg  
> wallhaven-2yv9rm.jpg  
> wallhaven-1pqvwg.jpg  
> wallhaven-1ppyk9.jpg  
> wallhaven-1pol63.png  
> w2k5dra6b4xc1.png  
> Vagabond.jpg  
> The Firefly Lane.jpg  
> sword_girl_with_blue_eyes.png  
> sunset_girl.jpg  
> Study-table.png  
> stormlight_arc1_wallpaper.png  
> Spiderwomen.jpg  
> space_suit.png  
> Smoking_girl.png  
> retro.jpg  
> retro-room.png  
> Red_with_blueflame.jpg  
> Red_samurai.png  
> power-closeup.png  
> pink-ring.png  
> painting.jpg  
> nun.jpeg  
> mountain_dragon_pink.jpg  
> monstera.png  
> mazda.png  
> main.png  
> lotm.png  
> Lofi_Cat.png  
> Kojiro.png  
> Klein-in-grayfog.png  
> kita-1.png  
> Kaiju.jpg  
> green-andro.png  
> green_girl.jpg  
> green_dinasour.png  
> goto-hitori.png  
> gojo_kun.png  
> girl.jpg  
> Girl_with_latern.png  
> evangelion.png  
> darkish.jpg  
> cyberpunk-girl-pink.png  
> Cute-Aesthetic-4k-Wallpaper.jpg  
> borderlands.jpg  
> blue.jpg  
> blue-mushroom.jpg  
> birdandcat.jpg  
> Biker_Girl.jpg  
> Batman_.png  
> AnymzpF.jpg  
> anime-girl-countryside.jpg  
> anime-classroom.jpg  
> aishot-1011.jpeg  
> aesthetic_deer.png  
> Pink_gyal.jpg  

Source: https://github.com/NischalDawadi/Wallpapers

---

## Notes

- State is stored in: ~/.cache/wallust/  
- Wallpaper images are not included in this repository  
- Kitty colours are reloaded automatically each time
