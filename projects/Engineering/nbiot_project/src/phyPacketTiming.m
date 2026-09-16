function [txTimeSec, latencyMs, rateBps, details] = phyPacketTiming(cfg, modulation, packetSizeBytes, repetition, ttiMs)
%PHYPACKETTIMING Estimate packet TX time and latency using a simplified PHY model.

arguments
    cfg struct
    modulation (1,1) string
    packetSizeBytes (1,1) double
    repetition (1,1) double
    ttiMs (1,1) double
end

% Bits per symbol
switch upper(modulation)
    case "BPSK"
        bitsPerSym = 1;
    case "QPSK"
        bitsPerSym = 2;
    otherwise
        bitsPerSym = 1;
end

subframes = max(ttiMs, 1); % 1 ms subframe base
bitsPerSubframe = cfg.phy.subcarriers * cfg.phy.symbolsPerSubframe * bitsPerSym * cfg.phy.codeRate;
bitsPerTTI = bitsPerSubframe * subframes;

rateBps = bitsPerTTI / (ttiMs/1000);
packetBits = packetSizeBytes * 8;

baseTxTime = packetBits / max(rateBps, 1);

% Effective transmission time with repetitions
txTimeSec = baseTxTime * repetition;
latencyMs = max(ttiMs, baseTxTime*1000) * repetition;

if nargout > 3
    details = struct();
    details.bitsPerSubframe = bitsPerSubframe;
    details.bitsPerTTI = bitsPerTTI;
    details.packetBits = packetBits;
end
end
