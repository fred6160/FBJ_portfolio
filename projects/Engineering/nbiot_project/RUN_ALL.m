%RUN_ALL End-to-end pipeline for the NB-IoT cross-layer RL project.
%   1. Validate environment / toolboxes
%   2. Generate dataset (for model-curve figures)
%   3. Train proposed DQN agent
%   4. Evaluate all policies across all TR 45.820 scenarios
%   5. Render publication figures
%   6. Emit LaTeX-ready result tables
%
%   Run this from the MATLAB command window with the project root as
%   the current folder (or anywhere, since every path is resolved
%   through setup_path()):
%
%       >> RUN_ALL
%
%   Expect a full run (500 training episodes x 200 steps, plus 10 seeds
%   x 5 policies x 3 scenarios x 200-step evaluation rollouts) to take
%   anywhere from several minutes to a couple of hours depending on your
%   machine, since the DQN in this project is a plain-MATLAB
%   implementation (no GPU/Deep Learning Toolbox dependency). For a
%   quick smoke test, open scripts/train_rl_agent.m and reduce
%   NUM_EPISODES before running RUN_ALL.

projectRoot = setup_path();

fprintf('================================================================\n');
fprintf(' NB-IoT Cross-Layer Adaptive Packet Configuration -- Full Pipeline\n');
fprintf('================================================================\n\n');

run(fullfile(projectRoot, 'scripts', 'validate_setup.m'));
run(fullfile(projectRoot, 'scripts', 'generate_dataset.m'));
run(fullfile(projectRoot, 'scripts', 'train_rl_agent.m'));
run(fullfile(projectRoot, 'scripts', 'evaluate_baselines.m'));
run(fullfile(projectRoot, 'scripts', 'generate_figures.m'));
run(fullfile(projectRoot, 'scripts', 'generate_report_tables.m'));
run(fullfile(projectRoot, 'scripts', 'statistical_analysis.m'));
run(fullfile(projectRoot, 'scripts', 'compare_with_literature.m'));

fprintf('\n================================================================\n');
fprintf(' RUN_ALL complete\n');
fprintf('   Dataset  : %s\n', fullfile(projectRoot, 'dataset_nb_iot.csv'));
fprintf('   Agent    : %s\n', fullfile(projectRoot, 'trainedAgent.mat'));
fprintf('   Results  : %s\n', fullfile(projectRoot, 'evalResults.mat'));
fprintf('   Figures  : %s\n', fullfile(projectRoot, 'docs', 'figures'));
fprintf('   Tables   : %s\n', fullfile(projectRoot, 'docs', 'tables'));
fprintf('   Stats    : %s\n', fullfile(projectRoot, 'statisticalResults.mat'));
fprintf('================================================================\n');
