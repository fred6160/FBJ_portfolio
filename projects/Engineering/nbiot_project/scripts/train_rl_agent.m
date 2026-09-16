%TRAIN_RL_AGENT Train the proposed cross-layer DQN agent.
%   Trains on the "urban" scenario by default (representative training
%   condition per report Section 3.2), then saves the trained agent and
%   the full training-reward history to trainedAgent.mat for use by
%   evaluate_baselines.m and generate_figures.m.
%
%   NOTE ON RUNTIME: cfg.rl.maxEpisodes (500) x cfg.rl.maxStepsPerEpisode
%   (200) is up to 100,000 environment steps. With the plain-MATLAB
%   QNetwork this typically takes minutes to tens of minutes depending
%   on hardware. For a quick smoke test during development, lower
%   NUM_EPISODES below (e.g. to 30-50) before running RUN_ALL.

projectRoot = setup_path();
cfg = getDefaultConfig();
rng(cfg.seed);

NUM_EPISODES = cfg.rl.maxEpisodes;   % set lower for a fast smoke test

trainCfg = cfg;
trainCfg.env.active = "urban";

env   = NBIoTRLEnv(trainCfg, "urban");
agent = DQNAgentCustom(trainCfg, env);

fprintf('--- Training proposed DQN agent (%d episodes, urban scenario) ---\n', NUM_EPISODES);
fprintf('    obs dim = %d, action-grid size = %d\n', env.obsDim(), env.numActions());

trainingStats = agent.train(NUM_EPISODES, true);

agentFile = fullfile(projectRoot, 'trainedAgent.mat');
save(agentFile, 'agent', 'trainingStats', 'cfg');
fprintf('Saved trained agent to %s\n', agentFile);
