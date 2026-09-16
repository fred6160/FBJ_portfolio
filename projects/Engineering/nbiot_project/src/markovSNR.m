function [snrDb, nextStateIdx, transition] = markovSNR(cfg, prevStateIdx)
%MARKOVSNR Generate a temporally-correlated SNR sample from a discrete
%   Markov chain. Uses cfg.channel.markovStatesDb and
%   cfg.channel.markovTransition.
%
%   NOTE: as of the channelSnapshot.m fix, the caller treats this
%   output as a FLUCTUATION (re-centred around zero) to be added to a
%   scenario-specific physical mean SNR -- not as an absolute SNR value.
%   This function itself is unchanged; only how its output is
%   interpreted by the caller changed.

arguments
    cfg struct
    prevStateIdx (1,1) double {mustBeInteger, mustBePositive}
end

statesDb = cfg.channel.markovStatesDb(:)';
numStates = numel(statesDb);

transition = cfg.channel.markovTransition;
if isempty(transition)
    transition = buildDefaultMarkovTransition(numStates);
end

if prevStateIdx > numStates
    prevStateIdx = numStates;
end

% Sample next state without Statistics Toolbox
p = transition(prevStateIdx, :);
cdf = cumsum(p);
u = rand();
nextStateIdx = find(u <= cdf, 1, 'first');
if isempty(nextStateIdx)
    nextStateIdx = numStates;
end

% Add small local variation around state mean
snrDb = statesDb(nextStateIdx) + randn()*1.0;
end
