# Pedoman Transkripsi (untuk koreksi manual)

Transkrip inilah **label** data latih. Keputusan di sini langsung menjadi
apa yang dipelajari model, jadi konsistensi lebih penting daripada selera.

## Aturan pokok

1. **Verbatim, bukan dirapikan.** Tulis apa yang terdengar, termasuk
   pengulangan dan kalimat yang tidak selesai.
2. **Satu baris per giliran bicara**, diawali label penutur:

   ```
   PENUTUR A: jadi kita perlu align dulu sebelum deploy ya
   PENUTUR B: iya tapi staging-nya masih down dari kemarin
   ```

3. **Istilah Inggris ditulis dengan ejaan Inggris yang benar**, tanpa tanda
   kutip dan tanpa huruf miring: `deploy`, bukan `deploy`/`diploi`.
4. **Imbuhan Indonesia pada kata Inggris pakai tanda hubung**, mengikuti
   kaidah yang umum: `di-deploy`, `me-review`, `staging-nya`, `di-handle`.
   Ini harus konsisten — normaliser WER memecah tanda hubung, jadi kedua
   konvensi akan cocok saat diukur, tetapi label latih yang tidak konsisten
   mengajari model dua ejaan untuk satu kata.
5. **Angka ditulis dengan huruf** sebagaimana diucapkan: "kuartal empat",
   bukan "kuartal 4". Normaliser mengubah digit menjadi kata di kedua sisi,
   jadi hasil pengukuran sama — tetapi label latih yang ditulis sebagai
   huruf sesuai ucapan membuat model belajar keluaran yang konsisten.
6. **Jeda pengisi ditulis** apa adanya: `eh`, `ehm`, `hmm`. Normaliser
   membuangnya saat mengukur, jadi tidak merusak angka WER, dan
   keberadaannya di label membuat data lebih jujur.

## Penanda

| Penanda | Dipakai untuk | Contoh |
|---|---|---|
| `[tak jelas]` | tidak terdengar sama sekali | `anggaran [tak jelas] miliar` |
| `[tak jelas: budget?]` | dugaan yang tidak pasti | |
| `[tumpang tindih]` | dua penutur bersamaan | |
| `[tawa]`, `[batuk]`, `[derau]` | suara non-ucapan | |
| `[potong]` | **wajib** — peserta minta bagian ini dihapus | |

`[potong]` diproses oleh `ingest.py`: potongan yang menyentuhnya dibuang
dari dataset. Jangan dihapus manual dari transkrip — biarkan penandanya,
supaya jejak permintaan peserta tercatat.

## Jangan

- Jangan menerjemahkan. Biarkan campur bahasanya.
- Jangan membetulkan tata bahasa penutur.
- Jangan menambah tanda baca yang tidak terdengar sebagai jeda.
- Jangan menulis nama orang di luar label penutur. Ganti dengan
  `[nama]` bila seseorang menyebut nama rekan yang bukan peserta sesi.
