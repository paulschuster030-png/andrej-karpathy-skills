/*
  robloxian.js — an actual blocky Roblox character, drawn as real 3D boxes.

  The first cover used a smooth silhouette. It looked good, but it did not
  look like ROBLOX, and a thumbnail's first job is to tell a scrolling player
  which platform and which kind of game they are looking at. Every top
  thumbnail on the platform has a blocky avatar in it.

  So this builds a classic R6 rig — head, torso, two arms, two legs — as
  boxes in 3D, projects them, sorts the faces back-to-front and shades each
  one by its angle to a light. Posing is real rotation around real joints,
  which is why the pose reads as a pose rather than as a sticker.

  The face is deliberately extreme. Thumbnails with strong emotional
  expressions measurably out-click neutral ones, and "shocked" is the
  expression the whole platform's visual language is built on.
*/

const DEG = Math.PI / 180;

/* Camera: a three-quarter view, slightly from above. Straight-on loses the
   blockiness entirely, and that blockiness is the whole point. */
const YAW = -28 * DEG;
const PITCH = 10 * DEG;

const LIGHT = normalise([-0.45, 0.8, 0.55]);

function normalise(v) {
  const length = Math.hypot(v[0], v[1], v[2]) || 1;
  return [v[0] / length, v[1] / length, v[2] / length];
}

function rotate(point, rotation) {
  let [x, y, z] = point;
  const [rx, ry, rz] = rotation.map((d) => d * DEG);

  if (rz) {
    const c = Math.cos(rz), s = Math.sin(rz);
    [x, y] = [x * c - y * s, x * s + y * c];
  }
  if (rx) {
    const c = Math.cos(rx), s = Math.sin(rx);
    [y, z] = [y * c - z * s, y * s + z * c];
  }
  if (ry) {
    const c = Math.cos(ry), s = Math.sin(ry);
    [x, z] = [x * c + z * s, -x * s + z * c];
  }
  return [x, y, z];
}

function project(point) {
  const [x, y, z] = point;
  const cy = Math.cos(YAW), sy = Math.sin(YAW);
  const x1 = x * cy + z * sy;
  const z1 = -x * sy + z * cy;
  const cp = Math.cos(PITCH), sp = Math.sin(PITCH);
  const y1 = y * cp - z1 * sp;
  const depth = y * sp + z1 * cp;
  return { x: x1, y: -y1, depth };
}

/* Face definitions as corner indices into the 8 box corners, plus the
   outward normal used for shading. */
const FACES = [
  { corners: [0, 1, 3, 2], normal: [0, 0, -1] }, // front
  { corners: [5, 4, 6, 7], normal: [0, 0, 1] },  // back
  { corners: [4, 0, 2, 6], normal: [-1, 0, 0] }, // left
  { corners: [1, 5, 7, 3], normal: [1, 0, 0] },  // right
  { corners: [4, 5, 1, 0], normal: [0, 1, 0] },  // top
  { corners: [2, 3, 7, 6], normal: [0, -1, 0] }, // bottom
];

function shade(hex, amount) {
  const n = parseInt(hex.slice(1), 16);
  const r = Math.min(255, Math.max(0, Math.round(((n >> 16) & 255) * amount)));
  const g = Math.min(255, Math.max(0, Math.round(((n >> 8) & 255) * amount)));
  const b = Math.min(255, Math.max(0, Math.round((n & 255) * amount)));
  return `rgb(${r},${g},${b})`;
}

/**
 * Turn one box into drawable, depth-sorted polygons.
 * pivot   world-space joint the part rotates about
 * offset  centre of the box relative to that joint
 * size    [width, height, depth] in studs
 */
function boxFaces(part) {
  const { pivot, offset, size, rotation = [0, 0, 0], color } = part;
  const [w, h, d] = size.map((s) => s / 2);

  const local = [
    [-w, h, -d], [w, h, -d], [-w, -h, -d], [w, -h, -d],
    [-w, h, d], [w, h, d], [-w, -h, d], [w, -h, d],
  ];

  const world = local.map((corner) => {
    const moved = [corner[0] + offset[0], corner[1] + offset[1], corner[2] + offset[2]];
    const spun = rotate(moved, rotation);
    return [spun[0] + pivot[0], spun[1] + pivot[1], spun[2] + pivot[2]];
  });

  const projected = world.map(project);

  return FACES.map((face) => {
    const normal = normalise(rotate(face.normal, rotation));
    const lambert = Math.max(0, normal[0] * LIGHT[0] + normal[1] * LIGHT[1] + normal[2] * LIGHT[2]);
    // Ambient floor keeps the shadowed side readable instead of black.
    const brightness = 0.52 + lambert * 0.62;
    const points = face.corners.map((index) => projected[index]);
    return {
      depth: points.reduce((sum, p) => sum + p.depth, 0) / 4,
      points,
      fill: shade(color, brightness),
      part,
    };
  });
}

/**
 * A classic R6 miner. `pose` rotates the limbs; everything else is fixed
 * proportion, because R6 proportions are the recognisable part.
 */
