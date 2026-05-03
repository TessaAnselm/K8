/* ============================================================
   COPY.JS — Copy button logic for all code blocks
   K8s Security Lab
============================================================ */

/**
 * Called by onclick="copyCode(this)" on each .copy-btn
 * Reads the sibling .code element and copies its innerText
 */
function copyCode(btn) {
  const codeEl = btn.previousElementSibling;
  if (!codeEl) return;

  const text = codeEl.innerText;

  navigator.clipboard.writeText(text)
    .then(() => {
      btn.textContent = 'Copied!';
      btn.classList.add('copied');
      setTimeout(() => {
        btn.textContent = 'Copy';
        btn.classList.remove('copied');
      }, 2000);
    })
    .catch(() => {
      /* Fallback for older browsers */
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      btn.textContent = 'Copied!';
      btn.classList.add('copied');
      setTimeout(() => {
        btn.textContent = 'Copy';
        btn.classList.remove('copied');
      }, 2000);
    });
}
