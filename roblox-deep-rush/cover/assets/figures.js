/*
  figures.js — the miner.

  Every <defs> id is suffixed with a per-instance counter. Without that, two
  figures on the same page share the first one's gradients and filters — which
  is exactly how the "marked" player on the steal thumbnail came out with the
  thief's amber rim instead of the magenta one the mechanic is named after.

  Drawn rather than rendered: a Roblox avatar screenshot would date the image
  the moment the player changes their outfit, and a silhouette with a lamp
  reads at 150px where a textured character does not.

  Swap in your own avatar render by replacing the <svg> this returns with an
  <img> — the composition leaves the figure on its own layer for exactly that.
*/

let figureUid = 0;

function minerFalling(options) {
  const uid = 'f' + (++figureUid);
  const o = Object.assign({
    size: 460,
    lamp: '#ffd45e',
    body: '#05050a',
    accent: '#ffc93c',
    rim: 0.9,
  }, options || {});

  // Limbs are drawn as round-capped strokes rather than filled outlines.
  // Filled paths kept collapsing into a blob at thumbnail scale; strokes hold
  // their shape because the silhouette is defined by one width, not by two
  // edges that can drift together.
  return `
<svg viewBox="0 0 320 460" width="${o.size}" height="${o.size * 1.44}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="lampGlow-${uid}" cx="50%" cy="50%">
      <stop offset="0%" stop-color="${o.lamp}" stop-opacity="1"/>
      <stop offset="45%" stop-color="${o.lamp}" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="${o.lamp}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="beam-${uid}" x1="0.5" y1="0" x2="0.2" y2="1">
      <stop offset="0%" stop-color="${o.lamp}" stop-opacity="0.42"/>
      <stop offset="100%" stop-color="${o.lamp}" stop-opacity="0"/>
    </linearGradient>

    <!-- Dilate the alpha, flood it amber, blur, and lay the figure back on
         top. Without this the silhouette only exists where the core glow
         happens to sit behind it, and the pickaxe vanishes entirely. -->
    <filter id="rimlight-${uid}" x="-25%" y="-25%" width="150%" height="150%">
      <feMorphology in="SourceAlpha" operator="dilate" radius="6" result="fat"/>
      <feFlood flood-color="${o.accent}" flood-opacity="0.95"/>
      <feComposite in2="fat" operator="in" result="outline"/>
      <feGaussianBlur in="outline" stdDeviation="4" result="soft"/>
      <feMerge>
        <feMergeNode in="soft"/>
        <feMergeNode in="outline"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>

  <!-- the lamp beam, thrown ahead of the fall -->
  <path d="M150 96 L20 452 L268 452 Z" fill="url(#beam-${uid})"/>

  <g filter="url(#rimlight-${uid})">
  <g transform="rotate(16 160 240)"
     stroke="${o.body}" fill="none" stroke-linecap="round" stroke-linejoin="round">

    <!-- legs trailing, knees bent -->
    <path d="M140 250 L112 322 L146 372" stroke-width="30"/>
    <path d="M172 250 L212 306 L192 374" stroke-width="30"/>

    <!-- torso -->
    <path d="M156 148 L156 250" stroke-width="76"/>

    <!-- left arm swung back, right arm up holding the pick -->
    <path d="M126 168 L78 138 L60 84" stroke-width="26"/>
    <path d="M188 168 L238 186 L262 140" stroke-width="26"/>
  </g>

  <g transform="rotate(16 160 240)">
    <!-- the pickaxe: the fastest way to say "mining game" at 150px -->
    <g stroke-linecap="round">
      <path d="M40 40 L92 128" stroke="${o.body}" stroke-width="15"/>
      <path d="M6 44 q40 -30 74 -6 q-36 6 -74 6 z" fill="${o.body}"/>
      <path d="M80 38 q-40 -26 -74 6 q38 -2 74 -6 z" fill="${o.body}"/>
      <path d="M12 40 q34 -20 62 -2" fill="none" stroke="${o.accent}" stroke-width="5" opacity="${o.rim}"/>
    </g>

    <!-- head, helmet, brim -->
    <circle cx="156" cy="106" r="36" fill="${o.body}"/>
    <path d="M118 104 q0 -48 38 -48 q38 0 38 48 z" fill="${o.body}"/>
    <path d="M108 104 q48 -14 96 0 q6 12 -6 15 l-84 0 q-12 -3 -6 -15 z" fill="${o.body}"/>
    <path d="M124 74 q32 -16 64 0 q-8 -20 -32 -20 q-24 0 -32 20 z"
          fill="${o.accent}" opacity="0.5"/>

  </g>
  </g>

  <!-- the lamp sits outside the rim filter: it is a light source, and the
       filter would ring it with an outline it should not have -->
  <g transform="rotate(16 160 240)">
    <circle cx="156" cy="84" r="40" fill="url(#lampGlow-${uid})"/>
    <circle cx="156" cy="84" r="11" fill="${o.lamp}"/>
  </g>
</svg>`;
}

