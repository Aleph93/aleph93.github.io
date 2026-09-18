/* Alexandru Romanciuc - portfolio
   Vanilla, no dependencies.

   Everything here is an enhancement. With JS disabled, screenshot
   thumbnails stay plain links to the full-size image and no content
   becomes unreachable - which also keeps the page whole for text
   extractors and resume parsers. */

(function () {
  'use strict';

  /* ---------- "Save CV as PDF" ---------- */

  document.addEventListener('click', function (e) {
    var trigger = e.target.closest('[data-print]');
    if (trigger) {
      e.preventDefault();
      window.print();
    }
  });

  /* ---------- lightbox ---------- */

  var shotLinks = Array.prototype.slice.call(document.querySelectorAll('a[data-shot]'));
  if (!shotLinks.length) { return; }

  var box, stage, image, caption, counter, prevBtn, nextBtn, closeBtn;
  var group = [];        // the <a> elements of the gallery currently open
  var index = 0;
  var lastFocused = null;

  function build() {
    box = document.createElement('div');
    box.className = 'lightbox';
    box.hidden = true;
    box.setAttribute('role', 'dialog');
    box.setAttribute('aria-modal', 'true');
    box.setAttribute('aria-label', 'Screenshot viewer');

    box.innerHTML =
      '<button type="button" class="lightbox-close" aria-label="Close viewer">Close</button>' +
      '<div class="lightbox-stage"><img alt=""></div>' +
      '<div class="lightbox-bar">' +
        '<button type="button" class="lightbox-prev" aria-label="Previous screenshot">&#8592; Prev</button>' +
        '<span class="lightbox-count" aria-live="polite"></span>' +
        '<button type="button" class="lightbox-next" aria-label="Next screenshot">Next &#8594;</button>' +
      '</div>' +
      '<p class="lightbox-caption"></p>';

    stage    = box.querySelector('.lightbox-stage');
    image    = box.querySelector('.lightbox-stage img');
    caption  = box.querySelector('.lightbox-caption');
    counter  = box.querySelector('.lightbox-count');
    prevBtn  = box.querySelector('.lightbox-prev');
    nextBtn  = box.querySelector('.lightbox-next');
    closeBtn = box.querySelector('.lightbox-close');

    prevBtn.addEventListener('click', function () { step(-1); });
    nextBtn.addEventListener('click', function () { step(1); });
    closeBtn.addEventListener('click', close);

    // Click the backdrop (but not the image or the controls) to dismiss.
    box.addEventListener('click', function (e) {
      if (e.target === box || e.target === stage) { close(); }
    });

    document.body.appendChild(box);
  }

  function show(i) {
    index = (i + group.length) % group.length;   // wraps both directions
    var link = group[index];
    var thumb = link.querySelector('img');

    image.src = link.getAttribute('href');
    image.alt = thumb ? thumb.getAttribute('alt') : '';
    caption.textContent = thumb ? thumb.getAttribute('alt') : '';
    counter.textContent = (index + 1) + ' / ' + group.length;

    var solo = group.length < 2;
    prevBtn.hidden = solo;
    nextBtn.hidden = solo;
    counter.hidden = solo;
  }

  function step(delta) { show(index + delta); }

  function open(link) {
    var list = link.closest('.shots');
    group = list
      ? Array.prototype.slice.call(list.querySelectorAll('a[data-shot]'))
      : [link];

    lastFocused = document.activeElement;
    show(group.indexOf(link));

    box.hidden = false;
    document.body.style.overflow = 'hidden';
    closeBtn.focus();
  }

  function close() {
    box.hidden = true;
    image.removeAttribute('src');
    document.body.style.overflow = '';
    if (lastFocused && lastFocused.focus) { lastFocused.focus(); }
    lastFocused = null;
  }

  build();

  document.addEventListener('click', function (e) {
    var link = e.target.closest('a[data-shot]');
    if (!link) { return; }
    // Leave modified clicks alone so "open in new tab" still works.
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) { return; }
    e.preventDefault();
    open(link);
  });

  document.addEventListener('keydown', function (e) {
    if (box.hidden) { return; }

    switch (e.key) {
      case 'Escape':     e.preventDefault(); close();  break;
      case 'ArrowLeft':  e.preventDefault(); step(-1); break;
      case 'ArrowRight': e.preventDefault(); step(1);  break;
      case 'Tab': {
        // Keep focus inside the dialog while it is open.
        var focusable = Array.prototype.filter.call(
          box.querySelectorAll('button'),
          function (el) { return !el.hidden; }
        );
        if (!focusable.length) { return; }

        var first = focusable[0];
        var last  = focusable[focusable.length - 1];

        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault(); last.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault(); first.focus();
        }
        break;
      }
    }
  });
}());
