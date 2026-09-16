%GENERATE_DATASET Sweep dataset for channel/config performance mapping.
%   Produces dataset_nb_iot.csv, used by generate_figures.m for the
%   BLER-vs-SNR scatter, SNR-by-scenario boxplots, energy-vs-packet-size,
%   reliability-vs-repetition, and latency-vs-TTI figures (the
%   dataset-driven equivalents of report Figures 4.1 and 4.4-4.7).
%   Independent of RL training; safe to re-run after parameter changes.
%
%   FIX vs. the original script: a single scalar markovStateIdx was
%   previously reused across scenario switches even though each
%   scenario's channel is now anchored to a different physical mean SNR
%   (see src/channelSnapshot.m fix notes). This version keeps one
%   Markov-fluctuation state per scenario so each chain stays internally
%   consistent.

projectRoot = setup_path();
cfg = getDefaultConfig();
rng(cfg.seed);

numSamples = 2000;
rows = zeros(numSamples, 10);
markovStateIdx = ones(1, numel(cfg.env.types));   % one chain per scenario

for i = 1:numSamples
    envIdx = randi(numel(cfg.env.types));
    cfg.env.active = cfg.env.types{envIdx};

    [snrDb, state] = channelSnapshot(cfg, cfg.env.active, markovStateIdx(envIdx));
    if isfield(state, 'markovStateIdx')
        markovStateIdx(envIdx) = state.markovStateIdx;
    end

    packet = cfg.phy.packetSizesBytes(randi(numel(cfg.phy.packetSizesBytes)));
    rep    = cfg.phy.repetitionFactors(randi(numel(cfg.phy.repetitionFactors)));
    modIdx = randi(numel(cfg.phy.modulations));
    mod    = cfg.phy.modulations{modIdx};
    tti    = cfg.mac.ttiMs(randi(numel(cfg.mac.ttiMs)));

    bler = blerModel(snrDb, mod, packet, rep, cfg);
    [energyJ, det] = energyModel(cfg, packet, rep, bler, mod, tti);

    rows(i, :) = [envIdx, snrDb, packet, rep, modIdx, tti, bler, energyJ, ...
                  det.latencyMs, cfg.qos.maxLatencyMs];
end

T = array2table(rows, 'VariableNames', ...
    {'envId', 'snrDb', 'packetBytes', 'repetition', 'modIdx', ...
     'ttiMs', 'bler', 'energyJ', 'latencyMs', 'qosMaxLatency'});

outFile = fullfile(projectRoot, 'dataset_nb_iot.csv');
writetable(T, outFile);
fprintf('Wrote %s (%d samples).\n', outFile, numSamples);
