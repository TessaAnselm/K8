/* ============================================================
   LAB.JS — Module tabs, scenario toggle, progress tracking
   K8s Security Lab
============================================================ */

const TOTAL_SCENARIOS = 9;
const STORAGE_KEY     = 'k8s-lab-progress';

/* ── MODULE TABS ─────────────────────────────────────────── */
/**
 * Switch active lab module panel.
 * Called by onclick="showModule('m1', this)" on each .mod-tab
 */
function showModule(id, btn) {
  document.querySelectorAll('.module-panel').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.mod-tab').forEach(t => t.classList.remove('active'));
  document.getElementById(id).classList.add('active');
  btn.classList.add('active');
}

/* ── SCENARIO TOGGLE ─────────────────────────────────────── */
/**
 * Expand/collapse a scenario card.
 * Ignores clicks on the checkbox and copy buttons.
 * Called by onclick="handleScenarioClick(event, 's1')"
 */
function handleScenarioClick(event, id) {
  const ignored = event.target.classList.contains('scenario-check') ||
                  event.target.closest('.copy-btn');
  if (ignored) return;
  document.getElementById(id).classList.toggle('open');
}

/* ── ATTACK CARDS (newest section) ──────────────────────── */
/**
 * Toggle collapsible attack cards in the Newest Attacks section.
 * Called by onclick="toggleCard(this)" on .attack-card
 */
function toggleCard(card) {
  card.classList.toggle('open');
}

/* ── PROGRESS TRACKING ───────────────────────────────────── */

/** Load progress object from localStorage */
function getProgress() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
  } catch {
    return {};
  }
}

/** Persist progress object to localStorage */
function saveProgress(progress) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(progress));
  } catch {
    /* localStorage unavailable — fail silently */
  }
}

/**
 * Toggle the completed state of one scenario.
 * Called by onclick="toggleCheck('s1')" on .scenario-check
 */
function toggleCheck(id) {
  const progress = getProgress();
  progress[id]   = !progress[id];
  saveProgress(progress);
  applyProgress(progress);
}

/**
 * Apply a progress object to the DOM:
 *   - marks completed scenarios
 *   - updates progress bar + counters
 */
function applyProgress(progress) {
  let done = 0;

  for (let i = 1; i <= TOTAL_SCENARIOS; i++) {
    const sid   = 's' + i;
    const el    = document.getElementById(sid);
    const check = document.getElementById('check-' + sid);
    if (!el || !check) continue;

    if (progress[sid]) {
      el.classList.add('completed');
      check.textContent = '✓';
      done++;
    } else {
      el.classList.remove('completed');
      check.textContent = '';
    }
  }

  /* Update progress bar */
  const pct = Math.round((done / TOTAL_SCENARIOS) * 100);
  const bar = document.getElementById('progressBar');
  if (bar) bar.style.width = pct + '%';

  /* Update count label */
  const countEl = document.getElementById('progressCount');
  if (countEl) countEl.textContent = done + ' / ' + TOTAL_SCENARIOS + ' complete';

  /* Update hero stat */
  const heroStat = document.getElementById('hero-progress-stat');
  if (heroStat) heroStat.textContent = done + '/' + TOTAL_SCENARIOS;
}

/** Clear all progress. Called by the Reset button. */
function resetProgress() {
  saveProgress({});
  applyProgress({});
}

/* ── INIT ────────────────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', () => {
  applyProgress(getProgress());
});
