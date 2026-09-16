function [txTimeSec, latencyMs, tbs, details] = phyPacketTimingLTE(cfg, modulation, packetSizeBytes, repetition, ttiMs)
%PHYPACKETTIMINGLTE Estimate packet TX time using LTE Toolbox for NPUSCH.
%   NOTE: this path requires the (separately licensed) LTE Toolbox
%   function lteNPUSCHIndices and is only exercised when
%   cfg.phy.useLTEModel = true (default: false). If that toolbox is not
%   installed, leave useLTEModel false -- phyPacketTiming.m (the
%   simplified model) is used everywhere by default and does not need
%   it.

arguments
    cfg struct
    modulation (1,1) string
    packetSizeBytes (1,1) double
    repetition (1,1) double
    ttiMs (1,1) double
end

% NPUSCH configuration for NB-IoT
npusch = struct();
npusch.NBundled = packetSizeBytes * 8; % Transport block size in bits
npusch.NRep = repetition;
npusch.ISF = 0; % No subframe offset
npusch.NULSlots = 1; % Number of slots
npusch.NBULSubcarrierSet15kHz = 0:11; % Default subcarrier set for one RU

% Modulation to MCS mapping (simplified)
if strcmpi(modulation, 'QPSK')
    npusch.IMCS = 4; % Approx QPSK
else
    npusch.IMCS = 2; % Approx BPSK
end

% Determine number of resource units (RU) required
% This is an iterative process to find the smallest N_RU that fits the TBS
possibleNRU = [1, 2, 3, 4, 5, 6, 8, 10];
tbs = 0;
% Clear any previous subcarrier set field to avoid conflicts
if isfield(npusch, 'NBULSubcarrierSet15kHz')
    npusch = rmfield(npusch, 'NBULSubcarrierSet15kHz');
end

for nru = possibleNRU
    npusch.NRU = nru;

    % Dynamically set the subcarrier set based on NRU
    subcarrierIndices = 0:(12*nru - 1);
    if nru == 1
        npusch.NBULSubcarrierSet15kHz = subcarrierIndices;
    else
        if isfield(npusch, 'NBULSubcarrierSet15kHz')
             npusch = rmfield(npusch, 'NBULSubcarrierSet15kHz');
        end
        npusch.NBULSubcarrierSet = subcarrierIndices;
    end

    % Get NPUSCH info, including the transport block size for this config
    [~, info] = lteNPUSCHIndices(cfg.enb, npusch);
    if info.G >= npusch.NBundled
        tbs = info.G;
        break;
    end
end

if tbs == 0
    % TBS is too large for any RU configuration, indicates failure
    txTimeSec = inf;
    latencyMs = inf;
    details = struct('error', 'TBS too large');
    return;
end

% Calculate timing
subframesPerRep = info.NSF;
totalSubframes = subframesPerRep * npusch.NRep;
txTimeSec = totalSubframes / 1000; % Each subframe is 1ms

% Latency is a function of TTI and total transmission time
latencyMs = max(ttiMs, txTimeSec * 1000);

if nargout > 3
    details = struct();
    details.tbs = tbs;
    details.modulation = modulation;
    details.resourceUnits = npusch.NRU;
    details.subframesPerRep = subframesPerRep;
    details.totalSubframes = totalSubframes;
end
end
