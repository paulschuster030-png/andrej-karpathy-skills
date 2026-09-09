#!/usr/bin/env node
/*
  avatar.mjs — fetch a real Roblox avatar render for the cover.

  Usage:  node cover/avatar.mjs <username>

  Downloads a transparent full-body render of that account's current avatar
  into cover/assets/avatar.png. Once it exists, the thumbnails use it instead
  of the drawn blocky miner — see the swap note in thumb-avatar.html.

  Why bother when we already draw a character: a render of YOUR rig keeps your
  outfit, accessories and face consistent across every thumbnail you ever
  make, which is how recognisable Roblox channels are built. The drawn miner
  is the default because it always works, needs no account, and cannot be
  someone else's likeness.

  Only ever point this at an account you own.
*/

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const username = process.argv[2];

if (!username) {
  console.error('usage: node cover/avatar.mjs <roblox-username>');
  process.exit(1);
}

async function json(url, init) {
  const response = await fetch(url, init);
  if (!response.ok) throw new Error(`${url} -> HTTP ${response.status}`);
  return response.json();
}

const lookup = await json('https://users.roblox.com/v1/usernames/users', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ usernames: [username], excludeBannedUsers: false }),
});

const user = lookup.data?.[0];
if (!user) {
  console.error(`no Roblox account called "${username}"`);
  process.exit(1);
}

// 720x720 is the largest full-body size the thumbnails API serves. Renders
// are generated lazily, so a fresh avatar can come back "Pending" the first
// time and needs a moment.
let imageUrl = null;
for (let attempt = 1; attempt <= 6; attempt++) {
  const thumb = await json(
    `https://thumbnails.roblox.com/v1/users/avatar?userIds=${user.id}&size=720x720&format=Png&isCircular=false`,
  );
  const entry = thumb.data?.[0];
  if (entry?.state === 'Completed' && entry.imageUrl) {
    imageUrl = entry.imageUrl;
    break;
  }
  console.log(`render ${entry?.state ?? 'unknown'}, waiting...`);
  await new Promise((resolve) => setTimeout(resolve, 2000 * attempt));
}

if (!imageUrl) {
  console.error('Roblox never finished the render; try again in a minute');
  process.exit(1);
}

const image = await fetch(imageUrl);
if (!image.ok) throw new Error(`image download -> HTTP ${image.status}`);

const destination = join(HERE, 'assets', 'avatar.png');
writeFileSync(destination, Buffer.from(await image.arrayBuffer()));

console.log(`saved ${destination}`);
console.log(`  account: ${user.name} (${user.displayName}), id ${user.id}`);
console.log('  now run: node cover/render.mjs');
