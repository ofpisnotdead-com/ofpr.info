// The menu is a row of items on a wide screen and a drawer below that. Without this
// the drawer has no way to open, which is why the stylesheet in the head leaves the
// items showing when there is no script.
(() => {
  const burger = document.querySelector('.menu__burger');
  const list = document.getElementById('menu-list');
  if (!burger || !list) return;

  burger.addEventListener('click', () => {
    burger.setAttribute('aria-expanded', String(list.classList.toggle('is-open')));
  });
})();

// The report link opens a dialog with somewhere to send it; with no script it stays
// the plain link to the issue form that it already is.
(() => {
  const openers = document.querySelectorAll('.report__open');
  const dialog = document.getElementById('report');
  if (openers.length === 0 || !dialog) return;

  openers.forEach((opener) => opener.addEventListener('click', (event) => {
    event.preventDefault();
    dialog.showModal();
  }));
  dialog.addEventListener('click', (event) => {
    if (event.target === dialog) dialog.close();
  });
  dialog.querySelector('.report__close').addEventListener('click', () => dialog.close());
})();

// Every picture in the archive is a thumbnail linking to the full size. This turns that
// pair into a viewer: open one, page through the rest, leave with Escape. Without
// javascript each link still opens its own picture, which is all they ever did.
(() => {
  const IMAGE = /\.(jpe?g|png|gif|bmp|webp)$/i;
  const HEADING = /^H[1-6]$/;
  const all = [...document.querySelectorAll('.body a')]
    .filter((link) => link.querySelector('img') && IMAGE.test(link.pathname));
  if (all.length === 0) return;

  // A heading ends a gallery. On the mods page that gives each mod its own screenshots
  // rather than one run through every mod on the page; an article, which has no
  // headings, keeps all of its pictures together.
  const groups = [];
  let run = null;
  document.querySelectorAll('.body > *').forEach((node) => {
    if (HEADING.test(node.tagName)) return (run = null);

    const found = all.filter((link) => node.contains(link));
    if (found.length === 0) return;
    if (!run) groups.push((run = []));
    run.push(...found);
  });
  if (groups.length === 0) groups.push(all);

  const groupOf = new Map();
  groups.forEach((group) => group.forEach((link) => groupOf.set(link, group)));

  // Drawn rather than typed: a glyph sits wherever its font puts it, which is never
  // the middle of a button.
  const icon = (path) =>
    `<svg class="viewer__icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
       <path d="${path}"/>
     </svg>`;

  const button = (name, label, path, data = '') =>
    `<button class="viewer__button viewer__${name}" type="button" aria-label="${label}" ${data}>
       ${icon(path)}
     </button>`;

  const viewer = document.createElement('dialog');
  viewer.className = 'viewer';
  viewer.innerHTML = `
    ${button('close', 'Close', 'M6 6l12 12M18 6L6 18')}
    ${button('step', 'Previous picture', 'M15 4l-8 8 8 8', 'data-step="-1"')}
    <img class="viewer__picture" alt="">
    ${button('step', 'Next picture', 'M9 4l8 8-8 8', 'data-step="1"')}
    <p class="viewer__caption"><span class="viewer__count"></span><span class="viewer__file"></span></p>`;
  document.body.append(viewer);

  const picture = viewer.querySelector('.viewer__picture');
  const count = viewer.querySelector('.viewer__count');
  const file = viewer.querySelector('.viewer__file');
  const steps = [...viewer.querySelectorAll('.viewer__step')];
  let shots = all;
  let at = 0;
  let opener = null;

  const preload = (index) => {
    const shot = shots.at(index % shots.length);
    if (shot) new Image().src = shot.href;
  };

  const show = (index) => {
    at = (index + shots.length) % shots.length;
    const shot = shots[at];
    picture.classList.remove('is-ready');
    picture.src = shot.href;
    picture.alt = shot.querySelector('img')?.alt ?? '';
    count.textContent = shots.length > 1 ? `${at + 1} of ${shots.length}` : '';
    file.textContent = decodeURIComponent(shot.pathname.split('/').pop());
    steps.forEach((step) => { step.hidden = shots.length < 2; });
    preload(at + 1);
    preload(at - 1);
  };

  picture.addEventListener('load', () => picture.classList.add('is-ready'));

  all.forEach((shot) => {
    shot.addEventListener('click', (event) => {
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;

      event.preventDefault();
      opener = shot;
      shots = groupOf.get(shot) ?? all;
      show(shots.indexOf(shot));
      viewer.showModal();
      document.documentElement.classList.add('is-held');
    });
  });

  steps.forEach((step) => {
    step.addEventListener('click', () => show(at + Number(step.dataset.step)));
  });
  viewer.querySelector('.viewer__close').addEventListener('click', () => viewer.close());

  viewer.addEventListener('keydown', (event) => {
    if (event.key === 'ArrowLeft') show(at - 1);
    if (event.key === 'ArrowRight') show(at + 1);
  });

  // A dialog's backdrop is the dialog itself as far as a click is concerned, so a click
  // that lands on anything inside it is not a click on the backdrop.
  viewer.addEventListener('click', (event) => {
    if (event.target === viewer) viewer.close();
  });

  viewer.addEventListener('close', () => {
    document.documentElement.classList.remove('is-held');
    picture.removeAttribute('src');
    opener?.focus();
  });

  let from = null;
  viewer.addEventListener('touchstart', (event) => { from = event.touches[0].clientX; },
    {passive: true});
  viewer.addEventListener('touchend', (event) => {
    const moved = event.changedTouches[0].clientX - from;
    if (Math.abs(moved) > 40) show(at + (moved < 0 ? 1 : -1));
  }, {passive: true});
})();

// A long list of what a download needs folds after its first eight; without
// javascript it is simply shown whole.
(() => {
  document.querySelectorAll('.needs__table').forEach((table) => {
    const rows = table.querySelectorAll('[data-fold]');
    if (rows.length === 0) return;

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'needs__more';
    const fold = (folded) => {
      rows.forEach((row) => { row.hidden = folded; });
      button.textContent = folded ? `Show all ${rows.length + 8}` : 'Show the first 8';
      button.setAttribute('aria-expanded', String(!folded));
    };
    let folded = true;
    button.addEventListener('click', () => { folded = !folded; fold(folded); });
    table.parentElement.after(button);
    fold(folded);
  });
})();
