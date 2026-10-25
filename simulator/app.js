// SeeForMe AI Interactive Simulator Engine
let currentMode = 'community';
let isOffline = false;
let currentProvider = 'scx';
let currentVoice = 'rachel';
let lastSpokenText = '';

// Clock
setInterval(() => {
    const now = new Date();
    const hours = now.getHours();
    const mins = String(now.getMinutes()).padStart(2, '0');
    const el = document.getElementById('currentTime');
    if (el) el.textContent = `${hours}:${mins}`;
}, 1000);

// Presets Data with Inline High-Resolution SVG Visuals
const PRESETS = {
    'sydney-transit': {
        title: 'Sydney Transit & Opal Signs',
        summary: 'Sydney Trains Platform 2 sign at Martin Place. Next service: T4 Eastern Suburbs line approaching in 3 minutes.',
        detail: 'Opal card reader is positioned directly to your left on the entrance gate pillar. Tactile paving leads straight to the platform edge.',
        uncertainty: 'Verified via SCX Sovereign Infrastructure (au-syd-1). Traffic delays subject to Sydney Trains dispatch.',
        image: createSVGImage('train', '#1e3a8a', 'PLATFORM 2\nMartin Place\nNext: T4 Bondi Junction (3 min)\n[Opal Card Tap Ready]')
    },
    'aud-note': {
        title: 'Australian $20 Banknote',
        summary: 'Australian 20-dollar banknote featuring Mary Reibey. Distinctive red-orange polymer note with clear window and tactile dots.',
        detail: 'Clear top-to-bottom window displays the compass motif and rolling colour effect. Note is crisp and intact.',
        uncertainty: 'On-device tactile verification advised for denomination certainty. Never rely on visual check for currency counterfeits.',
        image: createSVGImage('money', '#991b1b', 'AUSTRALIA $20\nMary Reibey\n[Tactile Dots ::]\n[Clear Window]')
    },
    'gauge-reader': {
        title: 'Analog & Digital Gauge Reader',
        summary: 'Analog pressure gauge reads 4.2 bar within standard operational limits. Calibration inspection tag verified through November 2026.',
        detail: 'Needle indicator is resting securely in the upper green zone. No pneumatic hiss, fluid accumulation, or gasket wear visible.',
        uncertainty: 'Verification tool only. Follow facility Work Health & Safety (WHS) protocols and verify critical readings with physical instruments.',
        image: createSVGImage('gauge', '#065f46', 'PRESSURE GAUGE\n4.2 BAR (NORMAL)\n[Range: 0 - 6 BAR]\nSafety Tag #AU-8832')
    },
    'ppe-audit': {
        title: 'Workplace PPE & Safety Audit',
        summary: 'PPE compliance check: 1 worker in view wearing class 2 high-visibility safety vest and compliant hard hat.',
        detail: 'Safety glasses and steel-capped boots observed. Emergency fire exit path to the right is unobstructed with zero trip hazards.',
        uncertainty: 'Assistive audit only. Does not replace mandated site Work Health and Safety (WHS) officer walk-through.',
        image: createSVGImage('ppe', '#d97706', 'WHS PPE AUDIT\nHigh-Vis: Compliant\nHard Hat: Verified\nExit Path: Clear')
    },
    'cafe-menu': {
        title: 'Printed Sydney Cafe Menu (Offline OCR)',
        summary: 'Menu items detected in reading order: Flat White $4.50, Long Black $4.20, Almond Croissant $6.00, Sourdough Toast $5.50.',
        detail: 'Extracted 100% on-device via Apple Vision OCR. Cheapest item is Long Black at $4.20. Soy and Oat milk available for $0.70.',
        uncertainty: 'Processed entirely on-device on Apple Neural Engine. No network connection required.',
        image: createSVGImage('menu', '#374151', 'SYDNEY HARBOUR CAFE\nFlat White ... $4.50\nLong Black ... $4.20\nAlmond Croissant ... $6.00\nSourdough Toast ... $5.50')
    },
    'asset-tag': {
        title: 'Equipment Serial & Asset Tag',
        summary: 'Machinery tag: Caterpillar Cat-X300 Hydraulic Pump. Serial Number: SN-77291-B. Voltage: 415V Three-Phase.',
        detail: 'Next scheduled maintenance due: 15 December 2026. Asset barcode #9312345678902 is clean and readable.',
        uncertainty: 'Alphanumeric values extracted with high OCR confidence. Confirm with maintenance ledger.',
        image: createSVGImage('tag', '#1f2937', 'CATERPILLAR CAT-X300\nS/N: 77291-B\nVoltage: 415V 3-Phase\nBarcode: 9312345678902')
    },
    'logistics-manifest': {
        title: 'Shipping Manifest & Cargo Audit',
        summary: 'Bill of Lading #BOL-2026-SYD: 14 pallets heavy machinery spare parts consigned to Martin Place Engineering.',
        detail: 'Carrier: Toll Priority Australia. Gross weight: 1,840 kg. All tamper-evident security seals verified intact.',
        uncertainty: 'Text extracted from printed bill of lading. Verify physical seal numbers against packing list.',
        image: createSVGImage('manifest', '#1e293b', 'BILL OF LADING\nBOL-2026-SYD\nConsignee: Martin Place Eng\n14 Pallets | 1,840 kg')
    }
};

