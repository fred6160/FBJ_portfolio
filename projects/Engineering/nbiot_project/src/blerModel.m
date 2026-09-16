function bler = blerModel(snrDb, modulation, packetSizeBytes, repetition, cfg)
%BLERMODEL Block-error rate for NB-IoT NPUSCH using a link-quality model.
%
%   Following the standard NB-IoT BLER abstraction (see Lauridsen 2017,
%   Azari 2018, Andres-Maldonado 2018), we approximate the operating
%   point of a turbo-coded NPUSCH block as a logistic function of the
%   *effective* SNR:
%
%       SNR_eff = SNR + G_rep * log2(R) - L_pkt(L) - L_mod(m)
%
%       BLER    = 1 / (1 + exp((SNR_eff - SNR_th) / sigma))
%
%   where G_rep is the per-doubling coding gain (~1.5 dB), L_pkt and
%   L_mod are penalty terms that grow with packet length and modulation
%   order, SNR_th is the waterfall midpoint (~-7 dB for QPSK r=0.5), and
%   sigma sets the waterfall slope (~2 dB).
%
%   This replaces an older AWGN BER^L^R formulation, which saturated to
%   BLER = 1 for large packets at low SNR regardless of repetition. That
%   older formulation is what generated the BLER-vs-SNR figure you have
%   from the previous experiment -- this model is the fix.

arguments
    snrDb            (1,1) double
    modulation       (1,1) string
    packetSizeBytes  (1,1) double
    repetition       (1,1) double
    cfg              struct = struct()
end

% Modulation penalty: 1 dB per extra bit/symbol over BPSK reference
switch upper(modulation)
    case "BPSK"
        modLossDb = 0;
    case "QPSK"
        modLossDb = 1;
    otherwise
        modLossDb = 0;
end

% Coding gain per doubling of repetitions (NB-IoT NPUSCH typical ~1.5 dB)
if isfield(cfg, 'phy') && isfield(cfg.phy, 'codingGainDbPerDoubling')
    Grep = cfg.phy.codingGainDbPerDoubling;
else
    Grep = 1.5;
end
repGainDb = Grep * log2(max(repetition, 1));

% Packet-length penalty: longer transport blocks need higher SNR for the
% same BLER (3 dB per 4x increase from a 40-byte reference).
pktLossDb = 3 * log2(max(packetSizeBytes, 1) / 40);
pktLossDb = max(pktLossDb, 0);

% Waterfall parameters (QPSK r=1/2 reference, calibrated to TR 45.820)
SNR_th_dB = -7;
sigma_dB  = 2;

snrEffDb = snrDb + repGainDb - pktLossDb - modLossDb;

% Logistic waterfall
bler = 1 / (1 + exp((snrEffDb - SNR_th_dB) / sigma_dB));

% Clamp to a meaningful range (avoid 0/1 singularities downstream)
bler = min(max(bler, 1e-6), 1 - 1e-6);
end
