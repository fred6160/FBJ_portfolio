%GENERATE_FIGURES Publication-style figures for the technical report.
%
%   Produces .png and .pdf figures into docs/figures using a white
%   publication palette. Reads from evalResults.mat, trainedAgent.mat,
%   and dataset_nb_iot.csv (all produced by earlier pipeline stages) so
%   figures stay in sync with the latest simulation run.
%
%   FIX vs. the original script: all file I/O goes through
%   fullfile(projectRoot, ...); trainingStats is a MATLAB table (not an
%   object), so column-existence is checked with
%   ismember(...,Properties.VariableNames) instead of isprop(); and this
%   version regenerates the dataset-driven Figures 4.5-4.7 (energy vs.
%   packet size, reliability vs. repetition, latency vs. TTI) that were
%   present in the report narrative but missing from the original
%   script, using the corrected channel/energy models.

projectRoot = setup_path();

% --- Publication style ---------------------------------------------------
set(groot, 'DefaultFigureColor', [1 1 1]);
set(groot, 'DefaultAxesColor',   [1 1 1]);
set(groot, 'DefaultAxesXColor',  [0 0 0]);
set(groot, 'DefaultAxesYColor',  [0 0 0]);
set(groot, 'DefaultTextColor',   [0 0 0]);
set(groot, 'DefaultAxesFontSize',     11);
set(groot, 'DefaultAxesFontName',     'Times New Roman');
set(groot, 'DefaultLineLineWidth',    1.4);

figDir = fullfile(projectRoot, 'docs', 'figures');
if ~exist(figDir, 'dir'); mkdir(figDir); end

% --- Load data -----------------------------------------------------------
resultsFile = fullfile(projectRoot, 'evalResults.mat');
if ~isfile(resultsFile)
    error('generate_figures:noResults', ...
        'evalResults.mat not found. Run scripts/evaluate_baselines.m first.');
end
L = load(resultsFile);
T = L.T; summary = L.summary;

trainingStats = [];
agentFile = fullfile(projectRoot, 'trainedAgent.mat');
if isfile(agentFile)
    S = load(agentFile, 'trainingStats');
    if isfield(S, 'trainingStats'); trainingStats = S.trainingStats; end
end

datasetFile = fullfile(projectRoot, 'dataset_nb_iot.csv');
if isfile(datasetFile)
    D = readtable(datasetFile);
else
    D = [];
end

% --- Fig 1: training reward ---------------------------------------------
if ~isempty(trainingStats)
    f = figure;
    plot(trainingStats.EpisodeReward, 'Color', [0.10 0.30 0.70]);
    hold on;
    if ismember('AverageReward', trainingStats.Properties.VariableNames)
        plot(trainingStats.AverageReward, 'Color', [0.85 0.20 0.20]);
    end
    grid on;
    xlabel('Episode'); ylabel('Total Reward');
    legend({'Per-episode', 'Moving avg. (10 ep.)'}, 'Location', 'best');
    title('Proposed DQN training reward');
    exportFig(f, fullfile(figDir, 'training_reward'));
end

% --- Fig 2: grouped bar — energy per scenario ---------------------------
groupedBar(summary, "energyPerSuccessJ_mean", 'Energy per successful packet (J)', ...
           fullfile(figDir, 'energy_per_scenario'));

% --- Fig 3: grouped bar — PDSR per scenario -----------------------------
groupedBar(summary, "pdsr_mean", 'Packet delivery success rate', ...
           fullfile(figDir, 'pdsr_per_scenario'));

% --- Fig 4: grouped bar — latency per scenario --------------------------
groupedBar(summary, "latencyMs_mean", 'Latency (ms)', ...
           fullfile(figDir, 'latency_per_scenario'));

% --- Fig 5: grouped bar — throughput per scenario -----------------------
groupedBar(summary, "throughputBps_mean", 'Throughput (bps)', ...
           fullfile(figDir, 'throughput_per_scenario'));

% --- Fig 5b: 3-panel comparison (Energy / Reliability / Latency by
% policy), matching the original Figure 4.3 layout (subplot, one bar
% chart per metric, all 5 policies as categories) so this can be dropped
% straight into the report in place of the old figure. Averaged across
% all three scenarios, since the original figure did not specify a
% single scenario.
threePanelComparison(summary, fullfile(figDir, 'comparative_analysis_energy_reliability_latency'));

% --- Fig 6: CDF of energy per policy (deep_indoor) ----------------------
cdfByPolicy(T, "deep_indoor", "energyPerSuccessJ", ...
            'Energy per successful packet (J)', ...
            fullfile(figDir, 'energy_cdf_deep_indoor'));

% --- Fig 7: BLER vs SNR (model curves) ----------------------------------
f = figure; hold on; grid on;
snrs = -25:0.5:15;
configs = struct( ...
    'label', {'BPSK, 20B, R=16', 'QPSK, 80B, R=4', 'QPSK, 320B, R=1'}, ...
    'mod',   {"BPSK",            "QPSK",            "QPSK"}, ...
    'pkt',   {20,                80,                320}, ...
    'rep',   {16,                4,                 1});
cfg = getDefaultConfig();
for i = 1:numel(configs)
    bler = arrayfun(@(s) blerModel(s, configs(i).mod, configs(i).pkt, configs(i).rep, cfg), snrs);
    plot(snrs, bler, 'DisplayName', configs(i).label);
end
xlabel('SNR (dB)'); ylabel('BLER'); set(gca, 'YScale', 'log');
legend('Location', 'southwest'); title('NB-IoT BLER vs SNR');
exportFig(f, fullfile(figDir, 'bler_vs_snr'));

