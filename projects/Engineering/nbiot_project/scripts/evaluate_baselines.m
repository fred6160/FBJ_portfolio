%EVALUATE_BASELINES Per-scenario evaluation of all policies.
%
%   Runs every policy (Conventional, FixedPacket, SNR-Adaptive, Prior-RL,
%   Proposed-DQN) across the three TR 45.820 scenarios (urban, rural,
%   deep_indoor) over multiple independent seeds. For each (scenario,
%   policy) we report the mean and 95% confidence interval of:
%
%       energyPerSuccessJ   - expected energy per successful packet (J)
%       pdsr                - packet delivery success rate
%       packetDropRate      - 1 - pdsr
%       latencyMs           - average per-packet latency (ms)
%       throughputBps       - effective throughput (bits/s)
%
%   Results are saved to evalResults.mat in long format ("tidy data") so
%   that figure generation and LaTeX table emission read from a single
%   source of truth.
%
%   FIX vs. the original script: all file I/O now goes through
%   fullfile(projectRoot, ...) instead of bare relative filenames, so
%   this script behaves the same regardless of MATLAB's current folder.
%   The ProposedDQN selector now wraps the plain-MATLAB DQNAgentCustom
%   (see src/DQNAgentCustom.m) instead of an RL-Toolbox agent object.

projectRoot = setup_path();
cfg = getDefaultConfig();
rng(cfg.seed);

NUM_SEEDS = 10;
NUM_STEPS = 200;

scenarios = ["urban", "rural", "deep_indoor"];

% --- Discover available policies ----------------------------------------
policies = {};
policies{end+1} = struct('name', "Conventional", 'select', @baselineConventional, 'kind', "static");
policies{end+1} = struct('name', "FixedPacket",  'select', @baselineFixedPacket,  'kind', "static");
policies{end+1} = struct('name', "SNRAdaptive",  'select', @baselineSnrAdaptive,  'kind', "heuristic");

% Prior-RL: train once on the urban scenario (representative of prior work)
fprintf('Training prior-RL (tabular Q-learning) baseline...\n');
cfgUrban = cfg; cfgUrban.env.active = "urban"; cfgUrban.rl.maxStepsPerEpisode = 50;
priorEnv   = NBIoTRLEnv(cfgUrban, "urban");
priorAgent = PriorRLAgent(cfgUrban);
priorAgent.train(priorEnv, 60);
policies{end+1} = struct('name', "PriorRL", 'select', ...
                         @(state, c) priorAgent.selectAction(state, c), 'kind', "rl");

% Proposed DQN (if trained)
agentFile = fullfile(projectRoot, 'trainedAgent.mat');
if isfile(agentFile)
    S = load(agentFile, 'agent');
    proposedAgent = S.agent;
    policies{end+1} = struct('name', "ProposedDQN", 'select', ...
                             @(state, c) selectDqnAction(proposedAgent, state, c), 'kind', "rl");
else
    warning("evaluate_baselines:noAgent", ...
        "trainedAgent.mat not found -- skipping ProposedDQN. Run scripts/train_rl_agent.m first.");
end

% --- Sweep -------------------------------------------------------------
records = struct('scenario', {}, 'policy', {}, 'seed', {}, ...
                 'energyPerSuccessJ', {}, 'pdsr', {}, 'packetDropRate', {}, ...
                 'latencyMs', {}, 'throughputBps', {});

for s = 1:numel(scenarios)
    scn = scenarios(s);
    for p = 1:numel(policies)
        pol = policies{p};
        for seed = 1:NUM_SEEDS
            rng(cfg.seed + seed);
            m = rolloutPolicy(cfg, scn, pol.select, NUM_STEPS);
            records(end+1) = struct( ...
                'scenario',          scn, ...
                'policy',            pol.name, ...
                'seed',              seed, ...
                'energyPerSuccessJ', m.energyPerSuccessJ, ...
                'pdsr',              m.pdsr, ...
                'packetDropRate',    m.packetDropRate, ...
                'latencyMs',         m.latencyMs, ...
                'throughputBps',     m.throughputBps); %#ok<SAGROW>
        end
    end
    fprintf('Finished scenario %s (%d policies x %d seeds)\n', scn, numel(policies), NUM_SEEDS);
