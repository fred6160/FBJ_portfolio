function [snrDb, details] = pathLossSNR(cfg, envType)
%PATHLOSSSNR Compute received SNR for a 3GPP TR 45.820 NB-IoT scenario.
%
%   Uses the log-distance path-loss model with environment-specific
%   exponent, log-normal shadowing, and (for deep-indoor) extra building
%   penetration loss. The link-budget components are:
%
%       SNR(dB) = P_tx - L_pl(d) - L_pen - NF - N0 + X_sigma
%
%   where L_pl(d) = L_pl(d0) + 10 n log10(d/d0), L_pen is the building
%   penetration loss (deep-indoor), NF is receiver noise figure, N0 the
%   thermal noise floor over the NB-IoT 180 kHz bandwidth, and
%   X_sigma ~ N(0, sigma^2) is shadowing.
%
%   Coverage classes follow TR 45.820 Section 6.1:
%       urban       : MCL = 144 dB (normal)
%       rural       : MCL = 154 dB (robust)
%       deep_indoor : MCL = 164 dB (extreme)
%
%   This function is unchanged from the version you were handed -- it
%   was already producing physically sensible SNR values (roughly -5 to
%   -20 dB for the default urban config). See channelSnapshot.m for the
%   fix that restores scenario differentiation when the Markov
%   fluctuation layer is enabled.

arguments
    cfg struct
    envType (1,1) string
end

scenario = getScenarioParams(cfg, envType);

% Reference path loss at d0 = 1 m using Friis free-space
fc      = cfg.channel.fcHz;
lambda  = physconst('LightSpeed') / fc;
pl1mDb  = 20*log10(4*pi/lambda);

% Log-distance path loss
d           = max(scenario.distanceMeters, 1);
pathLossDb  = pl1mDb + 10*scenario.pathLossExp*log10(d);

% Shadowing and penetration
shadowDb       = scenario.shadowingStdDb * randn();
penetrationDb  = scenario.penetrationDb;

% Thermal noise over NB-IoT bandwidth
kB           = physconst('Boltzmann');
T            = 290;                              % K
noisePowerW  = kB * T * cfg.channel.bandwidthHz;
noisePowerDbm = 10*log10(noisePowerW/1e-3);

snrDb = cfg.channel.txPowerdBm ...
        - pathLossDb ...
        - penetrationDb ...
        - cfg.channel.noiseFiguredB ...
        - noisePowerDbm ...
        - shadowDb;

if nargout > 1
    details = struct();
    details.pathLossDb     = pathLossDb;
    details.penetrationDb  = penetrationDb;
    details.shadowDb       = shadowDb;
    details.noisePowerDbm  = noisePowerDbm;
    details.pathLossExp    = scenario.pathLossExp;
    details.shadowStd      = scenario.shadowingStdDb;
    details.mclDb          = scenario.mclDb;
    details.fadingModel    = scenario.fadingModel;
end
end

function s = getScenarioParams(cfg, envType)
% Return scenario struct, falling back to channel defaults if unknown.
key = char(envType);
if isfield(cfg.env, key)
    s = cfg.env.(key);
else
    s = struct('pathLossExp',    cfg.channel.pathLossExp, ...
               'shadowingStdDb', cfg.channel.shadowingStdDb, ...
               'penetrationDb',  0, ...
               'mclDb',          144, ...
               'distanceMeters', cfg.channel.distanceMeters, ...
               'fadingModel',    "rayleigh");
end
end