% --- Fig 8: SNR distribution by environment -----------------------------
if ~isempty(D)
    f = figure;
    boxchart(categorical(D.envId), D.snrDb);
    grid on; xlabel('Scenario ID (1=urban, 2=rural, 3=deep\_indoor)'); ylabel('SNR (dB)');
    title('SNR distribution by scenario');
    exportFig(f, fullfile(figDir, 'snr_by_env'));

    % --- Fig 9: BLER vs SNR, sampled dataset (colour = scenario) --------
    f = figure;
    scatter(D.snrDb, D.bler, 12, D.envId, 'filled');
    grid on; xlabel('SNR (dB)'); ylabel('BLER'); colorbar;
    title('BLER vs SNR (sampled dataset)');
    exportFig(f, fullfile(figDir, 'bler_vs_snr_dataset'));

    % --- Fig 10: Energy vs packet size (report Fig. 4.5 equivalent) -----
    f = figure;
    boxchart(categorical(D.packetBytes), D.energyJ);
    set(gca, 'YScale', 'log'); grid on;
    xlabel('Packet size (bytes)'); ylabel('Energy per success (J, log scale)');
    title('Energy vs packet size');
    exportFig(f, fullfile(figDir, 'energy_vs_packet_size'));

    % --- Fig 11: Reliability vs repetition (report Fig. 4.6 equivalent) -
    f = figure;
    relByRep = groupsummary(D, 'repetition', 'mean', 'bler');
    relByRep.reliability = 1 - relByRep.mean_bler;
    plot(relByRep.repetition, relByRep.reliability, '-o');
    grid on; xlabel('Repetition factor'); ylabel('Mean reliability (1 - BLER)');
    title('Reliability vs repetition factor');
    exportFig(f, fullfile(figDir, 'reliability_vs_repetition'));

    % --- Fig 12: Latency vs TTI (report Fig. 4.7 equivalent) ------------
    f = figure;
    latByTti = groupsummary(D, 'ttiMs', 'mean', 'latencyMs');
    plot(latByTti.ttiMs, latByTti.mean_latencyMs, '-o');
    grid on; xlabel('TTI (ms)'); ylabel('Mean latency (ms)');
    title('Latency vs TTI');
    exportFig(f, fullfile(figDir, 'latency_vs_tti'));
end

fprintf('Saved publication figures to %s\n', figDir);

% =====================================================================
%                              local fns
% =====================================================================

function threePanelComparison(summary, outPath)
% Reproduces the layout of the original report's Figure 4.3: three
% stacked subplots (Energy per step, Reliability, Latency), one bar per
% policy, averaged across scenarios.
    policies = unique(summary.policy, 'stable');
    nPol = numel(policies);
    energyVals = nan(nPol, 1); relVals = nan(nPol, 1); latVals = nan(nPol, 1);
    for j = 1:nPol
        rows = summary(summary.policy == policies(j), :);
        energyVals(j) = mean(rows.energyPerSuccessJ_mean);
        relVals(j)    = mean(rows.pdsr_mean) * 100;   % as a percentage, matching original Table 4.2 units
        latVals(j)    = mean(rows.latencyMs_mean);
    end

    f = figure;
    subplot(3, 1, 1);
    bar(categorical(cellstr(policies), cellstr(policies)), energyVals);
    ylabel('Energy per step (J)'); title('Energy per Step'); grid on;

    subplot(3, 1, 2);
    bar(categorical(cellstr(policies), cellstr(policies)), relVals);
    ylabel('Reliability (%)'); title('Reliability'); grid on;

    subplot(3, 1, 3);
    bar(categorical(cellstr(policies), cellstr(policies)), latVals);
    ylabel('Latency (ms)'); title('Latency'); grid on;

    sgtitle('Comparative Analysis of Energy Consumption, Reliability, and Latency');
    exportFig(f, outPath);
end

function groupedBar(summary, metric, yLabel, outPath)
    scenarios = unique(summary.scenario, 'stable');
    policies  = unique(summary.policy,   'stable');
    M = nan(numel(scenarios), numel(policies));
    for i = 1:numel(scenarios)
        for j = 1:numel(policies)
            row = summary(summary.scenario == scenarios(i) & ...
                          summary.policy   == policies(j), :);
            if ~isempty(row)
                M(i, j) = row.(metric);
            end
        end
    end
    f = figure;
    b = bar(M);
    set(gca, 'XTickLabel', cellstr(scenarios));
    legend(b, cellstr(policies), 'Location', 'bestoutside');
    ylabel(yLabel); grid on;
    title(strrep(yLabel, '_', ' '));
    exportFig(f, outPath);
end

function cdfByPolicy(T, scenario, metric, xLabel, outPath)
    scn = string(scenario);
    sub = T(T.scenario == scn, :);
    if isempty(sub); return; end
    policies = unique(sub.policy, 'stable');
    f = figure; hold on; grid on;
    for j = 1:numel(policies)
        v = sub.(metric)(sub.policy == policies(j));
        [~, x] = ecdf(v); y = (1:numel(x))'/numel(x);
        plot(x, y, 'DisplayName', char(policies(j)));
    end
    xlabel(xLabel); ylabel('Empirical CDF');
    legend('Location', 'best');
    title(sprintf('%s CDF (%s)', xLabel, scn));
    exportFig(f, outPath);
end

function exportFig(f, basePath)
    saveas(f, [basePath '.png']);
    try
        exportgraphics(f, [basePath '.pdf'], 'ContentType', 'vector');
    catch
        print(f, '-dpdf', [basePath '.pdf']);
    end
    close(f);
end
