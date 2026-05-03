/* ============================================================
   MITRE.JS — Tactic click → highlight related CVEs in timeline
   K8s Security Lab
============================================================ */

let selectedMitre = null;

/**
 * Called by onclick="filterByMitre('TA0001', this)" on each .mitre-tactic
 * Scrolls to timeline and highlights entries whose data-mitre includes the tactic.
 */
function filterByMitre(tactic, el) {
  /* Second click on same tactic = clear */
  if (selectedMitre === tactic) {
    clearMitreFilter();
    return;
  }

  selectedMitre = tactic;

  /* Highlight selected tactic card */
  document.querySelectorAll('.mitre-tactic').forEach(t => t.classList.remove('selected'));
  el.classList.add('selected');

  /* Update banner */
  const banner     = document.getElementById('mitreBanner');
  const bannerText = document.getElementById('mitreBannerText');
  const tacticName = el.querySelector('.mitre-tactic-name').textContent;
  bannerText.textContent = `Showing CVEs mapped to ${tactic} — ${tacticName}`;
  banner.style.display = 'flex';

  /* Scroll to timeline section */
  document.getElementById('timeline').scrollIntoView({ behavior: 'smooth', block: 'start' });

  /* Apply match/dim after scroll starts */
  setTimeout(() => {
    document.querySelectorAll('.tl-year').forEach(yr => {
      const mitre = yr.dataset.mitre || '';
      if (mitre.includes(tactic)) {
        yr.classList.add('mitre-match');
        yr.classList.remove('mitre-dim');
      } else {
        yr.classList.remove('mitre-match');
        yr.classList.add('mitre-dim');
      }
    });
  }, 400);
}

/**
 * Resets all MITRE highlight state.
 * Called by the Clear button in the banner.
 */
function clearMitreFilter() {
  selectedMitre = null;

  document.querySelectorAll('.mitre-tactic').forEach(t => t.classList.remove('selected'));
  document.querySelectorAll('.tl-year').forEach(yr => {
    yr.classList.remove('mitre-match', 'mitre-dim');
  });

  /* Reset banner to default hint */
  const banner     = document.getElementById('mitreBanner');
  const bannerText = document.getElementById('mitreBannerText');
  bannerText.textContent = 'Click any tactic above → the CVE timeline will highlight entries that map to it';
  banner.style.display = 'flex';
}