// Helper to generate dynamic SVG images as data URLs
function createSVGImage(type, bgColor, text) {
    const lines = text.split('\n');
    const svgLines = lines.map((l, i) => `<text x="50%" y="${60 + i * 26}" font-size="${i === 0 ? 16 : 13}" font-weight="${i === 0 ? 'bold' : 'normal'}" fill="#ffffff" text-anchor="middle" font-family="-apple-system, sans-serif">${l}</text>`).join('');
    
    const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="360" height="200" viewBox="0 0 360 200">
        <rect width="360" height="200" rx="14" fill="${bgColor}"/>
        <rect x="8" y="8" width="344" height="184" rx="10" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="2" stroke-dasharray="6,6"/>
        ${svgLines}
    </svg>`;
    return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
}

// Mode Switching
function switchMode(mode) {
    currentMode = mode;
    const btnComm = document.getElementById('btnModeCommunity');
    const btnEnt = document.getElementById('btnModeEnterprise');
    const commActions = document.getElementById('communityActions');
    const entActions = document.getElementById('enterpriseActions');
    const subtitle = document.getElementById('appSubtitle');

    if (mode === 'enterprise') {
        btnComm.classList.remove('active');
        btnEnt.classList.add('active');
        commActions.style.display = 'none';
        entActions.style.display = 'flex';
        subtitle.textContent = 'Sovereign Industrial Vision & Safety Audit.';
        speak('Switched to Enterprise Inspection mode.');
    } else {
        btnEnt.classList.remove('active');
        btnComm.classList.add('active');
        entActions.style.display = 'none';
        commActions.style.display = 'flex';
        subtitle.textContent = 'See the world through sound.';
        speak('Switched to Community Assistive mode.');
    }
}

// Run Preset Scenario
function runPreset(presetKey) {
    const data = PRESETS[presetKey];
    if (!data) return;

    // Show on dynamic island
    setIsland('Analyzing…', '#f59e0b');

    // Populate result card
    const card = document.getElementById('resultCard');
    const img = document.getElementById('resultImage');
    const summary = document.getElementById('resultSummary');
    const detail = document.getElementById('resultDetail');
    const unc = document.getElementById('uncertaintyText');

    img.src = data.image;
    summary.textContent = data.summary;
    detail.textContent = data.detail;
    unc.textContent = data.uncertainty;

    card.style.display = 'flex';
    card.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

    // Speak response
    const fullSpeech = `${data.summary} ${data.detail}`;
    lastSpokenText = fullSpeech;
    speak(fullSpeech);

    setTimeout(() => {
        setIsland(isOffline ? 'Offline AI' : 'SCX Verified', '#10b981');
    }, 1200);
}

// Toggle Airplane / Offline Mode
function toggleOfflineMode() {
    isOffline = !isOffline;
    const netEl = document.getElementById('statusNetwork');
    const dotEl = document.getElementById('statusDot');
    const badgeEl = document.getElementById('statusBadge');
    const descEl = document.getElementById('statusDesc');
    const wifiEl = document.getElementById('wifiIcon');
    const btnEl = document.getElementById('btnToggleOffline');

    if (isOffline) {
        netEl.textContent = 'Offline (Airplane Mode)';
        dotEl.style.background = '#4ade80';
        badgeEl.textContent = 'Apple Neural Engine';
        badgeEl.style.color = '#4ade80';
        badgeEl.style.background = 'rgba(74, 222, 128, 0.15)';
        descEl.textContent = 'Running 100% offline via Apple Neural Engine. No photos leave this device.';
        wifiEl.textContent = '✈️';
        btnEl.innerHTML = '<span>📶 Turn On Online Mode</span>';
        setIsland('Airplane Mode', '#94a3b8');
        speak('Airplane mode enabled. Running 100 percent offline on Apple Neural Engine.');
    } else {
        netEl.textContent = 'Online';
        dotEl.style.background = '#10b981';
        badgeEl.textContent = 'SCX Sydney';
        badgeEl.style.color = '#60a5fa';
        badgeEl.style.background = 'rgba(96, 165, 250, 0.1)';
        descEl.textContent = 'Australian Sovereign Inference via SCX (Sydney). 100% onshore data residency.';
        wifiEl.textContent = '📶';
        btnEl.innerHTML = '<span>✈️ Toggle Airplane Mode</span>';
        setIsland('Online SCX', '#10b981');
        speak('Online mode restored. Connected to SCX Sovereign AI cloud.');
    }
}

// Provider & Voice Updates
function updateProvider() {
    currentProvider = document.getElementById('providerSelect').value;
    const badge = document.getElementById('statusBadge');
    if (currentProvider === 'scx') {
        badge.textContent = 'SCX Sydney';
        speak('Active vision provider set to SCX Sovereign AI Sydney.');
    } else if (currentProvider === 'ondevice') {
        badge.textContent = 'Apple Neural Engine';
        speak('Active vision provider set to Apple On-Device Neural Engine.');
    } else {
        badge.textContent = 'Claude Vision';
        speak('Active vision provider set to Anthropic Claude Vision.');
    }
}

function updateVoice() {
    currentVoice = document.getElementById('voiceSelect').value;
    speak(`Voice updated to ElevenLabs ${currentVoice}.`);
}

function testVoiceAudio() {
    const text = `G'day! This is SeeForMe AI running on Apple platforms, with ElevenLabs voice narration.`;
    lastSpokenText = text;
    speak(text);
}

