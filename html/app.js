(function () {
    const panel       = document.getElementById('hijackPanel');
    const timer       = document.getElementById('contractTimer');
    const stagePill   = document.getElementById('stagePill');
    const stageIcon   = document.getElementById('stageIcon');
    const stageLabel  = document.getElementById('stageLabel');
    const stageHint   = document.getElementById('stageHint');
    const vehicleName = document.getElementById('vehicleName');
    const vehicleColor = document.getElementById('vehicleColor');
    const vehiclePlate = document.getElementById('vehiclePlate');
    const tierPill    = document.getElementById('tierPill');
    const payoutValue = document.getElementById('payoutValue');

    // v1.1.0 — health + penalty UI
    const healthBlock  = document.getElementById('healthBlock');
    const engineFill   = document.getElementById('engineFill');
    const enginePct    = document.getElementById('enginePct');
    const bodyFill     = document.getElementById('bodyFill');
    const bodyPct      = document.getElementById('bodyPct');
    const penaltyValue = document.getElementById('penaltyValue');

    let basePayout    = 0;  // remembered so we can re-render reward = base - penalty
    let currentPenalty = 0; // v1.1.1 — single source of truth, prevents 1Hz/500ms flicker

    // v1.1.1 — central renderer, called from both 'update' and 'health' events
    function renderPayout() {
        const live = Math.max(0, basePayout - currentPenalty);
        payoutValue.textContent = '$' + live.toLocaleString();
    }

    const STAGE_MAP = {
        searching: { icon: '⌖', label: 'SEARCHING',     hint: 'Search the marked zone' },
        found:     { icon: '◉', label: 'TARGET FOUND',  hint: 'Steal the vehicle' },
        driving:   { icon: '➤', label: 'IN POSSESSION', hint: 'Drive to the drop-off' },
    };

    function formatTime(seconds) {
        if (seconds < 0) seconds = 0;
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    }

    function applyStage(stage) {
        const info = STAGE_MAP[stage] || STAGE_MAP.searching;
        stagePill.classList.remove('searching', 'found', 'driving');
        stagePill.classList.add(stage in STAGE_MAP ? stage : 'searching');
        stageIcon.textContent = info.icon;
        stageLabel.textContent = info.label;
        stageHint.textContent = info.hint;
    }

    function applyTier(tier) {
        const t = (tier || 'common').toLowerCase();
        tierPill.classList.remove('common', 'mid', 'rare', 'premium');
        tierPill.classList.add(t);
        tierPill.textContent = t.toUpperCase();
    }

    function applyTimer(secondsLeft) {
        timer.textContent = formatTime(secondsLeft);
        timer.classList.remove('warning', 'critical');
        if (secondsLeft <= 60)       timer.classList.add('critical');
        else if (secondsLeft <= 180) timer.classList.add('warning');
    }

    // v1.1.0 — health bar updater. Accepts 0-100 percentage.
    function applyHealthBar(fillEl, pctEl, pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)));
        fillEl.style.width = clamped + '%';
        pctEl.textContent = clamped + '%';
        fillEl.classList.remove('warn', 'crit');
        if (clamped <= 25)      fillEl.classList.add('crit');
        else if (clamped <= 60) fillEl.classList.add('warn');
    }

    function applyHealth(data) {
        if (typeof data.enginePct === 'number') applyHealthBar(engineFill, enginePct, data.enginePct);
        if (typeof data.bodyPct   === 'number') applyHealthBar(bodyFill,   bodyPct,   data.bodyPct);

        if (typeof data.penalty === 'number') {
            currentPenalty = Math.max(0, Math.round(data.penalty));
            penaltyValue.textContent = '-$' + currentPenalty.toLocaleString();
            penaltyValue.classList.toggle('zero', currentPenalty === 0);
            renderPayout();  // single source of truth
        }

        // Show the block once we have any data; hide it during searching stage
        if (data.show === true)  healthBlock.classList.remove('hidden');
        if (data.show === false) healthBlock.classList.add('hidden');
    }

    window.addEventListener('message', function (event) {
        const data = event.data || {};
        const action = data.action;

        if (action === 'show') {
            panel.classList.remove('hidden');
            applyStage(data.stage || 'searching');
            applyTier(data.tier || 'common');
            applyTimer(typeof data.secondsLeft === 'number' ? data.secondsLeft : 0);
            vehicleName.textContent  = data.vehicle || '—';
            vehicleColor.textContent = data.color || '—';
            vehiclePlate.textContent = data.plate || '—';
            basePayout = Number(data.payout || 0);
            currentPenalty = 0;        // v1.1.1 — reset on new contract
            renderPayout();
            // Reset health UI on new contract
            applyHealthBar(engineFill, enginePct, 100);
            applyHealthBar(bodyFill,   bodyPct,   100);
            penaltyValue.textContent = '-$0';
            penaltyValue.classList.add('zero');
            healthBlock.classList.add('hidden');  // hidden during searching
        }

        if (action === 'update') {
            if (data.stage)        applyStage(data.stage);
            if (data.tier)         applyTier(data.tier);
            if (typeof data.secondsLeft === 'number') applyTimer(data.secondsLeft);
            if (data.vehicle)      vehicleName.textContent  = data.vehicle;
            if (data.color)        vehicleColor.textContent = data.color;
            if (data.plate)        vehiclePlate.textContent = data.plate;
            if (typeof data.payout === 'number' && data.payout !== basePayout) {
                // v1.1.1 — only refresh base if it actually changed (prevents flicker)
                basePayout = data.payout;
                renderPayout();
            }
        }

        // v1.1.0 — live health/penalty pings from client.lua
        if (action === 'health') {
            applyHealth(data);
        }

        if (action === 'hide') {
            panel.classList.add('hidden');
            healthBlock.classList.add('hidden');
        }
    });
})();
