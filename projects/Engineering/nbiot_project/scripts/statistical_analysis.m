%STATISTICAL_ANALYSIS Hypothesis testing to back up the Chapter 4 claims.
%
%   Report Section 4.5 ("Statistical Analysis of Results") states that
%   anova1, ttest2, and fitlm were used to verify that the proposed
%   framework's improvements are statistically significant, and quotes
%   specific figures ("Energy Reduction Improvement: 37%-92% (p<0.001)",
%   "Reliability Improvement: 87.7%-98.0% (p<<0.001)"). Nothing in the
%   uploaded codebase actually computed those numbers -- this script
%   does, from the real per-seed evalResults.mat records, so the
%   percentages and p-values reported in the document are the ones this
%   code actually produced rather than hand-typed placeholders.
%
%   For each scenario and each metric, this script:
%     1. Runs a one-way ANOVA (anova1) across all 5 policies.
%     2. Runs a two-sample t-test (ttest2) for ProposedDQN vs each of
%        the 4 baselines, and reports the % change.
%   Requires the Statistics and Machine Learning Toolbox (anova1,
%   ttest2). If unavailable, this script computes the % changes only and
%   skips the p-values with a warning.

projectRoot = setup_path();
tableDir = fullfile(projectRoot, 'docs', 'tables');
if ~exist(tableDir, 'dir'); mkdir(tableDir); end

resultsFile = fullfile(projectRoot, 'evalResults.mat');
if ~isfile(resultsFile)
    error('statistical_analysis:noResults', ...
        'evalResults.mat not found. Run scripts/evaluate_baselines.m first.');
end
L = load(resultsFile);
T = L.T;

hasStatsToolbox = any(strcmp({ver().Name}, 'Statistics and Machine Learning Toolbox'));
if ~hasStatsToolbox
    warning('statistical_analysis:noToolbox', ...
        'Statistics and Machine Learning Toolbox not found -- p-values will be skipped, %% changes still computed.');
end

scenarios = unique(T.scenario, 'stable');
metrics   = ["energyPerSuccessJ", "pdsr", "latencyMs", "throughputBps", "packetDropRate"];
% Direction of "improvement" for each metric: -1 means lower is better,
% +1 means higher is better. Used only for the sign of the % change.
improveSign = struct('energyPerSuccessJ', -1, 'pdsr', +1, 'latencyMs', -1, ...
                     'throughputBps', +1, 'packetDropRate', -1);

rows = struct('scenario', {}, 'metric', {}, 'anova_p', {}, ...
              'vs_policy', {}, 'pct_change', {}, 'ttest_p', {});

for s = 1:numel(scenarios)
    scn = scenarios(s);
    sub = T(T.scenario == scn, :);
    baselines = setdiff(unique(sub.policy, 'stable'), "ProposedDQN");

    for m = 1:numel(metrics)
        metric = metrics(m);
        vals = sub.(metric);

        anovaP = NaN;
        if hasStatsToolbox
            anovaP = anova1(vals, cellstr(sub.policy), 'off');
        end

        if ~ismember("ProposedDQN", sub.policy)
            continue; % nothing trained yet -- skip proposed-vs-baseline comparisons
        end
        proposedVals = sub.(metric)(sub.policy == "ProposedDQN");

        for b = 1:numel(baselines)
            baseVals = sub.(metric)(sub.policy == baselines(b));
            pctChange = 100 * improveSign.(metric) * ...
                       (mean(baseVals) - mean(proposedVals)) / abs(mean(baseVals) + eps);
            % pctChange > 0 always means "ProposedDQN is better"

            ttestP = NaN;
            if hasStatsToolbox && numel(proposedVals) > 1 && numel(baseVals) > 1
                [~, ttestP] = ttest2(proposedVals, baseVals);
            end

            rows(end+1) = struct('scenario', scn, 'metric', metric, ... %#ok<SAGROW>
                'anova_p', anovaP, 'vs_policy', baselines(b), ...
                'pct_change', pctChange, 'ttest_p', ttestP);
        end
    end
end

statTable = struct2table(rows);
save(fullfile(projectRoot, 'statisticalResults.mat'), 'statTable');

fprintf('\n== Statistical analysis (ProposedDQN vs each baseline) ==\n');
disp(statTable);

% --- Emit a LaTeX summary table (energy + reliability, the two metrics
% Section 4.5 explicitly quotes) --------------------------------------
lines = strings(0, 1);
lines(end+1) = "\begin{table}[h]";
lines(end+1) = "\centering";
lines(end+1) = "\caption{Statistical significance of ProposedDQN improvements over each baseline (two-sample $t$-test).}";
lines(end+1) = "\label{tab:results_statistics}";
lines(end+1) = "\begin{tabular}{@{}llrrr@{}}";
lines(end+1) = "\toprule";
lines(end+1) = "Scenario & Baseline & Metric & \% change & $p$-value \\";
lines(end+1) = "\midrule";
for i = 1:height(statTable)
    r = statTable(i, :);
    if ismember(r.metric, ["energyPerSuccessJ", "pdsr"])
        pStr = "n/a";
        if ~isnan(r.ttest_p)
            if r.ttest_p < 0.001
                pStr = "$<0.001$";
            else
                pStr = sprintf("%.3f", r.ttest_p);
            end
        end
        lines(end+1) = sprintf("%s & %s & %s & %+.1f\\%% & %s \\\\", ...
            char(r.scenario), char(r.vs_policy), char(r.metric), r.pct_change, pStr); %#ok<AGROW>
    end
end
lines(end+1) = "\bottomrule";
lines(end+1) = "\end{tabular}";
lines(end+1) = "\end{table}";

outFile = fullfile(tableDir, 'results_statistics.tex');
fid = fopen(outFile, 'w');
fprintf(fid, '%s', strjoin(lines, newline));
fclose(fid);
fprintf('Wrote %s\n', outFile);

% Also print the headline range the report narrative wants to quote
% ("Energy Reduction Improvement: X%-Y%"):
energyRows = statTable(statTable.metric == "energyPerSuccessJ", :);
relRows    = statTable(statTable.metric == "pdsr", :);
if ~isempty(energyRows)
    fprintf('\nEnergy reduction improvement range (ProposedDQN vs baselines): %.1f%% - %.1f%%\n', ...
        min(energyRows.pct_change), max(energyRows.pct_change));
end
if ~isempty(relRows)
    fprintf('Reliability improvement range (ProposedDQN vs baselines): %.1f%% - %.1f%%\n', ...
        min(relRows.pct_change), max(relRows.pct_change));
end
