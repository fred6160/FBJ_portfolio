%COMPARE_WITH_LITERATURE Benchmark ProposedDQN against recent published
%   baseline papers, not just against this project's own internal
%   static baselines.
%
%   *** WHY THIS SCRIPT EXISTS ***
%   The supervisor's feedback was explicit: "you still need to validate
%   your results... compare throughput, latency, packet dropped and
%   other metrics ... with your recent baseline paper, conventional
%   NB-IoT and fixed packet-size transmission." Conventional and
%   FixedPacket are already simulated baselines in evaluate_baselines.m.
%   What was missing is a comparison against the numbers actually
%   reported in the cited literature. This script adds that.
%
%   IMPORTANT CAVEAT (stated explicitly in the generated table and
%   repeated here): the papers below were run under different
%   simulation/hardware assumptions, traffic models, and even different
%   radio technologies (e.g. LoRaWAN + NB-IoT smart meters vs. this
%   study's pure NB-IoT NPUSCH link-level simulation). A direct
%   number-for-number comparison is not a controlled experiment -- it is
%   literature benchmarking, which is standard practice for situating a
%   thesis's results but should be presented with that caveat, not as
%   like-for-like validation. Where a paper does not report a metric
%   this study also reports, that cell is left blank rather than
%   estimated.
%
%   Sources (see report reference list for full citations):
%     [1] Abbas, Li, Grinnemo, Eklund & Rajiullah (2025), "Dynamic
%         NB-IoT Configuration: A Machine Learning-Driven Optimization
%         Framework," IEEE IoT Journal. GLOBE framework reduces energy
%         consumption by 30-75% vs baseline configurations.
%     [2] Al-Sammak et al. (2025), "Optimizing IoT Energy Efficiency:
%         Real-Time Adaptive Algorithms for Smart Meters with LoRaWAN
%         and NB-IoT," Energies 18(4):987. NB-IoT arm: ~86.8% reduction
%         in transmitted packets, ~87.3% reduction in energy-consumption
%         spike frequency.
%     [3] Alipio, Chaguile & Bures (2024), "A review of LoRaWAN
%         performance optimization through cross-layer-based approach
%         for IoT," Internet of Things 28:101378. This is a systematic
%         review/survey, not an empirical study -- it reports no single
%         quantitative headline metric, so it is listed for completeness
%         but excluded from the numeric comparison.
%     [4] Anbazhagan & Mugelan (2024b), "Next-gen resource optimization
%         in NB-IoT networks: Harnessing soft actor-critic reinforcement
%         learning," Computer Networks 252:110670. SAC vs DQN/PPO:
%         +10.25% energy efficiency, +214.98% throughput, +614.46%
%         fairness (Jain's index).
%     [5] Arslan, Dörterler & Aydemir (2024), "Reinforcement learning
%         for energy optimization in IoT based landslide early warning
%         systems," J. Scientific Reports-A 59:32-57. DQN-based
%         duty-cycle control extended node uptime to 731 days, ~2.7x the
%         best prior comparator (270 days) -- a different metric axis
%         (solar-harvesting duty-cycle uptime, not radio-layer
%         throughput/latency/PDR), included with that caveat.

projectRoot = setup_path();
tableDir = fullfile(projectRoot, 'docs', 'tables');
if ~exist(tableDir, 'dir'); mkdir(tableDir); end

resultsFile = fullfile(projectRoot, 'evalResults.mat');
if ~isfile(resultsFile)
    error('compare_with_literature:noResults', ...
        'evalResults.mat not found. Run scripts/evaluate_baselines.m first.');
end
L = load(resultsFile);
summary = L.summary;

if ~ismember("ProposedDQN", summary.policy)
    error('compare_with_literature:noAgent', ...
        'No ProposedDQN rows in evalResults.mat. Train and evaluate the agent first.');
end

% --- This study's own energy-reduction % (ProposedDQN vs Conventional,
% averaged across the three TR 45.820 scenarios) -----------------------
scenarios = unique(summary.scenario, 'stable');
pctReductions = zeros(numel(scenarios), 1);
for s = 1:numel(scenarios)
    convRow = summary(summary.scenario == scenarios(s) & summary.policy == "Conventional", :);
    dqnRow  = summary(summary.scenario == scenarios(s) & summary.policy == "ProposedDQN", :);
    if isempty(convRow) || isempty(dqnRow); continue; end
    pctReductions(s) = 100 * (convRow.energyPerSuccessJ_mean - dqnRow.energyPerSuccessJ_mean) / ...
                       convRow.energyPerSuccessJ_mean;
end
thisStudyEnergyPct = mean(pctReductions);

% --- Literature reference table (hardcoded, sourced -- see header) -----
% NOTE: struct('field', {a,b,c,d}, ...) below builds a 1x4 STRUCT ARRAY
% (lit(1), lit(2), ... each with scalar fields) -- not a scalar struct
% of cell arrays. Index as lit(i).label, not lit.label{i}.
lit = struct( ...
    'label',        {"Abbas et al. (2025) -- GLOBE", ...
                     "Al-Sammak et al. (2025) -- NB-IoT arm", ...
                     "Anbazhagan \& Mugelan (2024) -- SAC vs DQN/PPO", ...
                     "Arslan et al. (2024) -- landslide DQN"}, ...
    'metric',       {"Energy reduction vs baseline config", ...
                     "Reduction in energy-spike frequency", ...
                     "Throughput improvement (SAC vs DQN/PPO)", ...
                     "Node uptime vs. best prior comparator"}, ...
    'value',        {"30\%--75\%", "87.3\%", "+214.98\%", "2.7$\times$ longer"}, ...
    'thisStudy',     {sprintf("%.1f\\%%", thisStudyEnergyPct), ...
                      "n/a (different application)", ...
                      "n/a (different comparison axis)", ...
                      "n/a (different comparison axis)"});

fprintf('\n== Literature benchmarking ==\n');
fprintf('This study''s ProposedDQN energy reduction vs Conventional (avg. across scenarios): %.1f%%\n', ...
    thisStudyEnergyPct);
for i = 1:numel(lit)
    fprintf('  %-45s | %-35s | reported: %-10s | this study: %s\n', ...
        char(lit(i).label), char(lit(i).metric), char(lit(i).value), char(lit(i).thisStudy));
end

% --- Emit LaTeX table ---------------------------------------------------
lines = strings(0, 1);
lines(end+1) = "\begin{table}[h]";
lines(end+1) = "\centering";
lines(end+1) = "\caption{Benchmarking against recent published baseline studies. Figures for other studies are as reported in the cited papers under their own simulation/hardware assumptions -- not reproduced here -- and are included for context rather than as a controlled comparison.}";
lines(end+1) = "\label{tab:results_literature_comparison}";
lines(end+1) = "\begin{tabular}{@{}p{4.2cm}p{4.5cm}rr@{}}";
lines(end+1) = "\toprule";
lines(end+1) = "Study & Metric & Reported value & This study \\";
lines(end+1) = "\midrule";
for i = 1:numel(lit)
    lines(end+1) = sprintf("%s & %s & %s & %s \\\\", ...
        lit(i).label, lit(i).metric, lit(i).value, lit(i).thisStudy); %#ok<AGROW>
end
lines(end+1) = "\midrule";
lines(end+1) = "\multicolumn{4}{p{13cm}}{\footnotesize Alipio et al. (2024) is a systematic review of LoRaWAN cross-layer optimization and reports no single quantitative headline metric; it is cited in the literature review for methodological context rather than included here.} \\";
lines(end+1) = "\bottomrule";
lines(end+1) = "\end{tabular}";
lines(end+1) = "\end{table}";

outFile = fullfile(tableDir, 'results_literature_comparison.tex');
fid = fopen(outFile, 'w');
fprintf(fid, '%s', strjoin(lines, newline));
fclose(fid);
fprintf('\nWrote %s\n', outFile);

% --- Companion figure: our energy reduction vs Conventional, per
% scenario, alongside the literature's headline energy-reduction figures
figDir = fullfile(projectRoot, 'docs', 'figures');
if ~exist(figDir, 'dir'); mkdir(figDir); end

f = figure;
labels = [cellstr(scenarios); {'Abbas 2025 (GLOBE)'; 'Al-Sammak 2025 (NB-IoT)'}];
values = [pctReductions; 75; 87.3];  % use the upper reported bound for Abbas' range
bar(categorical(labels, labels), values);
grid on;
ylabel('Energy reduction (\%)', 'Interpreter', 'latex');
title('This study''s energy reduction vs. reported literature values');
saveas(f, fullfile(figDir, 'energy_reduction_vs_literature.png'));
try
    exportgraphics(f, fullfile(figDir, 'energy_reduction_vs_literature.pdf'), 'ContentType', 'vector');
catch
    print(f, '-dpdf', fullfile(figDir, 'energy_reduction_vs_literature.pdf'));
end
close(f);
fprintf('Wrote %s\n', fullfile(figDir, 'energy_reduction_vs_literature.png'));
