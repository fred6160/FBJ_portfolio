%GENERATE_REPORT_TABLES Emit LaTeX-ready fragments from evalResults.mat.
%
%   For each TR 45.820 scenario this script writes a booktabs table
%   listing every policy's mean (95% CI) for the headline metrics. The
%   fragments are saved under docs/tables/ and \input{}-ed by the main
%   technical report so the LaTeX text never drifts from the simulation.
%
%   FIX vs. the original script: file I/O goes through
%   fullfile(projectRoot, ...); fwrite(fid, stringObject) has been
%   replaced with fprintf(fid, '%s', fragment), since fwrite expects
%   numeric/char data and a bare MATLAB string can behave inconsistently
%   across MATLAB versions.
%
%   FIX (supervisor review): PDSR and packet-drop rate are now reported
%   as percentages (x100) with a "(%)" column header, matching the
%   supervisor's explicit metric spec ("Packet Delivery Success Rate
%   (%)"). Previously these were left as raw 0-1 fractions.

projectRoot = setup_path();
tableDir = fullfile(projectRoot, 'docs', 'tables');
if ~exist(tableDir, 'dir'); mkdir(tableDir); end

resultsFile = fullfile(projectRoot, 'evalResults.mat');
if ~isfile(resultsFile)
    error('generate_report_tables:noResults', ...
        'evalResults.mat not found. Run scripts/evaluate_baselines.m first.');
end
L = load(resultsFile);
summary = L.summary;

scenarios = unique(summary.scenario, 'stable');

% Order policies (Conventional first, ProposedDQN last) for consistent
% column-ordering in the manuscript.
policyOrder = ["Conventional", "FixedPacket", "SNRAdaptive", "PriorRL", "ProposedDQN"];

for s = 1:numel(scenarios)
    scn = scenarios(s);
    fragment = renderScenarioTable(summary, scn, policyOrder);
    outFile = fullfile(tableDir, sprintf('results_%s.tex', char(scn)));
    fid = fopen(outFile, 'w');
    fprintf(fid, '%s', fragment);
    fclose(fid);
    fprintf('Wrote %s\n', outFile);
end

% Headline cross-scenario summary (energy only, mean +/- CI)
headlineFile = fullfile(tableDir, 'results_headline.tex');
fid = fopen(headlineFile, 'w');
fprintf(fid, '%s', renderHeadlineTable(summary, scenarios, policyOrder));
fclose(fid);
fprintf('Wrote %s\n', headlineFile);

% =====================================================================
function tex = renderScenarioTable(summary, scenario, policyOrder)
    scn = string(scenario);
    rows = summary(summary.scenario == scn, :);

    lines = strings(0,1);
    lines(end+1) = "\begin{table}[h]";
    lines(end+1) = "\centering";
    lines(end+1) = sprintf("\\caption{Policy comparison under the \\emph{%s} scenario (mean $\\pm$ 95\\%% CI over 10 seeds).}", scnLabel(scn));
    lines(end+1) = sprintf("\\label{tab:results_%s}", scn);
    lines(end+1) = "\begin{tabular}{@{}lrrrrr@{}}";
    lines(end+1) = "\toprule";
    lines(end+1) = "Policy & Energy/pkt (J) & PDSR (\%) & Drop (\%) & Latency (ms) & Throughput (bps) \\";
    lines(end+1) = "\midrule";

    for k = 1:numel(policyOrder)
        pol = policyOrder(k);
        r = rows(rows.policy == pol, :);
        if isempty(r); continue; end
        prefix = ternary(pol == "ProposedDQN", "\textbf{", "");
        suffix = ternary(pol == "ProposedDQN", "}",       "");
        lines(end+1) = sprintf( ...
            "%s%s%s & %s & %s & %s & %s & %s \\\\", ...
            prefix, char(pol), suffix, ...
            fmt(r.energyPerSuccessJ_mean, r.energyPerSuccessJ_ci), ...
            fmt(r.pdsr_mean * 100,              r.pdsr_ci * 100), ...
            fmt(r.packetDropRate_mean * 100,    r.packetDropRate_ci * 100), ...
            fmt(r.latencyMs_mean, r.latencyMs_ci), ...
            fmt(r.throughputBps_mean,     r.throughputBps_ci));
    end

    lines(end+1) = "\bottomrule";
    lines(end+1) = "\end{tabular}";
    lines(end+1) = "\end{table}";
    tex = strjoin(lines, newline);
end

function tex = renderHeadlineTable(summary, scenarios, policyOrder)
    lines = strings(0,1);
    lines(end+1) = "\begin{table}[h]";
    lines(end+1) = "\centering";
    lines(end+1) = "\caption{Mean energy per successful packet (J) across TR 45.820 scenarios.}";
    lines(end+1) = "\label{tab:results_headline}";
    lines(end+1) = sprintf("\\begin{tabular}{@{}l%s@{}}", repmat('r', 1, numel(scenarios)));
    lines(end+1) = "\toprule";
    hdr = "Policy";
    for s = 1:numel(scenarios)
        hdr = hdr + " & " + scnLabel(scenarios(s));
    end
    lines(end+1) = hdr + " \\";
    lines(end+1) = "\midrule";
    for k = 1:numel(policyOrder)
        pol = policyOrder(k);
        row = char(pol);
        for s = 1:numel(scenarios)
            r = summary(summary.scenario == scenarios(s) & summary.policy == pol, :);
            if isempty(r)
                row = [row ' & --'];
            else
                row = sprintf('%s & %.3f', row, r.energyPerSuccessJ_mean);
            end
        end
        if pol == "ProposedDQN"
            row = ['\textbf{' row '}'];
        end
        lines(end+1) = string([row ' \\']);
    end
    lines(end+1) = "\bottomrule";
    lines(end+1) = "\end{tabular}";
    lines(end+1) = "\end{table}";
    tex = strjoin(lines, newline);
end

function s = fmt(mu, ci)
    if mu >= 100 || mu < 0.01
        s = sprintf('%.2g $\\pm$ %.1g', mu, ci);
    else
        s = sprintf('%.3f $\\pm$ %.3f', mu, ci);
    end
end

function lbl = scnLabel(scn)
    switch lower(string(scn))
        case "urban",       lbl = "Urban (MCL 144 dB)";
        case "rural",       lbl = "Rural (MCL 154 dB)";
        case "deep_indoor", lbl = "Deep indoor (MCL 164 dB)";
        otherwise,          lbl = scn;
    end
end

function v = ternary(cond, a, b)
    if cond, v = a; else, v = b; end
end
