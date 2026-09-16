% RUN_SIMULATION - Quick smoke test for the NB-IoT channel/BLER/energy
%   models. Runs one channel snapshot + one packet transmission per
%   scenario (urban, rural, deep_indoor) and prints a summary table.
%   Use this to sanity-check that src/ is on the path and every model
%   function is wired together correctly before running the full
%   RUN_ALL pipeline.

setup_path();
cfg = getDefaultConfig();
rng(cfg.seed);

envTypes = cfg.env.types;
results  = struct();

for i = 1:numel(envTypes)
    cfg.env.active = envTypes{i};
    markovStateIdx = 1;

    [snrDb, state] = channelSnapshot(cfg, cfg.env.active, markovStateIdx);
    bler = blerModel(snrDb, "QPSK", 80, 4, cfg);
    [energyJ, energyDetails] = energyModel(cfg, 80, 4, bler, "QPSK", 4);

    results(i).env     = cfg.env.active; %#ok<SAGROW>
    results(i).snrDb   = snrDb;
    results(i).bler    = bler;
    results(i).energyJ = energyJ;
    results(i).details = struct("channel", state, "energy", energyDetails);
end

fprintf('\n--- RUN_SIMULATION smoke test (QPSK, 80 B, R=4, TTI=4 ms) ---\n');
disp(struct2table(rmfield(results, 'details')));
fprintf('Full detail structs are available in the ''results'' variable (results(i).details).\n');
