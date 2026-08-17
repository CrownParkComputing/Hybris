# Hybris

Discovery Software's *Hybris* (Amiga, 1988) running natively from ordinary
files — no disk image at runtime, no WHDLoad slave, no emulator front-end to
configure.

```
make            # builds build/hybris and build/hybris_play
make play       # the playable window
make test       # host-side tests, no 68000 involved
```

## How it boots

Hybris has no self-contained loader of its own, so the usual route is to be
WHDLoad — which stalls on the slave's undocumented patch list. This takes a
different route entirely.

The disk is an AmigaDOS volume whose filesystem holds exactly one thing: an
84,612-byte executable. The game's sixteen data files live on the raw tracks
behind the filesystem, contiguous and track aligned. `tools/extract_hybris_adf.py`
turns that into a directory:

```
original/hybris/hybris.exe     the loader, a normal AmigaDOS hunk file
original/hybris/data/03..18    the game files, carved from the disk
original/hybris/disk-map.txt   id, first track, tracks, length
```

At runtime the executable is hunk-loaded behind a stub `exec.library`, and the
loader's own trackloader is intercepted:

| what | where |
| --- | --- |
| read-tracks entry | `$EED8`, D0 = start track, D1 = track count |
| destination | long at `$F130`, stored by the dispatcher at `$EE54` |
| current file | long at `$2E28` → descriptor |
| true length | descriptor + 2 |

Serve those four and the whole MFM / DSKLEN / drive-stepping path never runs —
a track read becomes a `memcpy` from a file. `make test` checks the derived map
against the loader's *own* dispatch table, all fifteen entries.

## Controls

| action | pad | keyboard |
| --- | --- | --- |
| Move | stick or d-pad | arrows or WASD |
| Fire | **A** | Ctrl or Z |
| Special | **B** | Shift or X |
| Split | **Y** | Return |
| Config screen | **SELECT** | Space |
| Pause | **START** | P |
| Capture frame + RAM + registers | — | F12 |

The config screen is the game's own: number of ships, enemy bullet speed, time
between bullets, expansion timings. It is easy to miss — the original opens it
with SPACE from the title.

The game's two extra actions genuinely *are* keys: it never reads POTGOR, and
it takes a second joystick button as a POT0DAT change instead.

## The chipset

`src/host/amiga.c` is a small OCS implementation — copper, blitter, bitplanes,
sprites, Paula, CIA — written against what these titles actually do rather than
against a spec. Things it turned out to need, each because something visibly
broke without it:

- **Sprites written straight to the registers.** Hybris draws its whole
  SCORE/LIVES/HIGH panel by having the copper write `SPRxDATB`/`SPRxDATA`/`SPRxPOS`
  repeatedly across one scanline, repositioning a single sprite per glyph. None
  of it goes through a sprite list.
- **Mid-scanline colour changes.** A copper `WAIT` has a horizontal target as
  well as a vertical one; the title highlights the selected commander by
  changing `COLOR11` partway across the line.
- **HIRES.** The end-of-attract credit scroller is a 2-plane hires screen.
- **A fixed display origin, horizontal and vertical.** Windows land where they
  really are; deriving the origin from anything that moves makes the picture
  jump.
- **Sprites are not clipped to the display window vertically**, so the buffer is
  a whole PAL raster (352×288) and presented at 4:3, because an Amiga pixel is
  not square.

## Tools

- `tools/extract_hybris_adf.py` — disk image → files, deriving every offset
  rather than guessing, and reporting what it cannot account for.
- `tools/extract_hybris_gfx.py` — rips artwork out of chip RAM using the
  blitter as the index (`BS_DUMP_BLITS=file build/hybris` logs every distinct
  source, width, height and modulo the blitter fetched).

## Building

Needs a C11 compiler and, for the playable window, raylib in `~/.local`.
Musashi is vendored in `third_party/musashi` (MIT, Karl Stenerud).

## Status

Boots, plays, and renders the title, attract, demo, high scores and credits.
Sound works — Hybris drives its music from a CIA-B timer at level 6.

The sprite format is cracked — five planes, each padded to 128 bytes, the
fifth an inverted mask — so artwork can be ripped and replaced; see
`assets/sprites/README.md`.

Known open ends: the fire cadence is fixed at one shot per 24 frames by the
game itself, which no input pattern changes; and the formation enemies have
not been identified for remastering.
