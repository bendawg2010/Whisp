(function () {
  // === 1. DOWNLOAD GATE MODAL LOGIC ===
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


  // === 2. INTERACTIVE WHISP WEB MOCKUP ===
  
  // DOM Elements
  const statusDot = document.getElementById('webStatusDot');
  const statusText = document.getElementById('webStatusText');
  const shortcutLabel = document.getElementById('webShortcutLabel');
  const wave = document.getElementById('webWave');
  const waveContainer = document.getElementById('webWaveContainer');
  const transcriptBox = document.getElementById('webTranscriptBox');
  const transcriptText = document.getElementById('webTranscriptText');
  
  // Settings Controls
  const langSelect = document.getElementById('webLanguage');
  const textStyleSelect = document.getElementById('webTextStyle');
  const prefixInput = document.getElementById('webPrefix');
  const suffixInput = document.getElementById('webSuffix');
  const autoCopyToggle = document.getElementById('webAutoCopy');
  const showHudToggle = document.getElementById('webShowHUD');
  const hotkeyModifiersSelect = document.getElementById('webHotkeyModifiers');
  const hotkeyTriggerKeySelect = document.getElementById('webHotkeyTriggerKey');
  const hotkeyModeSelect = document.getElementById('webHotkeyMode');
  
  // Buttons
  const recordBtn = document.getElementById('webRecordBtn');
  const recordBtnText = document.getElementById('webRecordBtnText');
  const copyBtn = document.getElementById('webCopyBtn');
  const pasteBtn = document.getElementById('webPasteBtn');
  
  // History Elements
  const historyContainer = document.getElementById('webHistoryContainer');
  const historyList = document.getElementById('webHistoryList');
  
  // HUD Elements
  const webHud = document.getElementById('webHud');
  const webHudText = document.getElementById('webHudText');

  // Application State
  let isRecording = false;
  let rawTranscript = '';
  let finalFormattedText = '';
  
  // Web Audio Contexts
  let audioContext = null;
  let audioStream = null;
  let animationFrameId = null;
  
  // Speech Recognition Instances
  let recognition = null;
  let isSimulatedDictation = false;
  let simulatedInterval = null;
  let simulatedPhrase = '';
  let simulatedWordIndex = 0;

  // Set up Toast Notification System
  let toastElement = null;
  function createToastContainer() {
    toastElement = document.createElement('div');
    toastElement.className = 'web-toast';
    toastElement.innerHTML = '<span class="web-toast-icon">✓</span><span class="web-toast-message"></span>';
    document.body.appendChild(toastElement);
  }
  createToastContainer();

  function showToast(message) {
    if (!toastElement) return;
    toastElement.querySelector('.web-toast-message').textContent = message;
    toastElement.classList.add('show');
    setTimeout(() => {
      toastElement.classList.remove('show');
    }, 3000);
  }

  // Predefined Phrases for Simulated Typing fallback (Firefox, Brave, Safari without permissions)
  const SIMULATED_PHRASES = [
    "Whisp is a free, MIT-licensed macOS menubar app for fast voice-to-text. Talk anywhere, paste everywhere.",
    "Hello! This is a real-time speech-to-text demo running right inside my browser. It supports customizable text transformations, prefixes, and suffixes.",
    "With Whisp on your Mac, you just hold one shortcut, speak naturally, and clean text lands instantly wherever your cursor is working.",
    "This interactive web mockup demonstrates how the native app formats text, auto-copies to the clipboard, and displays a floating HUD window at the bottom of the screen."
  ];

  // Initialize Speech Recognition if supported
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (SpeechRecognition) {
    recognition = new SpeechRecognition();
    recognition.continuous = true;
    recognition.interimResults = true;

    recognition.onresult = (event) => {
      let finalTranscript = '';
      let interimTranscript = '';
      
      for (let i = 0; i < event.results.length; ++i) {
        let text = event.results[i][0].transcript;
        if (event.results[i].isFinal) {
          finalTranscript += text;
        } else {
          interimTranscript += text;
        }
      }
      
      let localRaw = finalTranscript + interimTranscript;
      updateLiveTranscript(localRaw);
    };

    recognition.onerror = (event) => {
      console.warn('Speech Recognition error:', event.error);
      if (event.error === 'not-allowed') {
        showToast("Mic permission denied. Running interactive mockup...");
        startSimulatedTranscription();
      } else {
        stopRecording(true);
      }
    };

    recognition.onend = () => {
      if (isRecording && !isSimulatedDictation) {
        // Recognition closed prematurely, finalize
        finalizeDictation();
      }
    };
  }

  // Formatting / Cleaning text (matches Swift implementation)
  function cleanAndFormat(text, transformation, prefix = '', suffix = '') {
    let cleaned = text.replace(/\s+/g, ' ').trim();
    if (!cleaned) return '';

    switch (transformation) {
      case 'raw':
        break;
      case 'standard':
        // Capitalize first character
        cleaned = cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
        // Append period if no final punctuation (. ? !)
        if (!/[.!?]$/.test(cleaned)) {
          cleaned += '.';
        }
        break;
      case 'bulletList':
        // Split by sentence punctuation
        const sentences = cleaned.split(/[.!?]+/)
          .map(s => s.trim())
          .filter(s => s.length > 0);
        cleaned = sentences.map(s => `- ${s}`).join('\n');
        break;
      case 'titleCase':
        // Capitalize first letter of every word
        cleaned = cleaned.split(' ')
          .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
          .join(' ');
        break;
      case 'upperCase':
        cleaned = cleaned.toUpperCase();
        break;
      case 'snakeCase':
        cleaned = cleaned.toLowerCase()
          .replace(/[^a-z0-9]+/g, '_')
          .replace(/^_+|_+$/g, '');
        break;
    }

    if (prefix) cleaned = prefix + cleaned;
    if (suffix) cleaned = cleaned + suffix;

    return cleaned;
  }

  // Update visualizer heights from live audio frequency
  async function startAudioVisualizer() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      audioStream = stream;

      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      audioContext = new AudioCtx();
      const source = audioContext.createMediaStreamSource(stream);
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = 64; // Gives 32 frequency bins
      source.connect(analyser);

      const bufferLength = analyser.frequencyBinCount;
      const dataArray = new Uint8Array(bufferLength);
      const bars = document.querySelectorAll('#webWave span.bar');
      const miniBars = document.querySelectorAll('#webHudEqualizer span.mini-bar');
      const hudEqualizer = document.getElementById('webHudEqualizer');
      if (hudEqualizer) hudEqualizer.classList.add('active');

      function draw() {
        if (!isRecording) return;
        animationFrameId = requestAnimationFrame(draw);
        analyser.getByteFrequencyData(dataArray);

        for (let i = 0; i < bars.length; i++) {
          const sampleIdx = Math.floor((i / bars.length) * bufferLength);
          const val = dataArray[sampleIdx];
          const scale = 0.25 + (val / 255) * 3.0; // Boost sensitivity for visual appeal
          bars[i].style.transform = `scaleY(${Math.min(2.8, scale)})`;
        }

        for (let i = 0; i < miniBars.length; i++) {
          const sampleIdx = Math.floor((i / miniBars.length) * bufferLength);
          const val = dataArray[sampleIdx];
          const scale = 0.25 + (val / 255) * 2.5; // Boost sensitivity for mini bars
          miniBars[i].style.transform = `scaleY(${Math.min(2.5, scale)})`;
        }
      }
      draw();
    } catch (err) {
      console.warn('Microphone stream access blocked:', err);
      startSimulatedVisualizer();
    }
  }

  // Fallback math-driven animated wave
  function startSimulatedVisualizer() {
    const bars = document.querySelectorAll('#webWave span.bar');
    const miniBars = document.querySelectorAll('#webHudEqualizer span.mini-bar');
    const hudEqualizer = document.getElementById('webHudEqualizer');
    if (hudEqualizer) hudEqualizer.classList.add('active');
    const startTime = Date.now();

    function drawSimulated() {
      if (!isRecording) return;
      animationFrameId = requestAnimationFrame(drawSimulated);
      const elapsed = (Date.now() - startTime) / 1000;

      for (let i = 0; i < bars.length; i++) {
        const wave1 = Math.sin(elapsed * 6 + i * 0.7) * 0.4 + 0.4;
        const wave2 = Math.cos(elapsed * 4 - i * 0.3) * 0.2 + 0.2;
        const noise = Math.random() * 0.12;
        const scale = 0.25 + (wave1 + wave2 + noise) * 1.8;
        bars[i].style.transform = `scaleY(${Math.min(2.5, Math.max(0.25, scale))})`;
      }

      for (let i = 0; i < miniBars.length; i++) {
        const wave1 = Math.sin(elapsed * 8 + i * 0.9) * 0.4 + 0.4;
        const wave2 = Math.cos(elapsed * 5 - i * 0.4) * 0.2 + 0.2;
        const noise = Math.random() * 0.1;
        const scale = 0.3 + (wave1 + wave2 + noise) * 1.5;
        miniBars[i].style.transform = `scaleY(${Math.min(2.2, Math.max(0.3, scale))})`;
      }
    }
    drawSimulated();
  }

  // Live updates as the user speaks (or simulator runs)
  function updateLiveTranscript(raw) {
    rawTranscript = raw;
    
    // Live format the intermediate text
    const formatType = textStyleSelect.value;
    const prefix = prefixInput.value;
    const suffix = suffixInput.value;
    
    finalFormattedText = cleanAndFormat(raw, formatType, prefix, suffix);
    
    // Render text to UI
    transcriptText.textContent = finalFormattedText || "Speak now...";
    webHudText.textContent = finalFormattedText || "Start speaking...";
    webHudText.scrollLeft = webHudText.scrollWidth;
  }

  // Simulated Speech-to-Text Fallback
  function startSimulatedTranscription() {
    isSimulatedDictation = true;
    rawTranscript = '';
    simulatedWordIndex = 0;
    
    // Pick random demo sentence
    simulatedPhrase = SIMULATED_PHRASES[Math.floor(Math.random() * SIMULATED_PHRASES.length)];
    const words = simulatedPhrase.split(' ');

    simulatedInterval = setInterval(() => {
      if (simulatedWordIndex < words.length) {
        rawTranscript += (simulatedWordIndex === 0 ? '' : ' ') + words[simulatedWordIndex];
        simulatedWordIndex++;
        updateLiveTranscript(rawTranscript);
      } else {
        // Automatically stop when sentence ends
        finalizeDictation();
      }
    }, 280);
  }

  // Start Dictation Lifecycle
  function startRecording() {
    if (isRecording) return;
    isRecording = true;
    rawTranscript = '';
    finalFormattedText = '';
    
    // UI State -> Recording active
    statusDot.className = 'status-dot recording';
    statusText.textContent = 'Listening...';
    wave.classList.add('active');
    transcriptBox.classList.add('recording');
    
    recordBtn.classList.add('recording');
    recordBtnText.textContent = 'Stop';
    
    copyBtn.disabled = true;
    pasteBtn.disabled = true;
    
    transcriptText.textContent = "Listening...";
    transcriptText.style.opacity = 0.9;
    
    // HUD Overlay
    if (showHudToggle.checked) {
      webHudText.textContent = "Start speaking...";
      webHud.classList.add('show');
    }

    // Trigger audio visualizer
    startAudioVisualizer();

    // Trigger Speech Engine
    if (recognition) {
      recognition.lang = langSelect.value;
      isSimulatedDictation = false;
      try {
        recognition.start();
      } catch (e) {
        console.warn('Recognition start error, falling back:', e);
        startSimulatedTranscription();
      }
    } else {
      startSimulatedTranscription();
    }
  }

  // Finalize/Complete Dictation Lifecycle
  function finalizeDictation() {
    if (!isRecording) return;
    isRecording = false;
    
    // UI -> Transcribing/Cleaning state
    statusDot.className = 'status-dot inactive';
    statusText.textContent = 'Transcribing...';
    wave.classList.remove('active');
    recordBtn.classList.remove('recording');
    recordBtnText.textContent = 'Record';
    
    // Hide HUD
    webHud.classList.remove('show');

    // Clean up Audio
    if (audioStream) {
      audioStream.getTracks().forEach(track => track.stop());
      audioStream = null;
    }
    if (audioContext && audioContext.state !== 'closed') {
      audioContext.close();
      audioContext = null;
    }
    if (animationFrameId) {
      cancelAnimationFrame(animationFrameId);
      animationFrameId = null;
    }
    
    // Reset visualizer bars to resting CSS animations
    const bars = document.querySelectorAll('#webWave span.bar');
    bars.forEach(bar => {
      bar.style.transform = '';
    });

    const miniBars = document.querySelectorAll('#webHudEqualizer span.mini-bar');
    miniBars.forEach(bar => {
      bar.style.transform = '';
    });
    const hudEqualizer = document.getElementById('webHudEqualizer');
    if (hudEqualizer) hudEqualizer.classList.remove('active');

    // Clear simulated triggers
    if (simulatedInterval) {
      clearInterval(simulatedInterval);
      simulatedInterval = null;
    }

    if (recognition && !isSimulatedDictation) {
      try {
        recognition.stop();
      } catch (e) {}
    }

    // Process final formatting
    const style = textStyleSelect.value;
    const prefix = prefixInput.value;
    const suffix = suffixInput.value;
    finalFormattedText = cleanAndFormat(rawTranscript, style, prefix, suffix);

    // Apply text results
    if (finalFormattedText) {
      transcriptText.textContent = finalFormattedText;
      copyBtn.disabled = false;
      pasteBtn.disabled = false;
      
      // Add to Dictation History
      addHistoryItem(finalFormattedText);

      // Auto-copy to Clipboard
      if (autoCopyToggle.checked) {
        navigator.clipboard.writeText(finalFormattedText)
          .then(() => showToast("Copied to clipboard automatically!"))
          .catch(() => showToast("Formatted text complete."));
      } else {
        showToast("Dictation complete.");
      }
    } else {
      transcriptText.textContent = "No text captured. Click Record to try again.";
      showToast("No speech detected.");
    }
    
    statusText.textContent = 'Click Record to talk';
    transcriptBox.classList.remove('recording');
  }

  function toggleRecord() {
    if (isRecording) {
      finalizeDictation();
    } else {
      startRecording();
    }
  }

  // Bind Buttons
  recordBtn.addEventListener('click', toggleRecord);
  
  copyBtn.addEventListener('click', () => {
    if (!finalFormattedText) return;
    navigator.clipboard.writeText(finalFormattedText)
      .then(() => showToast("Copied to clipboard!"))
      .catch(() => showToast("Copy failed."));
  });

  pasteBtn.addEventListener('click', () => {
    if (!finalFormattedText) return;
    // Browser Paste Simulation
    showToast("Pasted! (On macOS, Whisp drops text directly into your active window)");
  });

  let isHotkeyHeld = false;

  function matchesShortcut(e) {
    if (!hotkeyModifiersSelect || !hotkeyTriggerKeySelect) return false;
    const mods = hotkeyModifiersSelect.value;
    const keyVal = hotkeyTriggerKeySelect.value;

    let modsMatch = false;
    if (mods === 'controlOption') {
      modsMatch = e.ctrlKey && e.altKey && !e.metaKey && !e.shiftKey;
    } else if (mods === 'controlCommand') {
      modsMatch = e.ctrlKey && e.metaKey && !e.altKey && !e.shiftKey;
    } else if (mods === 'optionCommand') {
      modsMatch = e.altKey && e.metaKey && !e.ctrlKey && !e.shiftKey;
    } else if (mods === 'controlShift') {
      modsMatch = e.ctrlKey && e.shiftKey && !e.altKey && !e.metaKey;
    }

    if (!modsMatch) return false;

    let keyMatch = false;
    if (keyVal === 'Space') {
      keyMatch = e.code === 'Space' || e.key === ' ';
    } else if (keyVal === 'Return') {
      keyMatch = e.key === 'Enter';
    } else if (keyVal === 'Tab') {
      keyMatch = e.key === 'Tab';
    } else if (keyVal === 'Escape') {
      keyMatch = e.key === 'Escape';
    } else if (keyVal === 'D') {
      keyMatch = e.key.toLowerCase() === 'd';
    } else if (keyVal === 'R') {
      keyMatch = e.key.toLowerCase() === 'r';
    } else if (keyVal === 'Grave Accent (`)') {
      keyMatch = e.key === '`' || e.code === 'Backquote';
    }

    return keyMatch;
  }

  document.addEventListener('keydown', (e) => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT' || e.target.tagName === 'TEXTAREA') {
      return;
    }
    if (matchesShortcut(e)) {
      e.preventDefault();
      
      const mode = hotkeyModeSelect ? hotkeyModeSelect.value : 'hold';
      if (mode === 'hold') {
        if (!isHotkeyHeld) {
          isHotkeyHeld = true;
          if (!isRecording) {
            startRecording();
          }
        }
      } else {
        toggleRecord();
      }
    }
  });

  document.addEventListener('keyup', (e) => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT' || e.target.tagName === 'TEXTAREA') {
      return;
    }
    if (!hotkeyTriggerKeySelect) return;
    const keyVal = hotkeyTriggerKeySelect.value;
    let keyMatch = false;
    if (keyVal === 'Space') {
      keyMatch = e.code === 'Space' || e.key === ' ';
    } else if (keyVal === 'Return') {
      keyMatch = e.key === 'Enter';
    } else if (keyVal === 'Tab') {
      keyMatch = e.key === 'Tab';
    } else if (keyVal === 'Escape') {
      keyMatch = e.key === 'Escape';
    } else if (keyVal === 'D') {
      keyMatch = e.key.toLowerCase() === 'd';
    } else if (keyVal === 'R') {
      keyMatch = e.key.toLowerCase() === 'r';
    } else if (keyVal === 'Grave Accent (`)') {
      keyMatch = e.key === '`' || e.code === 'Backquote';
    }

    if (keyMatch) {
      isHotkeyHeld = false;
      const mode = hotkeyModeSelect ? hotkeyModeSelect.value : 'hold';
      if (mode === 'hold' && isRecording) {
        finalizeDictation();
      }
    }
  });

  function updateShortcutAndMode() {
    if (!hotkeyModifiersSelect || !hotkeyTriggerKeySelect || !hotkeyModeSelect) return;
    const mods = hotkeyModifiersSelect.value;
    const keyVal = hotkeyTriggerKeySelect.value;
    const mode = hotkeyModeSelect.value;

    let modDesc = '⌃⌥';
    if (mods === 'controlOption') modDesc = '⌃⌥';
    else if (mods === 'controlCommand') modDesc = '⌃⌘';
    else if (mods === 'optionCommand') modDesc = '⌥⌘';
    else if (mods === 'controlShift') modDesc = '⌃⇧';

    let keyDesc = 'Space';
    if (keyVal === 'Space') keyDesc = 'Space';
    else if (keyVal === 'Return') keyDesc = '↩';
    else if (keyVal === 'Tab') keyDesc = '⇥';
    else if (keyVal === 'Escape') keyDesc = '⎋';
    else if (keyVal === 'D') keyDesc = 'D';
    else if (keyVal === 'R') keyDesc = 'R';
    else if (keyVal === 'Grave Accent (`)') keyDesc = '`';

    const shortcutText = modDesc + keyDesc;
    if (shortcutLabel) shortcutLabel.textContent = shortcutText;

    if (!isRecording && (!finalFormattedText || transcriptText.textContent.startsWith("Press the button below or hit") || transcriptText.textContent.startsWith("Hold"))) {
      if (mode === 'hold') {
        transcriptText.textContent = `Hold ${shortcutText} to try Whisp right here in your browser.`;
      } else {
        transcriptText.textContent = `Press the button below or hit ${shortcutText} to try Whisp right here in your browser.`;
      }
    }
    
    saveLocalSettings();
  }

  if (hotkeyModifiersSelect) hotkeyModifiersSelect.addEventListener('change', updateShortcutAndMode);
  if (hotkeyTriggerKeySelect) hotkeyTriggerKeySelect.addEventListener('change', updateShortcutAndMode);
  if (hotkeyModeSelect) hotkeyModeSelect.addEventListener('change', updateShortcutAndMode);

  // Settings Live Updates (re-formats existing transcript box text in real time)
  function reformatActiveText() {
    if (rawTranscript && !isRecording) {
      const style = textStyleSelect.value;
      const prefix = prefixInput.value;
      const suffix = suffixInput.value;
      finalFormattedText = cleanAndFormat(rawTranscript, style, prefix, suffix);
      transcriptText.textContent = finalFormattedText || "Speak now...";
    }
    saveLocalSettings();
  }

  textStyleSelect.addEventListener('change', reformatActiveText);
  prefixInput.addEventListener('input', reformatActiveText);
  suffixInput.addEventListener('input', reformatActiveText);
  langSelect.addEventListener('change', saveLocalSettings);
  autoCopyToggle.addEventListener('change', saveLocalSettings);
  showHudToggle.addEventListener('change', saveLocalSettings);

  // === 3. LOCAL SETTINGS PERSISTENCE ===
  
  function saveLocalSettings() {
    const settings = {
      lang: langSelect.value,
      textStyle: textStyleSelect.value,
      prefix: prefixInput.value,
      suffix: suffixInput.value,
      autoCopy: autoCopyToggle.checked,
      showHud: showHudToggle.checked,
      hotkeyModifiers: hotkeyModifiersSelect ? hotkeyModifiersSelect.value : 'controlOption',
      hotkeyTriggerKey: hotkeyTriggerKeySelect ? hotkeyTriggerKeySelect.value : 'Space',
      hotkeyMode: hotkeyModeSelect ? hotkeyModeSelect.value : 'hold'
    };
    localStorage.setItem('whisp_web_settings', JSON.stringify(settings));
  }

  function loadLocalSettings() {
    try {
      const stored = localStorage.getItem('whisp_web_settings');
      if (stored) {
        const settings = JSON.parse(stored);
        if (settings.lang) langSelect.value = settings.lang;
        if (settings.textStyle) textStyleSelect.value = settings.textStyle;
        if (settings.prefix) prefixInput.value = settings.prefix;
        if (settings.suffix) suffixInput.value = settings.suffix;
        if (settings.autoCopy !== undefined) autoCopyToggle.checked = settings.autoCopy;
        if (settings.showHud !== undefined) showHudToggle.checked = settings.showHud;
        if (settings.hotkeyModifiers && hotkeyModifiersSelect) hotkeyModifiersSelect.value = settings.hotkeyModifiers;
        if (settings.hotkeyTriggerKey && hotkeyTriggerKeySelect) hotkeyTriggerKeySelect.value = settings.hotkeyTriggerKey;
        if (settings.hotkeyMode && hotkeyModeSelect) hotkeyModeSelect.value = settings.hotkeyMode;
      }
    } catch (e) {
      console.warn("Failed to load local settings:", e);
    }
  }

  // === 4. WEB HISTORY LOGIC ===
  let dictationHistory = [];

  function loadHistory() {
    try {
      const stored = localStorage.getItem('whisp_web_history');
      if (stored) {
        dictationHistory = JSON.parse(stored);
        renderHistoryList();
      }
    } catch (e) {
      console.warn("Failed to load dictation history:", e);
    }
  }

  function saveHistory() {
    localStorage.setItem('whisp_web_history', JSON.stringify(dictationHistory));
  }

  function addHistoryItem(text) {
    const item = {
      id: Date.now(),
      text: text,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      date: new Date().toLocaleDateString()
    };
    dictationHistory.unshift(item);
    
    // Cap history list at 10 items for landing page clean mockup feel
    if (dictationHistory.length > 10) {
      dictationHistory = dictationHistory.slice(0, 10);
    }
    
    saveHistory();
    renderHistoryList();
  }

  function deleteHistoryItem(id) {
    dictationHistory = dictationHistory.filter(item => item.id !== id);
    saveHistory();
    renderHistoryList();
    showToast("Dictation deleted.");
  }

  function renderHistoryList() {
    historyList.innerHTML = '';
    
    if (dictationHistory.length === 0) {
      historyContainer.hidden = true;
      return;
    }
    
    historyContainer.hidden = false;
    
    dictationHistory.forEach(item => {
      const card = document.createElement('div');
      card.className = 'web-history-item';
      
      const copyBtnSvg = `
        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
          <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
        </svg>
      `;
      
      const trashBtnSvg = `
        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="3 6 5 6 21 6"></polyline>
          <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
        </svg>
      `;

      card.innerHTML = `
        <div class="web-history-text" title="${item.text}">${item.text}</div>
        <div class="web-history-meta">${item.timestamp}</div>
        <div class="web-history-actions">
          <button class="web-history-btn copy" title="Copy to clipboard">${copyBtnSvg}</button>
          <button class="web-history-btn delete" title="Delete entry">${trashBtnSvg}</button>
        </div>
      `;

      // Copy Action
      card.querySelector('.web-history-btn.copy').addEventListener('click', () => {
        navigator.clipboard.writeText(item.text)
          .then(() => showToast("Copied history text!"))
          .catch(() => showToast("Copy failed."));
      });

      // Delete Action
      card.querySelector('.web-history-btn.delete').addEventListener('click', () => {
        deleteHistoryItem(item.id);
      });

      historyList.appendChild(card);
    });
  }

  // Load configuration and history on bootstrap
  loadLocalSettings();
  updateShortcutAndMode();
  loadHistory();
})();
