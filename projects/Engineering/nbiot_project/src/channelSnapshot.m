function [snrDb, state] = channelSnapshot(cfg, envType, prevMarkovStateIdx)
%CHANNELSNAPSHOT Generate one SNR sample for a 3GPP TR 45.820 scenario.
%   Combines a scenario-specific deterministic mean SNR (from the
%   log-distance path-loss link budget) with a Markov-correlated
%   fluctuation layer and a small-scale fading multiplier whose
%   distribution depends on the scenario:
%       urban / deep_indoor : Rayleigh
%       rural               : Rician (K = 6 dB)
%
%   Returns the SNR in dB and a state struct used to seed the next call.
%
%   *** BUG FIX (audit finding) ***
%   The original implementation branched entirely on
%   cfg.channel.useMarkov: when true (the default), it called
%   markovSNR(cfg, prevMarkovStateIdx) -- WITHOUT passing envType -- and
%   used that value as the *absolute* SNR. Since markovSNR only knows
%   about a single scenario-agnostic 6-level state list
%   (cfg.channel.markovStatesDb), this meant urban, rural, and
%   deep_indoor scenarios drew SNR from an IDENTICAL distribution
%   whenever useMarkov=true -- silently discarding all the per-scenario
%   physics defined in cfg.env.urban/.rural/.deep_indoor (path-loss
%   exponent, penetration loss, MCL target). Given useMarkov defaults to
%   true, this meant the three-scenario comparison that is the whole
%   point of the TR 45.820 study design was not actually happening.
%
%   FIX: pathLossSNR() is now ALWAYS called first to get the correct
%   scenario-specific deterministic mean SNR. The Markov chain is kept
%   only as a small, zero-mean, temporally-correlated FLUCTUATION added
%   on top of that mean (not as the absolute SNR). This preserves both
%   the intended slow temporal correlation AND proper urban/rural/deep-
%   indoor differentiation.

arguments
    cfg struct
    envType (1,1) string
    prevMarkovStateIdx (1,1) double {mustBeInteger, mustBePositive} = 1
end

% Scenario-specific deterministic mean SNR (path loss + shadowing draw).
% This ALWAYS reflects urban/rural/deep_indoor differences.
[baseSnrDb, details] = pathLossSNR(cfg, envType);

useMarkov = isfield(cfg, 'channel') && ...
            isfield(cfg.channel, 'useMarkov') && ...
            cfg.channel.useMarkov;

if useMarkov
    [fluctRaw, nextStateIdx, transition] = markovSNR(cfg, prevMarkovStateIdx);
    % markovStatesDb is not itself zero-mean, so re-centre the sampled
    % value before treating it as a fluctuation around the physical
    % link-budget mean computed above.
    fluctDb = fluctRaw - mean(cfg.channel.markovStatesDb);
    snrDb = baseSnrDb + fluctDb;
    details.markovStateIdx   = nextStateIdx;
    details.markovTransition = transition;
else
    snrDb = baseSnrDb;
    details.markovStateIdx = prevMarkovStateIdx;
end

% Resolve fading model from scenario, with fallback to legacy switch
fadingModel = resolveFadingModel(cfg, envType);

switch lower(string(fadingModel))
    case "rician"
        K = 6;                          % K-factor in dB
        KLin   = 10^(K/10);
        s      = sqrt(KLin/(KLin+1));
        sigma  = sqrt(1/(2*(KLin+1)));
        fadingLin = sqrt((s + sigma*randn())^2 + (sigma*randn())^2);
    case "rayleigh"
        fadingLin = raylrnd(1/sqrt(2));
    otherwise
        fadingLin = 1;
end

snrDb = snrDb + 20*log10(max(fadingLin, 1e-6));

state              = details;
state.fadingLin    = fadingLin;
state.envType      = envType;
end

function fm = resolveFadingModel(cfg, envType)
key = char(envType);
if isfield(cfg.env, key) && isfield(cfg.env.(key), 'fadingModel')
    fm = cfg.env.(key).fadingModel;
else
    switch lower(string(envType))
        case "rural",       fm = "rician";
        otherwise,          fm = "rayleigh";
    end
end
end
