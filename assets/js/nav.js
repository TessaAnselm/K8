/* ============================================================
   NAV.JS — Scroll-aware navigation link highlighting
   K8s Security Lab
============================================================ */

/**
 * Highlights the nav link whose section is currently in view.
 * Uses a 140px offset so the link activates slightly before
 * the section reaches the very top of the viewport.
 */
(function initNav() {
  const OFFSET = 140;

  const sections = document.querySelectorAll('section[id]');
  const navLinks = document.querySelectorAll('.nav-links a');

  function onScroll() {
    let current = '';

    sections.forEach(section => {
      if (window.scrollY >= section.offsetTop - OFFSET) {
        current = section.id;
      }
    });

    navLinks.forEach(link => {
      const href = link.getAttribute('href');
      link.classList.toggle('active', href === '#' + current);
    });
  }

  window.addEventListener('scroll', onScroll, { passive: true });

  /* Run once on load to set initial state */
  onScroll();
})();