function robloxMiner(options) {
  const o = Object.assign({
    scale: 46,
    skin: '#f2c14a',
    shirt: '#e2571e',
    vest: '#ffd23f',
    trousers: '#2c3446',
    helmet: '#ffb020',
    haft: '#7a5426',
    steel: '#c9ced8',
    lean: -14,
    outline: '#08080c',
    rim: '#ffc93c',
  }, options || {});

  /*
    Joint angles, and how to read them. A limb hangs from its pivot with
    offset (0,-1,0); a Z rotation of theta swings its far end to
    (sin theta, -cos theta). So 0 hangs straight down, 180 points straight up,
    and anything in 90..180 goes up-and-right. Getting this backwards is why
    the first pass had both arms folded across the chest.
  */
  const ARM_PICK = 205;   // up and out to the left, holding the pick
  const ARM_FREE = 112;   // out to the right, roughly horizontal

  const parts = [
    // Legs, splayed outward and kicked back so they read as two legs.
    { pivot: [-0.5, -1, 0], offset: [0, -1, 0], size: [1, 2, 1], rotation: [30, 0, -20], color: o.trousers },
    { pivot: [0.5, -1, 0], offset: [0, -1, 0], size: [1, 2, 1], rotation: [-18, 0, 16], color: o.trousers },

    // Torso: dark shirt, hi-vis vest over it, reflective stripe across.
    { pivot: [0, 0, 0], offset: [0, 0, 0], size: [2, 2, 1], color: o.trousers },
    { pivot: [0, 0, 0], offset: [0, 0.06, 0], size: [2.08, 1.66, 1.08], color: o.shirt },
    { pivot: [0, 0, 0], offset: [0, -0.28, 0], size: [2.12, 0.24, 1.12], color: o.vest },

    // Arms.
    { pivot: [-1.5, 1, 0], offset: [0, -1, 0], size: [1, 2, 1], rotation: [0, 0, ARM_PICK], color: o.skin },
    { pivot: [1.5, 1, 0], offset: [0, -1, 0], size: [1, 2, 1], rotation: [0, 0, ARM_FREE], color: o.skin },

    // The pickaxe hangs off the same pivot as the raised arm, so it stays in
    // the hand no matter how that arm is posed, and it gets depth-sorted with
    // everything else instead of floating on top as a flat sticker.
    { pivot: [-1.5, 1, 0], offset: [0, -2.9, 0], size: [0.26, 2.6, 0.26], rotation: [0, 0, ARM_PICK], color: o.haft },
    { pivot: [-1.5, 1, 0], offset: [0, -4.2, 0], size: [1.9, 0.3, 0.32], rotation: [0, 0, ARM_PICK], color: o.steel },
    { pivot: [-1.5, 1, 0], offset: [-0.86, -3.86, 0], size: [0.42, 0.78, 0.32], rotation: [0, 0, ARM_PICK], color: o.steel },
    { pivot: [-1.5, 1, 0], offset: [0.86, -3.94, 0], size: [0.42, 0.56, 0.32], rotation: [0, 0, ARM_PICK], color: o.steel },

    // Head, hard hat, brim.
    { pivot: [0, 1, 0], offset: [0, 0.62, 0], size: [1.45, 1.24, 1.45], color: o.skin, head: true },
    { pivot: [0, 1, 0], offset: [0, 1.38, 0], size: [1.56, 0.52, 1.56], color: o.helmet },
    { pivot: [0, 1, 0], offset: [0, 1.14, -0.42], size: [1.66, 0.18, 0.98], color: o.helmet },
  ];

  const faces = [];
  for (const part of parts) faces.push(...boxFaces(part));
  faces.sort((a, b) => b.depth - a.depth);

  const lean = o.lean;
  const body = faces.map((face) => {
    const d = face.points.map((p) => `${(p.x * o.scale).toFixed(2)},${(p.y * o.scale).toFixed(2)}`).join(' ');
    return `<polygon points="${d}" fill="${face.fill}" stroke="${o.outline}" stroke-width="1.6" stroke-linejoin="round"/>`;
  }).join('\n    ');

  // The face is drawn flat onto the head's front plane afterwards. Projecting
  // it through the same pipeline would be more correct and would also make it
  // unreadable at thumbnail size, which is the only size that counts.
  const headAnchor = project([0, 1.62, -0.73]);
  const fx = headAnchor.x * o.scale;
  const fy = headAnchor.y * o.scale;

  return `
<svg viewBox="-230 -280 460 470" width="${o.width || 520}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="rmRim-${o.uid || 'a'}" x="-30%" y="-30%" width="160%" height="160%">
      <feMorphology in="SourceAlpha" operator="dilate" radius="5" result="fat"/>
      <feFlood flood-color="${o.rim}" flood-opacity="0.95"/>
      <feComposite in2="fat" operator="in" result="outline"/>
      <feGaussianBlur in="outline" stdDeviation="4" result="soft"/>
      <feMerge>
        <feMergeNode in="soft"/><feMergeNode in="outline"/><feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>

  <g filter="url(#rmRim-${o.uid || 'a'})" transform="rotate(${o.lean})">
    ${body}

    <!-- Shocked face. Strong expressions measurably out-click neutral ones,
         and this is the expression the platform's visual language runs on. -->
    <g transform="translate(${fx.toFixed(2)} ${fy.toFixed(2)}) rotate(${(-YAW / DEG * 0.5).toFixed(1)})">
      <ellipse cx="-12" cy="-5" rx="7" ry="9.5" fill="#141414"/>
      <ellipse cx="12" cy="-5" rx="7" ry="9.5" fill="#141414"/>
      <ellipse cx="-10.2" cy="-8.2" rx="2.3" ry="2.9" fill="#ffffff"/>
      <ellipse cx="13.8" cy="-8.2" rx="2.3" ry="2.9" fill="#ffffff"/>
      <ellipse cx="0" cy="15" rx="8" ry="10" fill="#141414"/>
    </g>
  </g>
</svg>`;
}
