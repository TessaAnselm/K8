/* ============================================================
   SEARCH.JS — Global page search with text highlighting
   K8s Security Lab
============================================================ */

/**
 * Main search handler — called oninput on the search field.
 * Walks all text nodes across sections, wraps matches in <mark>.
 */
function handleSearch(query) {
  const countEl = document.getElementById('searchCount');

  /* Clear previous highlights first */
  clearHighlights();

  if (!query.trim()) {
    if (countEl) countEl.textContent = '';
    return;
  }

  /* Escape special regex characters in the query */
  const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex   = new RegExp(escaped, 'gi');

  let totalMatches = 0;

  /* Walk every section, then every text node */
  document.querySelectorAll('section').forEach(section => {
    const walker = document.createTreeWalker(section, NodeFilter.SHOW_TEXT);
    const nodes  = [];
    let node;
    while ((node = walker.nextNode())) nodes.push(node);

    nodes.forEach(textNode => {
      /* Skip nodes inside the search input itself */
      if (!textNode.parentElement) return;
      if (textNode.parentElement.closest('.search-wrap')) return;
      /* Skip nodes already inside a <mark> (avoids double-wrapping) */
      if (textNode.parentElement.tagName === 'MARK') return;

      const text = textNode.textContent;
      if (!regex.test(text)) return;
      regex.lastIndex = 0; /* reset after test() */

      const matches = text.match(regex) || [];
      totalMatches += matches.length;

      /* Replace text node with a span containing <mark> elements */
      const wrapper   = document.createElement('span');
      wrapper.dataset.searchWrapper = '1';
      wrapper.innerHTML = text.replace(regex, m => `<mark class="highlight">${m}</mark>`);
      textNode.parentElement.replaceChild(wrapper, textNode);
    });
  });

  if (countEl) {
    countEl.textContent = totalMatches
      ? totalMatches + (totalMatches === 1 ? ' match' : ' matches')
      : 'No matches';
  }
}

/**
 * Remove all <mark> highlights and unwrap search wrapper spans.
 */
function clearHighlights() {
  /* Unwrap all search wrapper spans, restoring original text nodes */
  document.querySelectorAll('span[data-search-wrapper]').forEach(wrapper => {
    const parent = wrapper.parentNode;
    if (!parent) return;
    /* Replace wrapper with its plain text content */
    const text = document.createTextNode(wrapper.textContent);
    parent.replaceChild(text, wrapper);
    parent.normalize();
  });
}
