/*
  shaft.js — the one visual idea the whole cover is built on.

  Looking down a mine shaft: rings receding to a glowing core, everything
  else swallowed by black.

  The first version of this was a bullseye — every ring concentric, all the
  same weight — which read as a flat spiral target and fought the headline
  for attention. Two changes fixed it:

    THE SHAFT BENDS. Ring centres travel along a curve toward the vanishing
    point instead of stacking on one spot, so it reads as a tunnel you could
    fall down rather than a pattern.

    THE ROCK IS NEARLY BLACK. A thumbnail can only have one focal point. The
    rock is atmosphere; the glowing core and the figure are the subject. Ring
    brightness tops out around 12% lightness for that reason.
*/

function buildShaft(host, options) {
  const o = Object.assign({
    mouthX: 46,      // where the shaft opening sits, % of stage
    mouthY: 34,
    coreX: 68,       // where the bottom of it sits
    coreY: 58,
    rings: 26,
    start: 2600,     // outermost ring diameter in px
    ratio: 0.874,    // gentler than a bullseye: more rings, closer together
    squash: 0.78,
    hue: 'ore',
    maxLightness: 12,
  }, options || {});

  const oreColor = o.hue === 'greed' ? '255,61,127'
    : o.hue === 'depth' ? '95,224,255'
    : '255,201,60';

  let size = o.start;

  for (let i = 0; i < o.rings; i++) {
    const t = i / (o.rings - 1);         // 0 at the mouth, 1 at the core
    // Ease the travel so the bend tightens as it goes deeper, the way
    // perspective actually compresses.
    const ease = t * t * (3 - 2 * t);
    const cx = o.mouthX + (o.coreX - o.mouthX) * ease;
    const cy = o.mouthY + (o.coreY - o.mouthY) * ease;

    const ring = document.createElement('div');
    ring.className = 'ring';

    const lightness = Math.max(2, o.maxLightness * (1 - t * 0.86));
    const thickness = Math.max(1.5, 26 * (1 - t) + 1.5);

    ring.style.width = size + 'px';
    ring.style.height = (size * o.squash) + 'px';
    ring.style.borderWidth = thickness + 'px';
    ring.style.borderColor = `hsl(26 26% ${lightness}%)`;
    ring.style.left = cx + '%';
    ring.style.top = cy + '%';
    ring.style.boxShadow = `inset 0 ${thickness}px ${thickness * 3}px rgba(0,0,0,0.9)`;
    ring.style.zIndex = String(i);
    host.appendChild(ring);

    // Ore. Rare and bright rather than frequent and dim — a few hot points
    // lead the eye inward; a scatter of them just adds texture noise.
    if (i % 4 === 1 && t < 0.7) {
      const glints = 2;
      for (let g = 0; g < glints; g++) {
        const angle = (i * 63 + g * 180 + 20) * Math.PI / 180;
        const rx = (size / 2) * Math.cos(angle);
        const ry = (size * o.squash / 2) * Math.sin(angle);
        const scale = (1 - t) * 22 + 5;
        const alpha = (1 - t) * 0.95 + 0.05;
        const glint = document.createElement('div');
        glint.style.position = 'absolute';
        glint.style.left = `calc(${cx}% + ${rx}px)`;
        glint.style.top = `calc(${cy}% + ${ry}px)`;
        glint.style.width = scale + 'px';
        glint.style.height = scale * 0.62 + 'px';
        glint.style.marginLeft = (-scale / 2) + 'px';
        glint.style.marginTop = (-scale * 0.31) + 'px';
        glint.style.borderRadius = '45%';
        glint.style.background = `rgba(${oreColor},${alpha})`;
        glint.style.boxShadow = `0 0 ${scale * 2.6}px rgba(${oreColor},${alpha}),
                                 0 0 ${scale * 6}px rgba(${oreColor},${alpha * 0.55})`;
        glint.style.zIndex = String(i);
        host.appendChild(glint);
      }
    }

    size *= o.ratio;
  }

  // The core. This is the focal point of the whole image, so it is large,
  // hot, and the only thing in frame allowed to be this bright.
  const core = document.createElement('div');
  core.style.position = 'absolute';
  core.style.left = o.coreX + '%';
  core.style.top = o.coreY + '%';
  core.style.width = '620px';
  core.style.height = '460px';
  core.style.transform = 'translate(-50%,-50%)';
  core.style.borderRadius = '50%';
  core.style.background = `radial-gradient(ellipse,
      rgba(255,255,240,0.95) 0%,
      rgba(${oreColor},0.85) 12%,
      rgba(${oreColor},0.30) 34%,
      rgba(${oreColor},0.08) 58%,
      transparent 76%)`;
  core.style.zIndex = String(o.rings + 1);
  host.appendChild(core);
}
