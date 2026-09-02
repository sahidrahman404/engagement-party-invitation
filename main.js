/* Rahman & Fia — invitation behaviour.
   Two jobs: the "Buka Undangan" cover gate, and reveal-on-scroll. No dependencies. */
(function () {
  'use strict';

  var body = document.body;
  var deck = document.getElementById('deck');
  var opener = document.getElementById('opener');
  var calm = window.matchMedia('(prefers-reduced-motion: reduce)');

  /* ── cover gate ──────────────────────────────────────────────────── */
  function open() {
    if (body.dataset.open === 'true') return;
    body.dataset.open = 'true';
    deck.focus({ preventScroll: true });
  }

  if (opener) {
    opener.addEventListener('click', open);
  } else {
    body.dataset.open = 'true';
  }

  /* Keep the deck pinned to screen 01 while the gate is closed — a bfcache
     restore or a mid-scroll reload would otherwise leave it part-way down. */
  deck.addEventListener('scroll', function () {
    if (body.dataset.open === 'false' && deck.scrollTop !== 0) deck.scrollTop = 0;
  }, { passive: true });

  window.addEventListener('pageshow', function () {
    if (body.dataset.open === 'false') deck.scrollTop = 0;
  });

  /* ── reveal on scroll ────────────────────────────────────────────── */
  var targets = document.querySelectorAll('[data-reveal]');

  if (calm.matches || !('IntersectionObserver' in window)) {
    targets.forEach(function (el) { el.classList.add('is-visible'); });
    return;
  }

  var seen = new WeakMap();

  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (!entry.isIntersecting) return;

      /* Stagger siblings within a screen so a section arrives as a sequence
         rather than all at once. */
      var screen = entry.target.closest('.screen');
      var n = seen.get(screen) || 0;
      seen.set(screen, n + 1);
      entry.target.style.setProperty('--delay', Math.min(n, 5) * 110 + 'ms');

      entry.target.classList.add('is-visible');
      io.unobserve(entry.target);
    });
  }, { root: deck, threshold: 0.15, rootMargin: '0px 0px -8% 0px' });

  targets.forEach(function (el) { io.observe(el); });
})();