/* A dropped cargo crate, used on the steal variant. */
function crate(options) {
  const uid = 'c' + (++figureUid);
  const o = Object.assign({ size: 260, tint: '#d6a03c' }, options || {});
  return `
<svg viewBox="0 0 240 200" width="${o.size}" height="${o.size * 0.83}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="crateFace-${uid}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${o.tint}"/>
      <stop offset="100%" stop-color="#6d4c17"/>
    </linearGradient>
  </defs>
  <path d="M120 12 L226 62 L120 112 L14 62 Z" fill="${o.tint}" opacity="0.95"/>
  <path d="M14 62 L120 112 L120 188 L14 138 Z" fill="url(#crateFace-${uid})"/>
  <path d="M226 62 L120 112 L120 188 L226 138 Z" fill="#4a340f"/>
  <path d="M14 62 L120 112 L226 62" fill="none" stroke="#ffdd8a" stroke-width="3" opacity="0.6"/>
  <path d="M120 112 L120 188" fill="none" stroke="#ffdd8a" stroke-width="3" opacity="0.35"/>
</svg>`;
}

/* A faceted ore crystal, for the rarity thumbnail.

   One elongated octahedron, not two stacked pyramids: stacking pinched the
   silhouette into an hourglass, which read as a timer rather than a gem.
   Facets are flat polygons because a gradient gem turns to mush at thumbnail
   size while hard facet edges survive the downscale. */
function oreCrystal(options) {
  const uid = 'g' + (++figureUid);
  const o = Object.assign({ size: 620, hot: '#fff3c4', mid: '#ffc93c', deep: '#b8620f', edge: '#fff' }, options || {});
  return `
<svg viewBox="0 0 400 560" width="${o.size}" height="${o.size * 1.4}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="halo-${uid}" cx="50%" cy="46%">
      <stop offset="0%" stop-color="${o.mid}" stop-opacity="0.9"/>
      <stop offset="42%" stop-color="${o.mid}" stop-opacity="0.24"/>
      <stop offset="100%" stop-color="${o.mid}" stop-opacity="0"/>
    </radialGradient>
    <filter id="gemGlow-${uid}" x="-60%" y="-60%" width="220%" height="220%">
      <feGaussianBlur stdDeviation="20" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>

  <ellipse cx="200" cy="260" rx="198" ry="256" fill="url(#halo-${uid})"/>

  <g filter="url(#gemGlow-${uid})">
    <!-- crown -->
    <polygon points="200,18 312,196 200,196 88,196" fill="${o.mid}"/>
    <polygon points="200,18 312,196 200,196" fill="${o.hot}"/>
    <polygon points="200,18 88,196 200,196" fill="${o.hot}" opacity="0.62"/>

    <!-- pavilion, long and tapered so it reads as one crystal -->
    <polygon points="88,196 200,196 200,540" fill="${o.mid}" opacity="0.95"/>
    <polygon points="312,196 200,196 200,540" fill="${o.deep}"/>
    <polygon points="88,196 148,300 200,540" fill="${o.deep}" opacity="0.45"/>

    <!-- inner light, the bit that says "this one is worth something" -->
    <polygon points="200,60 268,192 200,192 132,192" fill="#fffdf3" opacity="0.55"/>

    <polygon points="200,18 312,196 200,540 88,196" fill="none" stroke="${o.edge}" stroke-width="4.5" opacity="0.9"/>
    <line x1="88" y1="196" x2="312" y2="196" stroke="${o.edge}" stroke-width="3" opacity="0.55"/>
    <line x1="200" y1="18" x2="200" y2="540" stroke="${o.edge}" stroke-width="2.5" opacity="0.35"/>
  </g>
</svg>`;
}