// Dynamic Island updates
function setIsland(text, color) {
    const island = document.getElementById('islandStatus');
    if (island) {
        island.textContent = text;
        island.style.color = color || '#94a3b8';
    }
}

// Speech Synthesis with Waveform Animation
function speak(text) {
    if (!('speechSynthesis' in window)) return;

    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 1.0;

    // Try finding matching native browser voice
    const voices = window.speechSynthesis.getVoices();
    if (currentVoice === 'rachel' || currentVoice === 'bella') {
        const female = voices.find(v => v.name.includes('Samantha') || v.name.includes('Karen') || v.name.includes('Victoria') || v.name.includes('Female'));
        if (female) utterance.voice = female;
    } else {
        const male = voices.find(v => v.name.includes('Daniel') || v.name.includes('Alex') || v.name.includes('Male'));
        if (male) utterance.voice = male;
    }

    const speakingBar = document.getElementById('speakingBar');
    if (speakingBar) speakingBar.style.display = 'flex';

    utterance.onend = () => {
        if (speakingBar) speakingBar.style.display = 'none';
        setIsland('Ready', '#94a3b8');
    };

    utterance.onerror = () => {
        if (speakingBar) speakingBar.style.display = 'none';
    };

    window.speechSynthesis.speak(utterance);
}

function stopSpeech() {
    if ('speechSynthesis' in window) {
        window.speechSynthesis.cancel();
    }
    const speakingBar = document.getElementById('speakingBar');
    if (speakingBar) speakingBar.style.display = 'none';
    setIsland('Stopped', '#ef4444');
}

function repeatSpeech() {
    if (lastSpokenText) {
        speak(lastSpokenText);
    }
}

// Voice Question Simulation
function startVoiceQuestion() {
    setIsland('Listening…', '#f59e0b');
    const promptQ = prompt('Ask a question by voice (or type your question):', 'What is the cheapest item?');
    if (promptQ) {
        setIsland('Thinking…', '#60a5fa');
        setTimeout(() => {
            const answer = `Regarding '${promptQ}': The cheapest item visible on the menu is the Long Black for four dollars and twenty cents.`;
            lastSpokenText = answer;
            document.getElementById('resultSummary').textContent = answer;
            document.getElementById('resultDetail').textContent = 'Extracted from on-device text OCR.';
            document.getElementById('resultCard').style.display = 'flex';
            speak(answer);
        }, 800);
    } else {
        setIsland('Ready', '#94a3b8');
    }
}

// Custom Image Upload Handling
function triggerCustomUpload() {
    document.getElementById('customFileInput').click();
}

function handleCustomFile(e) {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = function(evt) {
        setIsland('Analyzing…', '#f59e0b');
        const card = document.getElementById('resultCard');
        const img = document.getElementById('resultImage');
        const summary = document.getElementById('resultSummary');
        const detail = document.getElementById('resultDetail');
        const unc = document.getElementById('uncertaintyText');

        img.src = evt.target.result;
        summary.textContent = `Custom image analysis: ${file.name.replace(/\.[^/.]+$/, '')} successfully processed.`;
        detail.textContent = `Identified key structural features and visible labels using ${currentProvider === 'scx' ? 'SCX Sovereign AI' : 'Apple Neural Engine'}.`;
        unc.textContent = 'Custom image verification. Lighting and angle may affect accuracy.';

        card.style.display = 'flex';
        card.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

        const spoken = `${summary.textContent} ${detail.textContent}`;
        lastSpokenText = spoken;
        speak(spoken);
        setIsland('Ready', '#10b981');
    };
    reader.readAsDataURL(file);
}

// Initial announcement on load
window.addEventListener('load', () => {
    setTimeout(() => {
        speak('SeeForMe AI simulator ready. Select Community Impact or Enterprise Inspection.');
    }, 500);
});
