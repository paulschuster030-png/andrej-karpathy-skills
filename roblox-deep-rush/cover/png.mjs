/*
  png.mjs — just enough PNG to crop a screenshot.

  Headless Chromium always writes a screenshot the size of the WINDOW, and a
  window is taller than its viewport by the height of the browser chrome. The
  design therefore lands in the top of a slightly-too-tall image and has to be
  trimmed.

  Written against node:zlib rather than a dependency so that `node
  cover/render.mjs` works on a clean checkout with nothing installed.
*/

import { readFileSync, writeFileSync } from 'node:fs';
import { deflateSync, inflateSync } from 'node:zlib';

const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  return table;
})();

function crc32(buffer) {
  let c = -1;
  for (let i = 0; i < buffer.length; i++) c = CRC_TABLE[(c ^ buffer[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(type, data) {
  const out = Buffer.alloc(12 + data.length);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, 'ascii');
  data.copy(out, 8);
  const body = out.subarray(4, 8 + data.length);
  out.writeUInt32BE(crc32(body), 8 + data.length);
  return out;
}

/** Undo PNG's per-row filters into flat RGBA/RGB rows. */
function unfilter(raw, width, height, channels) {
  const stride = width * channels;
  const rows = [];
  let previous = Buffer.alloc(stride);
  let offset = 0;

  for (let y = 0; y < height; y++) {
    const filter = raw[offset++];
    const line = Buffer.from(raw.subarray(offset, offset + stride));
    offset += stride;

    for (let x = 0; x < stride; x++) {
      const a = x >= channels ? line[x - channels] : 0;
      const b = previous[x];
      const c = x >= channels ? previous[x - channels] : 0;
      switch (filter) {
        case 1: line[x] = (line[x] + a) & 0xff; break;
        case 2: line[x] = (line[x] + b) & 0xff; break;
        case 3: line[x] = (line[x] + ((a + b) >> 1)) & 0xff; break;
        case 4: {
          const p = a + b - c;
          const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
          line[x] = (line[x] + (pa <= pb && pa <= pc ? a : pb <= pc ? b : c)) & 0xff;
          break;
        }
      }
    }

    rows.push(line);
    previous = line;
  }

  return rows;
}

/** Decode a PNG into flat rows plus its geometry. */
function decode(path) {
  const file = readFileSync(path);
  if (!file.subarray(0, 8).equals(SIGNATURE)) throw new Error(`${path} is not a PNG`);

  let position = 8;
  let width = 0, height = 0, depth = 0, colorType = 0;
  const idat = [];

  while (position < file.length) {
    const length = file.readUInt32BE(position);
    const type = file.toString('ascii', position + 4, position + 8);
    const data = file.subarray(position + 8, position + 8 + length);

    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      depth = data[8];
      colorType = data[9];
      if (depth !== 8 || (colorType !== 2 && colorType !== 6)) {
        throw new Error(`unsupported PNG: depth ${depth}, colour type ${colorType}`);
      }
    } else if (type === 'IDAT') {
      idat.push(data);
    }

    position += 12 + length;
  }

  const channels = colorType === 6 ? 4 : 3;
  const rows = unfilter(inflateSync(Buffer.concat(idat)), width, height, channels);
  return { width, height, channels, colorType, rows };
}

/** Write flat rows back out. Filter 0 throughout: these are flat-colour
    renders, so the compression given up is negligible. */
function encode(path, width, height, channels, colorType, rows) {
  const stride = width * channels;
  const body = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    body[y * (stride + 1)] = 0;
    rows[y].copy(body, y * (stride + 1) + 1);
  }

  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = colorType;

  writeFileSync(path, Buffer.concat([
    SIGNATURE,
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(body, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]));
}

/** Crop `path` to its top `keepHeight` rows, in place. */
export function cropTop(path, keepHeight) {
  const image = decode(path);
  if (keepHeight >= image.height) return { ...image, cropped: false };
  encode(path, image.width, keepHeight, image.channels, image.colorType, image.rows);
  return { width: image.width, height: keepHeight, cropped: true };
}

/**
 * Box-filter downscale, used to check the icon at the size a search result
 * actually shows it. Averaging every source pixel in the target cell (rather
 * than sampling one) is what makes thin rim lights survive the reduction —
 * point sampling drops them and flatters the design.
 */
export function downscale(sourcePath, destinationPath, size) {
  return resample(sourcePath, destinationPath, size, size);
}

/** Same, preserving aspect ratio from a target width. */
export function downscaleWidth(sourcePath, destinationPath, targetWidth) {
  const { width, height } = decode(sourcePath);
  const targetHeight = Math.round((height / width) * targetWidth);
  return resample(sourcePath, destinationPath, targetWidth, targetHeight);
}

function resample(sourcePath, destinationPath, outWidth, outHeight) {
  const { width, height, channels, colorType, rows } = decode(sourcePath);
  const out = [];

  for (let y = 0; y < outHeight; y++) {
    const line = Buffer.alloc(outWidth * channels);
    const y0 = Math.floor((y * height) / outHeight);
    const y1 = Math.max(y0 + 1, Math.floor(((y + 1) * height) / outHeight));

    for (let x = 0; x < outWidth; x++) {
      const x0 = Math.floor((x * width) / outWidth);
      const x1 = Math.max(x0 + 1, Math.floor(((x + 1) * width) / outWidth));
      const totals = new Array(channels).fill(0);
      let samples = 0;

      for (let sy = y0; sy < y1; sy++) {
        const row = rows[sy];
        for (let sx = x0; sx < x1; sx++) {
          for (let c = 0; c < channels; c++) totals[c] += row[sx * channels + c];
          samples++;
        }
      }

      for (let c = 0; c < channels; c++) {
        line[x * channels + c] = Math.round(totals[c] / samples);
      }
    }

    out.push(line);
  }

  encode(destinationPath, outWidth, outHeight, channels, colorType, out);
  return { width: outWidth, height: outHeight };
}
