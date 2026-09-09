#!/usr/bin/env node
/*
  render.mjs — turn the cover HTML into the PNGs Roblox actually wants.

  Sizes are not arbitrary: 1920x1080 is the thumbnail aspect the store scales
  from, and 512x512 is the game icon. The icon is also rendered at 150px,
  because that is roughly its size in a search result — an icon that only
  works at full size is an icon that does not work.

  The viewport quirk: headless Chromium's --window-size includes browser
  chrome, so the painted viewport comes out ~87px shorter than asked and the
  bottom strip of every design is silently cut. Rather than hard-coding 87,
  we measure the offset with a probe page at startup — it is a Chromium
  implementation detail and will change without telling us.
*/

import { execFileSync } from 'node:child_process';
import { cropTop, downscale, downscaleWidth } from './png.mjs';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, 'out');
const CHROME = process.env.CHROME_BIN || '/opt/pw-browsers/chromium';

const FLAGS = [
  '--headless',
  '--disable-gpu',
  '--no-sandbox',
  '--hide-scrollbars',
  '--force-device-scale-factor=1',
];

const TARGETS = [
  { file: 'thumb-depth.html',  out: 'deeprush-thumbnail-1-depth.png',  w: 1920, h: 1080 },
  { file: 'thumb-rarity.html', out: 'deeprush-thumbnail-2-rarity.png', w: 1920, h: 1080 },
  { file: 'thumb-steal.html',  out: 'deeprush-thumbnail-3-steal.png',  w: 1920, h: 1080 },
  { file: 'icon.html',         out: 'deeprush-icon-512.png',           w: 512,  h: 512 },
];

/** How many pixels of the requested window height never reach the page. */
function measureChromeHeight() {
  const probePath = join(tmpdir(), 'deeprush-viewport-probe.html');
  writeFileSync(probePath, `<html><body><p id="v"></p>
    <script>document.getElementById('v').textContent = 'VIEWPORT:' + innerWidth + 'x' + innerHeight;</script>
  </body></html>`);

  const dom = execFileSync(CHROME, [...FLAGS, '--window-size=800,800', '--dump-dom', 'file://' + probePath],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });

  const match = dom.match(/VIEWPORT:(\d+)x(\d+)/);
  if (!match) {
    console.warn('could not measure the viewport; assuming no chrome offset');
    return 0;
  }
  return 800 - Number(match[2]);
}

const chromeHeight = measureChromeHeight();
console.log(`viewport offset: ${chromeHeight}px of chrome`);

mkdirSync(OUT, { recursive: true });

for (const target of TARGETS) {
  const source = 'file://' + resolve(HERE, target.file);
  const destination = join(OUT, target.out);
  execFileSync(CHROME, [
    ...FLAGS,
    '--virtual-time-budget=4000',
    `--window-size=${target.w},${target.h + chromeHeight}`,
    `--screenshot=${destination}`,
    source,
  ], { stdio: ['ignore', 'ignore', 'ignore'] });

  // The screenshot is window-sized; trim the chrome strip off the bottom.
  cropTop(destination, target.h);
  console.log(`${target.out}  ${target.w}x${target.h}`);
}

// The icon's real test. A search result scales the 512 down; it does not
// re-render at 150, so checking it any other way flatters the design.
downscale(join(OUT, 'deeprush-icon-512.png'), join(OUT, 'deeprush-icon-150-check.png'), 150);
console.log('deeprush-icon-150-check.png  150x150  (downscaled — this is the size that decides)');

// Same discipline for the hero thumbnail: in the Home grid it is a few
// hundred pixels wide, and a headline that only works at 1920 is a headline
// nobody reads. Not square, so we scale the width and let the crop follow.
downscaleWidth(join(OUT, 'deeprush-thumbnail-1-depth.png'), join(OUT, 'deeprush-thumbnail-1-grid-check.png'), 384);
console.log('deeprush-thumbnail-1-grid-check.png  384x216  (how it looks in the Home grid)');
