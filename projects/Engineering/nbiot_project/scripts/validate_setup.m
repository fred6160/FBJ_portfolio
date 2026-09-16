%VALIDATE_SETUP Environment and dependency checks for the NB-IoT pipeline.
%   Soft-checks MATLAB version and optional toolboxes, creates required
%   output folders, and sanity-checks getDefaultConfig(). This does NOT
%   hard-fail on missing toolboxes: the DQN implementation in this
%   project (src/QNetwork.m, src/DQNAgentCustom.m) is written in plain
%   MATLAB and needs neither the Reinforcement Learning Toolbox nor the
%   Deep Learning Toolbox.

fprintf('--- Validating environment ---\n');

v = ver('MATLAB');
if ~isempty(v)
    fprintf('MATLAB version : %s (%s)\n', v.Version, v.Release);
else
    fprintf('MATLAB version : unknown\n');
end

optionalToolboxes = {'Statistics and Machine Learning Toolbox', ...
                     'Communications Toolbox', ...
                     'Reinforcement Learning Toolbox', ...
                     'Deep Learning Toolbox'};
installed = ver;
installedNames = {installed.Name};
for i = 1:numel(optionalToolboxes)
    if any(strcmp(installedNames, optionalToolboxes{i}))
        fprintf('  [ok]   %s found\n', optionalToolboxes{i});
    else
        fprintf('  [info] %s not found (not required by this pipeline)\n', optionalToolboxes{i});
    end
end

projectRoot = setup_path();
requiredDirs = {fullfile(projectRoot, 'docs', 'figures'), ...
               fullfile(projectRoot, 'docs', 'tables')};
for i = 1:numel(requiredDirs)
    if ~exist(requiredDirs{i}, 'dir')
        mkdir(requiredDirs{i});
        fprintf('  created %s\n', requiredDirs{i});
    end
end

cfg = getDefaultConfig();
assert(numel(cfg.phy.packetSizesBytes) > 0, 'validate_setup:emptyGrid', 'Empty packet size grid.');
assert(numel(cfg.phy.repetitionFactors) > 0, 'validate_setup:emptyGrid', 'Empty repetition grid.');
assert(numel(cfg.mac.ttiMs) > 0, 'validate_setup:emptyGrid', 'Empty TTI grid.');
assert(numel(cfg.phy.modulations) > 0, 'validate_setup:emptyGrid', 'Empty modulation grid.');
assert(cfg.qos.minReliability > 0 && cfg.qos.minReliability <= 1, ...
    'validate_setup:badQos', 'cfg.qos.minReliability must be in (0,1].');
assert(cfg.qos.maxLatencyMs > 0, 'validate_setup:badQos', 'cfg.qos.maxLatencyMs must be positive.');

numActions = numel(cfg.phy.packetSizesBytes) * numel(cfg.phy.repetitionFactors) * ...
             numel(cfg.phy.modulations) * numel(cfg.mac.ttiMs);
fprintf('  Action-grid size for the DQN: %d discrete actions\n', numActions);

fprintf('--- Environment OK ---\n\n');
