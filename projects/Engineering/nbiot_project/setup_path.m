function projectRoot = setup_path()
%SETUP_PATH Add project folders (src, scripts) to the MATLAB path and
%   return the absolute project root directory. This file must live at
%   the project root; every other script calls setup_path() first so
%   file I/O (dataset_nb_iot.csv, trainedAgent.mat, evalResults.mat,
%   docs/figures, docs/tables) always resolves to the same place
%   regardless of MATLAB's current working directory.

scriptDir   = fileparts(mfilename('fullpath'));
projectRoot = scriptDir;

addpath(genpath(fullfile(projectRoot, 'src')));
addpath(genpath(fullfile(projectRoot, 'scripts')));
addpath(projectRoot);
end
