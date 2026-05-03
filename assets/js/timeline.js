/* ============================================================
   TIMELINE.JS — Sort, filter, and expand/collapse logic
   K8s Security Lab
============================================================ */

/* ── STATE ───────────────────────────────────────────────── */
let currentSort   = 'newest';
let currentFilter = 'all';

/* ── TOGGLE ENTRY ────────────────────────────────────────── */
/**
 * Expand / collapse a timeline content card.
 * Called by onclick="toggleTL(this)" on .tl-content
 */
function toggleTL(el) {
  el.classList.toggle('open');
}

/* ── SORT ────────────────────────────────────────────────── */
/**
 * Re-orders .tl-year elements by data-year attribute.
 * @param {'newest'|'oldest'} dir
 * @param {HTMLElement} btn  - the clicked button
 */
function sortTimeline(dir, btn) {
  currentSort = dir;

  /* Update button active state */
  document.querySelectorAll('.tl-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');

  const track = document.getElementById('timelineTrack');
  const items = Array.from(track.querySelectorAll('.tl-year'));

  items.sort((a, b) => {
    const ay = parseInt(a.dataset.year, 10);
    const by = parseInt(b.dataset.year, 10);
    return dir === 'newest' ? by - ay : ay - by;
  });

  /* Re-append in sorted order */
  items.forEach(item => track.appendChild(item));
}

/* ── FILTER ──────────────────────────────────────────────── */
/**
 * Show/hide .tl-year elements by data-sev attribute.
 * @param {string}      sev - 'all' | 'critical' | 'high' | 'supply'
 * @param {HTMLElement} btn - the clicked filter button
 */
function filterTimeline(sev, btn) {
  currentFilter = sev;

  /* Update button active state */
  document.querySelectorAll('.tl-filter').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');

  document.querySelectorAll('.tl-year').forEach(el => {
    if (sev === 'all') {
      el.classList.remove('hidden');
      return;
    }
    const match = el.dataset.sev === sev;
    el.classList.toggle('hidden', !match);
  });
}
