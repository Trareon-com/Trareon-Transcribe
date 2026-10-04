# Bundled typefaces

Both faces are bundled rather than taken from the platform so that the three
target platforms render the same type rhythm for the owner's side-by-side test,
and so the golden tests under `test/goldens/` are deterministic. See
`docs/DESIGN-SYSTEM.md` §3.

| Family | Weights | Version | Licence |
|---|---|---|---|
| Inter | 400, 500, 600, 700 | 4.1 | SIL Open Font License 1.1 (`Inter-LICENSE.txt`) |
| JetBrains Mono | 400, 500 | 2.304 | SIL Open Font License 1.1 (`JetBrainsMono-OFL.txt`) |

Sources:

- Inter: <https://github.com/rsms/inter> (release `v4.1`, `extras/ttf/`)
- JetBrains Mono: <https://github.com/JetBrains/JetBrainsMono> (release
  `v2.304`, `fonts/ttf/`)

Both cover the full Latin range used by Bahasa Indonesia. Neither family is
renamed or modified, which is what the OFL requires of a verbatim
redistribution; the licence files above ship with the app bundle and are also
reachable in the app from Pengaturan, Tentang.

Only the weights the design system actually names are bundled. Adding a weight
means adding a row to the type scale in `docs/DESIGN-SYSTEM.md` §3.2 first.
