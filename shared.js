// Fade-in background image after load
window.addEventListener('DOMContentLoaded', function () {
  try {
    const bg = document.querySelector('.hero-bg');
    if (bg) {
      const bgImg = new Image();
      bgImg.src = '/assets/background-photo-green.jpeg';
      bgImg.onload = function () {
        bg.classList.add('bg-loaded');
      };
      bgImg.onerror = function () {
        console.warn('Background image failed to load');
      };
    }
  } catch (error) {
    console.error('Error loading background image:', error);
  }
});

// Back button handler (404 page)
document.addEventListener('DOMContentLoaded', function () {
  const backBtn = document.getElementById('backBtn');
  if (backBtn) {
    backBtn.addEventListener('click', () => {
      window.location.href = '/';
    });
  }
});

// Resume PDF show/hide handler
document.addEventListener('DOMContentLoaded', function () {
  const btn = document.getElementById('showResumeBtn');
  const container = document.getElementById('pdfContainer');

  if (btn && container) {
    btn.addEventListener('click', () => {
      const isShowing = container.classList.toggle('show');
      btn.setAttribute('aria-expanded', isShowing);
      btn.textContent = isShowing ? 'Hide Resume' : 'Show Resume';
    });
    
    // Allow Escape key to close
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && container.classList.contains('show')) {
        container.classList.remove('show');
        btn.setAttribute('aria-expanded', 'false');
        btn.textContent = 'Show Resume';
      }
    });
  }
});
