function cfg = getDefaultConfig()
%GETDEFAULTCONFIG Default configuration for NB-IoT simulation and RL.
%   Returns a struct with environment, channel, PHY/MAC, energy, and RL
%   parameters. Channel/scenario parameters follow 3GPP TR 45.820
%   (Cellular IoT) NB-IoT deployment scenarios with three coverage classes:
%     - "urban"       : MCL = 144 dB (normal coverage)
%     - "rural"       : MCL = 154 dB (robust / extended coverage)
%     - "deep_indoor" : MCL = 164 dB (extreme coverage extension)
%
%   NOTE: Table 3.1 in the report lists repetition factors "1-32". This
%   config (and the rest of the codebase) uses [1 2 4 8 16 32 64 128]
%   per NPUSCH's actual N_Rep range. Recommend updating Table 3.1 to
%   match the code (the code is the source of truth the figures/tables
%   are generated from).

cfg = struct();

% ---- Reproducibility ----
cfg.seed = 20260617;  % global RNG seed for deterministic experiments

% ---- Environment / scenarios (3GPP TR 45.820, Table 5-1) ----
cfg.env.types  = {"urban", "rural", "deep_indoor"};
cfg.env.active = "urban";

% Per-scenario channel parameters
%   pathLossExp     : log-distance exponent n
%   shadowingStdDb  : log-normal shadowing std (sigma)
%   penetrationDb   : extra building penetration loss (deep-indoor)
%   mclDb           : target Maximum Coupling Loss (TR 45.820)
%   distanceMeters  : nominal device-to-eNB distance
%   fadingModel     : "rayleigh" | "rician"
cfg.env.urban       = struct('pathLossExp', 3.76, 'shadowingStdDb',  8, ...
                             'penetrationDb',  0, 'mclDb', 144, ...
                             'distanceMeters', 1000, 'fadingModel', "rayleigh");
cfg.env.rural       = struct('pathLossExp', 3.50, 'shadowingStdDb',  6, ...
                             'penetrationDb',  0, 'mclDb', 154, ...
                             'distanceMeters', 5000, 'fadingModel', "rician");
cfg.env.deep_indoor = struct('pathLossExp', 4.00, 'shadowingStdDb', 10, ...
                             'penetrationDb', 20, 'mclDb', 164, ...
                             'distanceMeters', 1000, 'fadingModel', "rayleigh");

% ---- Channel / link budget (3GPP-aligned) ----
cfg.channel.fcHz          = 900e6;
cfg.channel.txPowerdBm    = 23;    % NB-IoT UE max uplink (Cat-NB1)
cfg.channel.noiseFiguredB = 5;
cfg.channel.bandwidthHz   = 180e3;
cfg.channel.pathLossExp   = 3.5;   % fallback if env unknown
cfg.channel.shadowingStdDb = 8;
cfg.channel.distanceMeters = 1000;

% Markov SNR model (slow temporal correlation, ZERO-MEAN fluctuation
% layer applied on top of the scenario's physical mean SNR -- see
% channelSnapshot.m fix notes for why this changed).
cfg.channel.useMarkov         = true;
cfg.channel.markovStatesDb    = [-18 -12 -6 0 6 12];
cfg.channel.markovTransition  = []; % auto-built if empty

% ---- PHY / MAC (NB-IoT) ----
cfg.phy.packetSizesBytes  = [20 40 80 160 320];
cfg.phy.modulations       = {"BPSK", "QPSK"};
cfg.phy.repetitionFactors = [1 2 4 8 16 32 64 128];   % NPUSCH N_Rep up to 128
cfg.mac.ttiMs             = [1 2 4 8 16];

% Simplified NPUSCH timing
cfg.phy.useLTEModel       = false;
cfg.phy.subcarriers       = 12;
cfg.phy.symbolsPerSubframe = 14;
cfg.phy.codeRate          = 0.5;
cfg.phy.codingGainDbPerDoubling = 1.5;  % effective coding gain per rep doubling

% eNB defaults for LTE Toolbox path (only used if useLTEModel = true)
cfg.enb = struct('NNCellID', 0, 'NFrame', 0, 'NSubframe', 0, ...
                 'NBULSubcarrierSpacing', '15kHz');

% ---- Energy model (Cat-NB1 power consumption, rough Quectel BC95 figures) ----
cfg.energy.txPowerW    = 0.50;   % @23 dBm UL (PA + RF chain)
cfg.energy.rxPowerW    = 0.08;
cfg.energy.procPowerW  = 0.02;
cfg.energy.idlePowerW  = 0.003;
cfg.energy.batteryJ    = 5400;   % 5 Wh budget (approx. AA-class)

% FIX (audit): explicit per-packet energy cap. Without this, energyModel
% divides by a successProb clamp near BLER=1 and can report a single
% packet costing MORE energy than the device's entire battery budget --
% a modeling artifact, not a real result. See energyModel.m.
cfg.energy.maxEnergyPerPacketJ = cfg.energy.batteryJ;

% ---- RL (DQN) ----
cfg.rl.discountFactor      = 0.99;
cfg.rl.sampleTime          = 1;
cfg.rl.maxStepsPerEpisode  = 200;
cfg.rl.maxEpisodes         = 500;
cfg.rl.miniBatchSize       = 256;
cfg.rl.experienceBufferLen = 1e6;
cfg.rl.targetSmoothFactor  = 1e-3;
cfg.rl.learningRate        = 1e-3;

% Reward weights (energy efficiency, reliability, latency penalty)
cfg.rl.rewardWeights = struct('alpha1', 1.0, 'alpha2', 2.0, 'alpha3', 1e-3);

% ---- QoS constraints ----
cfg.qos.maxLatencyMs    = 2000;   % NB-IoT typical NRT deadline
cfg.qos.minReliability  = 0.95;
cfg.qos.minThroughputBps = 100;

end
