(function () {
  const gate = document.getElementById('dlGate');
  const closeBtn = document.getElementById('dlGateClose');
  const confirmBtn = document.getElementById('dlGateConfirm');
  const confirmText = confirmBtn && confirmBtn.querySelector('.dl-gate-btn-text');
  let countdownTimer = null;

  function openGate(href) {
    gate.removeAttribute('hidden');
    confirmBtn.setAttribute('data-locked', 'true');
    confirmBtn.setAttribute('href', href);
    let remaining = 3;
    const tick = function () {
      if (remaining > 0) {
        confirmText.textContent = 'Read above (' + remaining + 's)...';
        remaining--;
      } else {
        confirmBtn.removeAttribute('data-locked');
        confirmText.textContent = 'Download Whisp';
        clearInterval(countdownTimer);
      }
    };
    tick();
    clearInterval(countdownTimer);
    countdownTimer = setInterval(tick, 1000);
  }

  function closeGate() {
    gate.setAttribute('hidden', '');
    clearInterval(countdownTimer);
    confirmBtn.setAttribute('data-locked', 'true');
    if (confirmText) confirmText.textContent = 'Read above first...';
  }

  document.querySelectorAll('[data-download-trigger]').forEach(function (link) {
    link.addEventListener('click', function (e) {
      e.preventDefault();
      openGate(link.getAttribute('href'));
    });
  });

  if (confirmBtn) confirmBtn.addEventListener('click', function (e) {
    if (confirmBtn.getAttribute('data-locked') === 'true') {
      e.preventDefault();
      return;
    }
    setTimeout(closeGate, 400);
  });

  if (closeBtn) closeBtn.addEventListener('click', closeGate);
  if (gate) gate.addEventListener('click', function (e) {
    if (e.target === gate) closeGate();
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !gate.hasAttribute('hidden')) closeGate();
  });
})();