end

% --- Aggregate to mean / 95% CI ----------------------------------------
T = struct2table(records);
summary = aggregateResults(T);

% --- Persist -----------------------------------------------------------
save(fullfile(projectRoot, 'evalResults.mat'), 'records', 'T', 'summary', 'cfg');

fprintf('\n== Per-scenario summary (mean [95%% CI]) ==\n');
disp(summary);

% =====================================================================
%                              local fns
% =====================================================================

function action = selectDqnAction(agent, state, cfg)
% Wrap the trained DQNAgentCustom as a unified policy function matching
% the (state, cfg) -> action struct interface used by every other policy.
    obs = [state.SNRdB; state.ResidualEnergyJ; state.RecentBLER; ...
          state.Retransmissions; state.QueueLen];
    a = agent.selectAction(obs, true);   % greedy at evaluation time
    row = agent.Env.ActionTable(a, :);
    modName = string(cfg.phy.modulations{row(3)});
    action = struct('packet', row(1), 'rep', row(2), 'mod', modName, ...
                    'tti', row(4), 'name', "ProposedDQN");
end

function m = rolloutPolicy(cfg, scenario, selectFn, nSteps)
% Roll one episode under a fixed scenario and return per-step means.
    cfg.env.active = scenario;

    state.SNRdB           = 0;
    state.MarkovStateIdx  = 1;
    state.ResidualEnergyJ = cfg.energy.batteryJ;
    state.RecentBLER      = 0.1;
    state.Retransmissions = 0;
    state.QueueLen        = 10;

    [snrDb, ch] = channelSnapshot(cfg, scenario, state.MarkovStateIdx);
    state.SNRdB = snrDb;
    if isfield(ch, 'markovStateIdx'); state.MarkovStateIdx = ch.markovStateIdx; end

    sumEnergy = 0; sumPdsr = 0; sumLatency = 0; sumThroughput = 0;

    for k = 1:nSteps
        a = selectFn(state, cfg);
        bler = blerModel(state.SNRdB, a.mod, a.packet, a.rep, cfg);
        [eJ, det] = energyModel(cfg, a.packet, a.rep, bler, a.mod, a.tti);

        sumEnergy     = sumEnergy     + eJ;
        sumPdsr       = sumPdsr       + (1 - bler);
        sumLatency    = sumLatency    + det.latencyMs;
        sumThroughput = sumThroughput + det.throughputBps;

        % step the channel and bookkeeping state
        [snrDb, ch] = channelSnapshot(cfg, scenario, state.MarkovStateIdx);
        state.SNRdB = snrDb;
        if isfield(ch, 'markovStateIdx'); state.MarkovStateIdx = ch.markovStateIdx; end
        state.RecentBLER      = bler;
        state.Retransmissions = max(round(bler*10), 0);
        state.ResidualEnergyJ = max(state.ResidualEnergyJ - det.energyAttemptJ, 0);
        state.QueueLen        = max(state.QueueLen - 1 + randi([0 2]), 0);
    end

    m = struct( ...
        'energyPerSuccessJ', sumEnergy / nSteps, ...
        'pdsr',              sumPdsr / nSteps, ...
        'packetDropRate',    1 - (sumPdsr / nSteps), ...
        'latencyMs',         sumLatency / nSteps, ...
        'throughputBps',     sumThroughput / nSteps);
end

function summary = aggregateResults(T)
%AGGREGATERESULTS Mean and 95% CI for each (scenario, policy).
    metrics = ["energyPerSuccessJ", "pdsr", "packetDropRate", "latencyMs", "throughputBps"];
    [G, scn, pol] = findgroups(T.scenario, T.policy);

    out = struct('scenario', {}, 'policy', {});
    for g = 1:max(G)
        out(g).scenario = scn(g);
        out(g).policy   = pol(g);
        for j = 1:numel(metrics)
            v = T.(metrics(j))(G == g);
            mu = mean(v);
            sd = std(v);
            ci = 1.96 * sd / sqrt(numel(v));
            out(g).(metrics(j) + "_mean") = mu;
            out(g).(metrics(j) + "_ci")   = ci;
        end
    end
    summary = struct2table(out);
end
