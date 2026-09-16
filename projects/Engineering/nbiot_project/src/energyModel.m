function [energyJ, details] = energyModel(cfg, packetSizeBytes, repetition, bler, modulation, ttiMs)
%ENERGYMODEL Energy per successfully-delivered packet plus throughput.
%
%   Computes the expected energy spent per *successful* packet, accounting
%   for transmit, receive, processing, and retransmission overhead. Also
%   returns throughput and the per-packet latency that downstream
%   evaluation needs:
%
%       E_total  = (E_tx + E_rx + E_proc) / (1 - BLER)
%       Tp       = (L * 8 * (1 - BLER)) / (latency_s)
%
%   where L is packet size in bytes and latency_s is the wall-clock time
%   for one transmission attempt (including all repetitions).
%
%   *** BUG FIX (audit finding) ***
%   The original clamp was `successProb = max(1 - bler, 1e-3)`. At the
%   low-SNR / high-repetition-penalty operating points that show up
%   constantly in this project's scenarios, BLER regularly sits near 1,
%   so this clamp let energyJ = Esum/successProb inflate by up to ~1000x
%   a single attempt's energy -- producing per-packet energy values in
%   the thousands of Joules, i.e. more energy than the ENTIRE device
%   battery budget (cfg.energy.batteryJ = 5400 J) for one packet. That
%   is exactly the pattern visible in the "Energy vs Packet Size"
%   boxplot you have from the previous run (outliers up to ~6000 J).
%
%   FIX: (1) loosen the floor to 5e-2 (still a strong penalty on
%   unreliable configs, but caps the blow-up at ~20x instead of ~1000x),
%   and (2) hard-cap the final energyJ at cfg.energy.maxEnergyPerPacketJ
%   (defaults to the full battery budget) so a single packet-level
%   estimate can never exceed what the device physically has available.
%   Both constants are configurable in getDefaultConfig.m.

arguments
    cfg              struct
    packetSizeBytes  (1,1) double
    repetition       (1,1) double
    bler             (1,1) double
    modulation       (1,1) string = "QPSK"
    ttiMs            (1,1) double = 1
end

% PHY timing
if isfield(cfg.phy, 'useLTEModel') && cfg.phy.useLTEModel
    [txTime, latencyMs, ~, timingDetails] = phyPacketTimingLTE(cfg, modulation, packetSizeBytes, repetition, ttiMs);
    rateBps = packetSizeBytes*8 / max(txTime, eps);
else
    [txTime, latencyMs, rateBps, timingDetails] = phyPacketTiming(cfg, modulation, packetSizeBytes, repetition, ttiMs);
end

rxTime   = txTime * 0.1;   % ACK + control overhead
procTime = 0.05;            % s

Etx   = cfg.energy.txPowerW   * txTime;            % repetition already in txTime
Erx   = cfg.energy.rxPowerW   * rxTime;
Eproc = cfg.energy.procPowerW * procTime;
Esum  = Etx + Erx + Eproc;

% FIX: floor loosened from 1e-3 to 5e-2 -- see header note.
successProb = max(1 - bler, 5e-2);

energyJ = Esum / successProb;             % expected energy / success

% FIX: hard cap so a single packet-level estimate can never exceed the
% configured device battery budget (a modeling sanity bound, not a
% physical retransmission-count limit).
if isfield(cfg, 'energy') && isfield(cfg.energy, 'maxEnergyPerPacketJ')
    energyJ = min(energyJ, cfg.energy.maxEnergyPerPacketJ);
end

throughputBps    = (packetSizeBytes * 8 * successProb) / max(latencyMs/1000, eps);
packetDropProb   = bler;

if nargout > 1
    details = struct();
    details.txTime          = txTime;
    details.rxTime          = rxTime;
    details.procTime        = procTime;
    details.energyAttemptJ  = Esum;                % energy of one attempt (no retx)
    details.energyPerSuccessJ = energyJ;
    details.successProb     = successProb;
    details.packetDropProb  = packetDropProb;
    details.latencyMs       = latencyMs;
    details.throughputBps   = throughputBps;
    details.rateBps         = rateBps;
    details.timingDetails   = timingDetails;
end
end
