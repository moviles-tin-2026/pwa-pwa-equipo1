/**
 * Genera pwa/public/pwa-192.png y pwa-512.png
 * sin dependencias externas — solo Node built-ins (zlib, fs).
 *
 * Ejecutar una vez desde la carpeta pwa/:
 *   node scripts/generate-icons.mjs
 */
import { deflateSync } from 'node:zlib'
import { writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { join, dirname } from 'node:path'

const __dir = dirname(fileURLToPath(import.meta.url))
const PUBLIC = join(__dir, '..', 'public')

// ── CRC32 ──────────────────────────────────────────────────────────────────
const CRC = new Uint32Array(256)
for (let n = 0; n < 256; n++) {
  let c = n
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
  CRC[n] = c
}
function crc32(buf) {
  let v = 0xffffffff
  for (const b of buf) v = CRC[(v ^ b) & 0xff] ^ (v >>> 8)
  return (v ^ 0xffffffff) >>> 0
}

// ── PNG chunk helper ───────────────────────────────────────────────────────
function chunk(type, data) {
  const t = Buffer.from(type, 'ascii')
  const len = Buffer.allocUnsafe(4)
  len.writeUInt32BE(data.length)
  const crcBuf = Buffer.allocUnsafe(4)
  crcBuf.writeUInt32BE(crc32(Buffer.concat([t, data])))
  return Buffer.concat([len, t, data, crcBuf])
}

// ── Draw icon on RGBA pixel grid ───────────────────────────────────────────
// All coordinates are proportional (0–1) so it scales to any size.
function drawIcon(size) {
  const px = new Uint8Array(size * size * 4)

  const setPixel = (x, y, r, g, b, a = 255) => {
    if (x < 0 || y < 0 || x >= size || y >= size) return
    const i = (y * size + x) * 4
    px[i] = r; px[i + 1] = g; px[i + 2] = b; px[i + 3] = a
  }

  const fillRect = (x0, y0, x1, y1, r, g, b, a = 255) => {
    for (let y = Math.round(y0); y < Math.round(y1); y++)
      for (let x = Math.round(x0); x < Math.round(x1); x++)
        setPixel(x, y, r, g, b, a)
  }

  const s = size

  // Background: olive #3d5016  rgb(61,80,22)
  fillRect(0, 0, s, s, 61, 80, 22)

  // Rounded-rect bg  (lighter olive #4a6020) — box body
  const m = s * 0.14            // margin
  const bx0 = m, bx1 = s - m
  const by0 = m * 1.1, by1 = s - m * 0.8
  fillRect(bx0, by0, bx1, by1, 74, 96, 32)

  // Top lid strip  rgb(238,240,213) ≈ #eef0d5
  const lidH = (by1 - by0) * 0.22
  fillRect(bx0, by0, bx1, by0 + lidH, 238, 240, 213)

  // Horizontal line dividing lid from body  (dark olive)
  const lh = Math.max(2, Math.round(s * 0.025))
  fillRect(bx0, by0 + lidH, bx1, by0 + lidH + lh, 40, 56, 12)

  // Small centered handle on lid
  const hw = (bx1 - bx0) * 0.28
  const hx = s / 2 - hw / 2
  const hy = by0 + lidH * 0.18
  const hh = lidH * 0.55
  fillRect(hx, hy, hx + hw, hy + hh, 40, 56, 12)

  // Two horizontal lines inside box body (lines = inventory rows)
  const lineGap = (by1 - by0 - lidH - lh) / 3
  const lStart = by0 + lidH + lh
  for (let i = 1; i <= 2; i++) {
    const ly = lStart + lineGap * i - lh / 2
    const lx0 = bx0 + (bx1 - bx0) * 0.15
    const lx1 = bx1 - (bx1 - bx0) * 0.15
    fillRect(lx0, ly, lx1, ly + lh, 238, 240, 213)
  }

  return px
}

// ── Encode RGBA pixels → PNG buffer ───────────────────────────────────────
function encodePNG(size, pixels) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])

  const ihdr = Buffer.allocUnsafe(13)
  ihdr.writeUInt32BE(size, 0)
  ihdr.writeUInt32BE(size, 4)
  ihdr[8] = 8   // bit depth
  ihdr[9] = 6   // color type: RGBA
  ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0

  // Raw scanlines: filter byte (0 = None) + RGBA per pixel
  const raw = Buffer.allocUnsafe(size * (1 + size * 4))
  for (let y = 0; y < size; y++) {
    raw[y * (1 + size * 4)] = 0
    for (let x = 0; x < size; x++) {
      const src = (y * size + x) * 4
      const dst = y * (1 + size * 4) + 1 + x * 4
      raw[dst]     = pixels[src]
      raw[dst + 1] = pixels[src + 1]
      raw[dst + 2] = pixels[src + 2]
      raw[dst + 3] = pixels[src + 3]
    }
  }

  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 6 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

// ── Generate & save ────────────────────────────────────────────────────────
for (const size of [192, 512]) {
  const pixels = drawIcon(size)
  const png = encodePNG(size, pixels)
  const out = join(PUBLIC, `pwa-${size}.png`)
  writeFileSync(out, png)
  console.log(`✓ ${out}  (${(png.length / 1024).toFixed(1)} KB)`)
}
console.log('Icons generated!')
