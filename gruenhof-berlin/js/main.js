(function () {
  "use strict";

  /* ---------- Mobiles Menü ---------- */
  var navToggle = document.getElementById('nav-toggle');
  var navLinks = document.getElementById('nav-links');
  if (navToggle && navLinks) {
    navToggle.addEventListener('click', function () {
      var open = navLinks.classList.toggle('is-open');
      navToggle.setAttribute('aria-expanded', String(open));
    });
    navLinks.querySelectorAll('a').forEach(function (a) {
      a.addEventListener('click', function () {
        navLinks.classList.remove('is-open');
        navToggle.setAttribute('aria-expanded', 'false');
      });
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {
        navLinks.classList.remove('is-open');
        navToggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  /* ---------- Warenkorb ---------- */
  var CART_KEY = 'gruenhof_cart_v1';

  function loadCart() {
    try {
      var raw = localStorage.getItem(CART_KEY);
      return raw ? JSON.parse(raw) : [];
    } catch (e) { return []; }
  }
  function saveCart(items) {
    try { localStorage.setItem(CART_KEY, JSON.stringify(items)); } catch (e) { /* storage unavailable */ }
  }

  var cart = loadCart();

  var cartToggle = document.getElementById('cart-toggle');
  var cartPanel = document.getElementById('cart-panel');
  var cartOverlay = document.getElementById('cart-overlay');
  var cartClose = document.getElementById('cart-close');
  var cartCount = document.getElementById('cart-count');
  var cartItemsEl = document.getElementById('cart-items');
  var cartTotalEl = document.getElementById('cart-total');
  var cartCheckoutBtn = document.getElementById('cart-checkout');

  function fmtPrice(n) {
    return n.toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
  }

  function renderCart() {
    var count = cart.reduce(function (sum, i) { return sum + i.qty; }, 0);
    if (cartCount) {
      cartCount.textContent = String(count);
      cartCount.hidden = count === 0;
    }
    if (!cartItemsEl) return;
    cartItemsEl.innerHTML = '';
    if (cart.length === 0) {
      var empty = document.createElement('p');
      empty.className = 'cart-panel__empty';
      empty.textContent = 'Dein Warenkorb ist noch leer.';
      cartItemsEl.appendChild(empty);
    } else {
      cart.forEach(function (item) {
        var row = document.createElement('div');
        row.className = 'cart-item';

        var name = document.createElement('span');
        name.className = 'cart-item__name';
        name.textContent = item.name;

        var qtyWrap = document.createElement('span');
        qtyWrap.className = 'cart-item__qty';
        var dec = document.createElement('button');
        dec.type = 'button'; dec.textContent = '−'; dec.setAttribute('aria-label', 'Menge verringern');
        dec.addEventListener('click', function () { changeQty(item.id, -1); });
        var qty = document.createElement('span');
        qty.textContent = String(item.qty);
        var inc = document.createElement('button');
        inc.type = 'button'; inc.textContent = '+'; inc.setAttribute('aria-label', 'Menge erhöhen');
        inc.addEventListener('click', function () { changeQty(item.id, 1); });
        qtyWrap.appendChild(dec); qtyWrap.appendChild(qty); qtyWrap.appendChild(inc);

        var price = document.createElement('span');
        price.textContent = fmtPrice(item.price * item.qty);

        var remove = document.createElement('button');
        remove.type = 'button'; remove.className = 'cart-item__remove'; remove.textContent = '✕';
        remove.setAttribute('aria-label', 'Artikel entfernen');
        remove.addEventListener('click', function () { removeItem(item.id); });

        row.appendChild(name);
        row.appendChild(qtyWrap);
        row.appendChild(price);
        row.appendChild(remove);
        cartItemsEl.appendChild(row);
      });
    }
    var total = cart.reduce(function (sum, i) { return sum + i.price * i.qty; }, 0);
    if (cartTotalEl) cartTotalEl.textContent = fmtPrice(total);
    if (cartCheckoutBtn) cartCheckoutBtn.disabled = cart.length === 0;
  }

  function addItem(id, name, price) {
    var existing = cart.filter(function (i) { return i.id === id; })[0];
    if (existing) { existing.qty += 1; }
    else { cart.push({ id: id, name: name, price: price, qty: 1 }); }
    saveCart(cart);
    renderCart();
    openCart();
  }
  function changeQty(id, delta) {
    var item = cart.filter(function (i) { return i.id === id; })[0];
    if (!item) return;
    item.qty += delta;
    if (item.qty <= 0) cart = cart.filter(function (i) { return i.id !== id; });
    saveCart(cart);
    renderCart();
  }
  function removeItem(id) {
    cart = cart.filter(function (i) { return i.id !== id; });
    saveCart(cart);
    renderCart();
  }

  function openCart() {
    if (cartPanel) cartPanel.classList.add('is-open');
    if (cartOverlay) cartOverlay.classList.add('is-open');
    if (cartToggle) cartToggle.setAttribute('aria-expanded', 'true');
  }
  function closeCart() {
    if (cartPanel) cartPanel.classList.remove('is-open');
    if (cartOverlay) cartOverlay.classList.remove('is-open');
    if (cartToggle) cartToggle.setAttribute('aria-expanded', 'false');
  }

  if (cartToggle) cartToggle.addEventListener('click', function (e) {
    e.preventDefault();
    if (cartPanel && cartPanel.classList.contains('is-open')) closeCart(); else openCart();
  });
  if (cartClose) cartClose.addEventListener('click', closeCart);
  if (cartOverlay) cartOverlay.addEventListener('click', closeCart);
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeCart(); });

  document.querySelectorAll('.js-add-to-cart').forEach(function (btn) {
    btn.addEventListener('click', function () {
      addItem(btn.dataset.id, btn.dataset.name, parseFloat(btn.dataset.price));
    });
  });

  var bundleBtn = document.getElementById('bundle-add-all');
  if (bundleBtn) {
    bundleBtn.addEventListener('click', function () {
      var items = JSON.parse(bundleBtn.dataset.items);
      items.forEach(function (i) {
        var existing = cart.filter(function (c) { return c.id === i.id; })[0];
        if (existing) existing.qty += 1; else cart.push({ id: i.id, name: i.name, price: i.price, qty: 1 });
      });
      saveCart(cart);
      renderCart();
      openCart();
    });
  }

  var kontaktLeistung = document.getElementById('kontakt-leistung');
  var kontaktNachricht = document.getElementById('kontakt-nachricht');

  if (cartCheckoutBtn) {
    cartCheckoutBtn.addEventListener('click', function () {
      if (cart.length === 0) return;
      var lines = cart.map(function (i) { return '- ' + i.qty + '× ' + i.name + ' (' + fmtPrice(i.price * i.qty) + ')'; });
      var total = cart.reduce(function (sum, i) { return sum + i.price * i.qty; }, 0);
      var summary = 'Bestellwunsch aus dem Gartenshop:\n' + lines.join('\n') + '\nGesamt: ' + fmtPrice(total);
      if (kontaktNachricht) kontaktNachricht.value = summary;
      if (kontaktLeistung) kontaktLeistung.value = 'shop';
      closeCart();
      var target = document.getElementById('kontakt');
      if (target) target.scrollIntoView({ behavior: 'smooth' });
      var nameField = document.getElementById('kontakt-name');
      if (nameField) setTimeout(function () { nameField.focus(); }, 500);
    });
  }

  renderCart();

  /* ---------- Nachbarschafts-CTA ---------- */
  var neighborCta = document.getElementById('neighbor-cta');
  if (neighborCta) {
    neighborCta.addEventListener('click', function () {
      if (kontaktLeistung) kontaktLeistung.value = 'nachbarschaft';
      if (kontaktNachricht && !kontaktNachricht.value.trim()) {
        kontaktNachricht.value = 'Wir sind mehrere Haushalte in einer Straße/einem Hof und möchten gemeinsam den Nachbarschafts-Bonus nutzen. Anzahl Haushalte: ';
      }
    });
  }

  var serviceHintLink = document.getElementById('kombi-termin-link');
  if (serviceHintLink) {
    serviceHintLink.addEventListener('click', function () {
      if (kontaktLeistung) kontaktLeistung.value = 'shop';
    });
  }

  document.querySelectorAll('.js-preset-leistung').forEach(function (link) {
    link.addEventListener('click', function () {
      if (kontaktLeistung) kontaktLeistung.value = link.dataset.leistung;
    });
  });

  /* ---------- Vorher/Nachher-Regler ---------- */
  (function () {
    var scene = document.querySelector('.tf-demo__scene');
    var handle = document.querySelector('.tf-demo__handle');
    if (!scene || !handle) return;
    var dragging = false;

    function currentP() {
      var v = parseFloat(scene.style.getPropertyValue('--p'));
      return isNaN(v) ? 0.55 : v;
    }
    function setP(p) {
      p = Math.min(1, Math.max(0, p));
      scene.style.setProperty('--p', p.toFixed(3));
      handle.setAttribute('aria-valuenow', String(Math.round(p * 100)));
    }
    function pFromEvent(clientX) {
      var rect = scene.getBoundingClientRect();
      return (clientX - rect.left) / rect.width;
    }

    handle.setAttribute('role', 'slider');
    handle.setAttribute('tabindex', '0');
    handle.setAttribute('aria-label', 'Vorher/Nachher-Vergleich verschieben');
    handle.setAttribute('aria-valuemin', '0');
    handle.setAttribute('aria-valuemax', '100');
    handle.setAttribute('aria-valuenow', String(Math.round(currentP() * 100)));

    handle.addEventListener('pointerdown', function (e) {
      dragging = true;
      handle.setPointerCapture(e.pointerId);
      e.preventDefault();
    });
    handle.addEventListener('pointermove', function (e) {
      if (!dragging) return;
      setP(pFromEvent(e.clientX));
    });
    handle.addEventListener('pointerup', function () { dragging = false; });
    handle.addEventListener('pointercancel', function () { dragging = false; });
    scene.addEventListener('pointerdown', function (e) {
      if (e.target === handle || handle.contains(e.target)) return;
      setP(pFromEvent(e.clientX));
    });
    handle.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowLeft') { setP(currentP() - 0.05); e.preventDefault(); }
      if (e.key === 'ArrowRight') { setP(currentP() + 0.05); e.preventDefault(); }
      if (e.key === 'Home') { setP(0); e.preventDefault(); }
      if (e.key === 'End') { setP(1); e.preventDefault(); }
    });
  })();

  /* ---------- Kontaktformular ---------- */
  (function () {
    var form = document.getElementById('kontakt-form');
    if (!form) return;
    var resultBox = document.getElementById('kontakt-result');
    var resultText = document.getElementById('kontakt-result-text');
    var copyBtn = document.getElementById('kontakt-copy');
    var mailLink = document.getElementById('kontakt-mail-link');

    var BUSINESS_EMAIL = 'hallo@gruenhof-berlin.de';

    function showError(row, message) {
      if (!row) return;
      row.classList.add('has-error');
      var err = row.querySelector('.form-error');
      if (err) err.textContent = message;
    }
    function clearError(row) {
      if (row) row.classList.remove('has-error');
    }

    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var valid = true;
      var name = document.getElementById('kontakt-name');
      var email = document.getElementById('kontakt-email');
      var telefon = document.getElementById('kontakt-telefon');
      var leistung = document.getElementById('kontakt-leistung');
      var nachricht = document.getElementById('kontakt-nachricht');
      var datenschutz = document.getElementById('kontakt-datenschutz');

      [name, email, leistung, nachricht].forEach(function (f) { clearError(f.closest('.form-row')); });
      clearError(datenschutz.closest('.form-check'));

      if (!name.value.trim()) { showError(name.closest('.form-row'), 'Bitte gib deinen Namen an.'); valid = false; }

      var emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailPattern.test(email.value.trim())) { showError(email.closest('.form-row'), 'Bitte gib eine gültige E-Mail-Adresse an.'); valid = false; }

      if (!leistung.value) { showError(leistung.closest('.form-row'), 'Bitte wähle ein Anliegen aus.'); valid = false; }

      if (nachricht.value.trim().length < 10) { showError(nachricht.closest('.form-row'), 'Bitte beschreibe kurz, worum es geht (mind. 10 Zeichen).'); valid = false; }

      if (!datenschutz.checked) {
        datenschutz.closest('.form-check').classList.add('has-error');
        valid = false;
      }

      if (!valid) {
        var firstError = form.querySelector('.has-error input, .has-error select, .has-error textarea, .has-error input[type="checkbox"]');
        if (firstError) firstError.focus();
        return;
      }

      var phone = telefon.value.trim();
      var leistungLabel = leistung.options[leistung.selectedIndex].text;
      var bodyLines = [
        'Name: ' + name.value.trim(),
        'E-Mail: ' + email.value.trim(),
        phone ? 'Telefon: ' + phone : null,
        'Anliegen: ' + leistungLabel,
        '',
        nachricht.value.trim()
      ].filter(function (l) { return l !== null; });
      var subject = 'Anfrage über Website: ' + leistungLabel;
      var body = bodyLines.join('\n');
      var mailto = 'mailto:' + BUSINESS_EMAIL + '?subject=' + encodeURIComponent(subject) + '&body=' + encodeURIComponent(body);

      if (resultBox) {
        resultBox.hidden = false;
        if (resultText) resultText.value = 'An: ' + BUSINESS_EMAIL + '\nBetreff: ' + subject + '\n\n' + body;
        if (mailLink) mailLink.href = mailto;
      }

      window.location.href = mailto;

      if (resultBox) {
        setTimeout(function () { resultBox.scrollIntoView({ behavior: 'smooth', block: 'center' }); }, 50);
      }
    });

    if (copyBtn) {
      copyBtn.addEventListener('click', function () {
        if (!resultText) return;
        resultText.focus();
        resultText.select();
        var done = function () {
          copyBtn.textContent = 'Kopiert ✓';
          setTimeout(function () { copyBtn.textContent = 'Text kopieren'; }, 1800);
        };
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(resultText.value).then(done).catch(function () {
            try { document.execCommand('copy'); done(); } catch (err) { /* clipboard unavailable */ }
          });
        } else {
          try { document.execCommand('copy'); done(); } catch (err) { /* clipboard unavailable */ }
        }
      });
    }
  })();

  /* ---------- 3D-Pop-up-Garten ---------- */
  (function () {
    var sec = document.querySelector('.popup');
    if (!sec) return;
    var book = sec.querySelector('[data-popup-book]');
    var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
    if ('IntersectionObserver' in window && !reduce) {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (x) { if (x.isIntersecting) { sec.classList.add('is-built'); io.disconnect(); } });
      }, { threshold: .32 });
      io.observe(sec);
    } else {
      sec.classList.add('is-built');
    }
    if (book && !reduce && matchMedia('(pointer: fine)').matches) {
      var raf = 0, tx = 0, ty = 0;
      var apply = function () { raf = 0; book.style.setProperty('--tx', tx.toFixed(3)); book.style.setProperty('--ty', ty.toFixed(3)); };
      sec.addEventListener('pointermove', function (ev) {
        var r = sec.getBoundingClientRect();
        tx = ((ev.clientX - r.left) / r.width - .5) * 2;
        ty = ((ev.clientY - r.top) / r.height - .5) * 2;
        if (!raf) raf = requestAnimationFrame(apply);
      });
      sec.addEventListener('pointerleave', function () { tx = 0; ty = 0; if (!raf) raf = requestAnimationFrame(apply); });
    }
    setTimeout(function () { sec.classList.add('is-built'); }, 2600);
  })();

})();
