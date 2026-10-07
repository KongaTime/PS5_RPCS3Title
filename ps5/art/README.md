# Title art

The home screen's art for PS5 RPCS3, made for this title by kongatime and
shipped with the title:

| File | Becomes |
| --- | --- |
| `icon-source.webp` (1254x1254) | `ps5/sce_sys/icon0.png`, 512x512 |
| `background-source.webp` (1672x941) | `ps5/sce_sys/pic0.dds` and `pic1.dds`, 3840x2160 BC7; and the launcher's Library background, `ps5/assets/launcher/background.jpg` |

`ps5/tools/title-art.py` writes them (Pillow and etcpak); run it after changing a
source and commit what it writes.
