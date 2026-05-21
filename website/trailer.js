(function () {
  // === MACBOOK SIMULATOR STATE MACHINE ===
  
  const scenarios = [
    {
      app: "Notes",
      placeholder: "Start typing here...",
      speech: "Hey team, just drafting the launch announcement. Whisp is working perfectly on my Mac! It is super lightweight and fast.",
      output: "Hey team, just drafting the launch announcement. Whisp is working perfectly on my Mac! It is super lightweight and fast."
    },
    {
      app: "Notes",
      placeholder: "Start typing here...",
      speech: "select star from users where status equals active order by created at desc limit ten",
      output: "SELECT * FROM users WHERE status = 'active' ORDER BY created_at DESC LIMIT 10;"
    },
    {
      app: "Notes",
      placeholder: "Start typing here...",
      speech: "bullet point write description of speech to text app bullet point support multiple custom formats bullet point build using native swift stack",
      output: "- Write description of speech to text app\n- Support multiple custom formats\n- Build using native Swift stack"
    }
  ];

  let currentScenarioIdx = 0;
  let state = "idle"; // idle, hotkey1, recording, hotkey2, pasting, success, reset
  let activeText = "";
  let timerId = null;
  let wordTimerId = null;
  let visualizerAnimId = null;

  // DOM Elements (Inside MacBook Frame)
  const menuIcon = document.getElementById('simMenuIcon');
  const keypress = document.getElementById('simKeypress');
  const hud = document.getElementById('simHud');
  const hudText = document.getElementById('simHudText');
  const hudEqualizer = document.getElementById('simHudEqualizer');
  const notesBody = document.getElementById('simNotesBody');
  const playPauseBtn = document.getElementById('simPlayPause');

  let isPlaying = true;

  // Reset all visual states
  function resetSimulation() {
    state = "idle";
    activeText = "";
    if (timerId) clearTimeout(timerId);
    if (wordTimerId) clearInterval(wordTimerId);
    if (visualizerAnimId) cancelAnimationFrame(visualizerAnimId);

    // DOM resets
    if (keypress) {
      keypress.classList.remove('show');
      keypress.classList.remove('pressed');
    }
    if (hud) {
      hud.classList.remove('show');
      hud.classList.remove('success');
    }
    if (hudText) hudText.textContent = "Start speaking...";
    if (hudEqualizer) {
      hudEqualizer.classList.remove('active');
      const miniBars = hudEqualizer.querySelectorAll('.sim-mini-bar');
      miniBars.forEach(bar => bar.style.transform = '');
    }
    if (menuIcon) menuIcon.classList.remove('active');
    if (notesBody) {
      const activeScenario = scenarios[currentScenarioIdx];
      notesBody.innerHTML = `<span class="sim-cursor"></span>`;
    }
  }

  // Mini simulator equalizer animations
  function animateSimVisualizer() {
    if (state !== "recording") return;
    const miniBars = hudEqualizer.querySelectorAll('.sim-mini-bar');
    const elapsed = Date.now() / 1000;

    for (let i = 0; i < miniBars.length; i++) {
      const wave1 = Math.sin(elapsed * 10 + i * 1.1) * 0.45 + 0.45;
      const wave2 = Math.cos(elapsed * 6 - i * 0.5) * 0.25 + 0.25;
      const noise = Math.random() * 0.15;
      const scale = 0.35 + (wave1 + wave2 + noise) * 1.8;
      miniBars[i].style.transform = `scaleY(${Math.min(2.5, Math.max(0.35, scale))})`;
    }

    visualizerAnimId = requestAnimationFrame(animateSimVisualizer);
  }

  // Simulation Sequence runner
  function runSequence() {
    if (!isPlaying) return;
    const activeScenario = scenarios[currentScenarioIdx];

    switch (state) {
      case "idle":
        // Wait 1.5 seconds, then show the hotkey shortcut overlay being pressed
        state = "hotkey1";
        timerId = setTimeout(() => {
          if (!isPlaying) return;
          if (keypress) {
            keypress.textContent = "⌃⌥Space";
            keypress.classList.add('show');
            setTimeout(() => { keypress.classList.add('pressed'); }, 150);
          }
          runSequence();
        }, 1500);
        break;

      case "hotkey1":
        // Wait 0.6 seconds, trigger recording start, hide hotkey indicator
        state = "recording";
        timerId = setTimeout(() => {
          if (!isPlaying) return;
          if (keypress) keypress.classList.remove('show', 'pressed');
          if (menuIcon) menuIcon.classList.add('active');
          if (hud) hud.classList.add('show');
          if (hudEqualizer) hudEqualizer.classList.add('active');
          
          animateSimVisualizer();

          // Type out the spoken words
          const words = activeScenario.speech.split(" ");
          let wordIdx = 0;
          activeText = "";

          wordTimerId = setInterval(() => {
            if (!isPlaying) return;
            if (wordIdx < words.length) {
              activeText += (wordIdx === 0 ? "" : " ") + words[wordIdx];
              if (hudText) hudText.textContent = activeText;
              wordIdx++;
            } else {
              clearInterval(wordTimerId);
              // Done speaking, trigger hotkey trigger to stop
              state = "hotkey2";
              runSequence();
            }
          }, 350); // Speed of spoken words typing
        }, 700);
        break;

      case "hotkey2":
        // Wait 0.5s, flash hotkey overlay again to stop recording
        timerId = setTimeout(() => {
          if (!isPlaying) return;
          if (keypress) {
            keypress.classList.add('show');
            setTimeout(() => { keypress.classList.add('pressed'); }, 150);
          }
          state = "pasting";
          runSequence();
        }, 500);
        break;

      case "pasting":
        // Wait 0.6s, show success HUD state ("Pasted!"), stop wave visualizers, slide HUD down, paste into editor
        timerId = setTimeout(() => {
          if (!isPlaying) return;
          if (keypress) keypress.classList.remove('show', 'pressed');
          if (menuIcon) menuIcon.classList.remove('active');
          if (hudEqualizer) {
            hudEqualizer.classList.remove('active');
            const miniBars = hudEqualizer.querySelectorAll('.sim-mini-bar');
            miniBars.forEach(bar => bar.style.transform = '');
          }
          if (hud) {
            hud.classList.add('success');
            if (hudText) hudText.textContent = "Copied & Pasted!";
          }

          // After Success delay, slide HUD out and insert text
          setTimeout(() => {
            if (!isPlaying) return;
            if (hud) hud.classList.remove('show', 'success');

            // Type text into Notes Editor
            let textToPaste = activeScenario.output;
            let currentLength = 0;
            
            // Fast typing animation simulating direct app insert
            const pasteTimer = setInterval(() => {
              if (!isPlaying) {
                clearInterval(pasteTimer);
                return;
              }
              if (currentLength <= textToPaste.length) {
                const subStr = textToPaste.substring(0, currentLength);
                // Convert newlines to breaks or handle spacing
                const formattedHtml = subStr.replace(/\n/g, '<br>') + '<span class="sim-cursor"></span>';
                if (notesBody) notesBody.innerHTML = formattedHtml;
                currentLength += Math.min(3, textToPaste.length - currentLength + 1); // Fast typing jump
              } else {
                clearInterval(pasteTimer);
                state = "success";
                runSequence();
              }
            }, 40);

          }, 800);
        }, 600);
        break;

      case "success":
        // Stay on finished note for 4.5 seconds, then transition to next scenario
        timerId = setTimeout(() => {
          if (!isPlaying) return;
          currentScenarioIdx = (currentScenarioIdx + 1) % scenarios.length;
          resetSimulation();
          runSequence();
        }, 4500);
        break;
    }
  }

  // Bind Play/Pause Controls
  if (playPauseBtn) {
    playPauseBtn.addEventListener('click', () => {
      isPlaying = !isPlaying;
      if (isPlaying) {
        playPauseBtn.innerHTML = `
          <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor">
            <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>
          </svg>
          Pause Simulation
        `;
        runSequence();
      } else {
        playPauseBtn.innerHTML = `
          <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor">
            <path d="M8 5v14l11-7z"/>
          </svg>
          Play Simulation
        `;
        resetSimulation();
      }
    });
  }

  // Initialize
  resetSimulation();
  runSequence();

})();
