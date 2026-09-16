classdef NBIoTRLEnv < handle
%NBIOTRLENV Reinforcement-learning environment for NB-IoT cross-layer
%   packet configuration (packet size, repetition, modulation, TTI).
%
%   *** THIS FILE WAS MISSING FROM THE INHERITED PROJECT ***
%   evaluate_baselines.m / generate_figures.m / PriorRLAgent.m all
%   reference NBIoTRLEnv (via reset(env), step(env, action),
%   env.ActionTable), but no class definition existed anywhere in the
%   uploaded files. This is a from-scratch implementation built to match
%   every call site exactly, and to match the state/action/reward design
%   described in report Section 3.2.1 and Figure 2.1:
%
%   State observation (5-dim, matches "Input layer: 5 neurons" in
%   Section 3.2.2):
%       [SNRdB, ResidualEnergyJ, RecentBLER, Retransmissions, QueueLen]
%
%   Action: a discrete index into ActionTable, a full grid of
%       (packetSizeBytes, repetitionFactor, modulationIndex, ttiMs).
%
%   Reward (implements eqn. 3.5's description -- energy efficiency gain,
%   reliability, latency penalty, tunable weights alpha1/alpha2/alpha3 --
%   the report does not give the exact closed-form equation, so this is
%   an explicit, documented interpretation of it):
%
%       R = alpha1 * energyEfficiencyGain
%         - alpha2 * unreliabilityPenalty
%         - alpha3 * latencyMs
%         - qosViolationPenalty
%
%   where energyEfficiencyGain = refEnergyJ / (attemptEnergyJ + eps),
%   unreliabilityPenalty = BLER, and qosViolationPenalty is a fixed
%   penalty applied whenever the QoS reliability or latency thresholds
%   (cfg.qos.minReliability / cfg.qos.maxLatencyMs) are violated.

    properties
        Cfg
        EnvType             (1,1) string = "urban"
        ActionTable                          % numActions x 4 = [packet, rep, modIdx, tti]
        MaxSteps            (1,1) double = 200
        StepCount           (1,1) double = 0
        MarkovStateIdx      (1,1) double = 1
        State                                % struct: SNRdB, ResidualEnergyJ, RecentBLER, Retransmissions, QueueLen
        RefEnergyJ          (1,1) double      % normalisation constant for reward shaping
        QosViolationPenalty (1,1) double = 5
    end

    methods
        function this = NBIoTRLEnv(cfg, envType)
            if nargin > 1 && ~isempty(envType)
                this.EnvType = string(envType);
            elseif isfield(cfg.env, 'active')
                this.EnvType = string(cfg.env.active);
            end
            this.Cfg = cfg;
            this.MaxSteps = cfg.rl.maxStepsPerEpisode;
            this.ActionTable = this.buildActionTable(cfg);

            % Reference energy: a fixed mid-range attempt (QPSK, 80 B,
            % R=4, TTI=4ms) at bler=0.5, used purely to keep the reward's
            % energy term at an O(1) scale regardless of absolute units.
            [~, refDet] = energyModel(cfg, 80, 4, 0.5, "QPSK", 4);
            this.RefEnergyJ = max(refDet.energyAttemptJ, eps);
        end

        function obs = reset(this)
            this.StepCount = 0;
            this.MarkovStateIdx = 1;
            [snrDb, ch] = channelSnapshot(this.Cfg, this.EnvType, this.MarkovStateIdx);
            if isfield(ch, 'markovStateIdx'); this.MarkovStateIdx = ch.markovStateIdx; end

            this.State = struct( ...
                'SNRdB',           snrDb, ...
                'ResidualEnergyJ', this.Cfg.energy.batteryJ, ...
                'RecentBLER',      0.1, ...
                'Retransmissions', 0, ...
                'QueueLen',        10);

            obs = this.observe();
        end

        function [obs, reward, done, info] = step(this, actionIdx)
            actionIdx = max(1, min(round(actionIdx), size(this.ActionTable, 1)));
            row = this.ActionTable(actionIdx, :);
            packet = row(1); rep = row(2); modIdx = row(3); tti = row(4);
            modName = string(this.Cfg.phy.modulations{modIdx});

            bler = blerModel(this.State.SNRdB, modName, packet, rep, this.Cfg);
            [energyJ, det] = energyModel(this.Cfg, packet, rep, bler, modName, tti);

            % --- Reward ---
            w = this.Cfg.rl.rewardWeights;
            energyEfficiencyGain = this.RefEnergyJ / (det.energyAttemptJ + eps);
            unreliabilityPenalty = bler;
            qosPenalty = 0;
            if (1 - bler) < this.Cfg.qos.minReliability || det.latencyMs > this.Cfg.qos.maxLatencyMs
                qosPenalty = this.QosViolationPenalty;
            end
            reward = w.alpha1 * energyEfficiencyGain ...
                   - w.alpha2 * unreliabilityPenalty ...
                   - w.alpha3 * det.latencyMs ...
                   - qosPenalty;

            % --- Transition the channel and bookkeeping state ---
            [snrDb, ch] = channelSnapshot(this.Cfg, this.EnvType, this.MarkovStateIdx);
            if isfield(ch, 'markovStateIdx'); this.MarkovStateIdx = ch.markovStateIdx; end

            this.State.SNRdB           = snrDb;
            this.State.RecentBLER      = bler;
            this.State.Retransmissions = max(round(bler * 10), 0);
            this.State.ResidualEnergyJ = max(this.State.ResidualEnergyJ - det.energyAttemptJ, 0);
            this.State.QueueLen        = max(this.State.QueueLen - 1 + randi([0 2]), 0);

            this.StepCount = this.StepCount + 1;
            done = (this.StepCount >= this.MaxSteps) || (this.State.ResidualEnergyJ <= 0);

            obs = this.observe();
            info = struct('bler', bler, 'energyJ', energyJ, 'details', det, ...
                          'action', struct('packet', packet, 'rep', rep, ...
                                           'mod', modName, 'tti', tti));
        end

        function obs = observe(this)
            obs = [this.State.SNRdB; this.State.ResidualEnergyJ; ...
                  this.State.RecentBLER; this.State.Retransmissions; ...
                  this.State.QueueLen];
        end

        function n = numActions(this)
            n = size(this.ActionTable, 1);
        end

        function n = obsDim(~)
            n = 5;
        end
    end

    methods (Static, Access = private)
        function grid = buildActionTable(cfg)
            % Column order [packet, rep, modIdx, tti] matches the table
            % built inline by makeDqnSelector in the original
            % generate_figures script, and what PriorRLAgent.mapToEnvAction
            % expects from env.ActionTable.
            P = cfg.phy.packetSizesBytes(:);
            R = cfg.phy.repetitionFactors(:);
            M = (1:numel(cfg.phy.modulations))';
            Ttab = cfg.mac.ttiMs(:);
            grid = zeros(numel(P)*numel(R)*numel(M)*numel(Ttab), 4);
            row = 1;
            for ip = 1:numel(P)
                for ir = 1:numel(R)
                    for im = 1:numel(M)
                        for it = 1:numel(Ttab)
                            grid(row, :) = [P(ip), R(ir), M(im), Ttab(it)];
                            row = row + 1;
                        end
                    end
                end
            end
        end
    end
end
