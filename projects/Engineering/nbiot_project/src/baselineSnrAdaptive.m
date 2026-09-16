function action = baselineSnrAdaptive(state, cfg)
%BASELINESNRADAPTIVE SNR-threshold lookup heuristic (Adaptive SNR-based).
%   Implements the classical channel-quality-indicator (CQI) style mapping
%   used as a baseline in NB-IoT optimisation studies (e.g. Azari 2018,
%   Al-Sammak 2025): coarse SNR bins are mapped to a packet/repetition/
%   modulation tuple that minimises the configured energy whilst keeping
%   the predicted BLER below 10%.
%
%   STATE must contain field .SNRdB (current channel quality).

arguments
    state struct
    cfg   struct
end

snrDb = state.SNRdB;

if snrDb >= 5
    packet = 320; rep =  1; mod = "QPSK"; tti = 1;
elseif snrDb >= 0
    packet = 160; rep =  2; mod = "QPSK"; tti = 2;
elseif snrDb >= -5
    packet =  80; rep =  4; mod = "QPSK"; tti = 4;
elseif snrDb >= -10
    packet =  40; rep =  8; mod = "BPSK"; tti = 8;
elseif snrDb >= -15
    packet =  20; rep = 16; mod = "BPSK"; tti = 8;
else
    packet =  20; rep = 32; mod = "BPSK"; tti = 16;
end

% Snap to configured action grid (defensive -- keeps the heuristic legal).
packet = snap(packet, cfg.phy.packetSizesBytes);
rep    = snap(rep,    cfg.phy.repetitionFactors);
tti    = snap(tti,    cfg.mac.ttiMs);

action = struct('packet', packet, 'rep', rep, 'mod', mod, 'tti', tti, ...
                'name', "SNRAdaptive");
end

function v = snap(v, grid)
[~, k] = min(abs(grid - v));
v = grid(k);
end
