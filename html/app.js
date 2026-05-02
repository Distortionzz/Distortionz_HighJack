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
            payoutValue.textContent  = data.payout ? `$${Number(data.payout).toLocaleString()}` : '$0';
        }

        if (action === 'update') {
            if (data.stage)        applyStage(data.stage);
            if (data.tier)         applyTier(data.tier);
            if (typeof data.secondsLeft === 'number') applyTimer(data.secondsLeft);
            if (data.vehicle)      vehicleName.textContent  = data.vehicle;
            if (data.color)        vehicleColor.textContent = data.color;
            if (data.plate)        vehiclePlate.textContent = data.plate;
            if (typeof data.payout === 'number') payoutValue.textContent = `$${data.payout.toLocaleString()}`;
        }

        if (action === 'hide') {
            panel.classList.add('hidden');
        }
    });
})();
