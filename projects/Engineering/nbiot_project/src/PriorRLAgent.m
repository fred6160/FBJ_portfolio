classdef PriorRLAgent < handle
%PRIORRLAGENT Tabular Q-learning baseline (prior-art RL representative).
%
%   Models the class of RL approaches that appear in recent NB-IoT
%   energy-optimisation literature (Anbazhagan 2024, Arslan 2024) which
%   optimise only PHY-layer parameters (packet size and repetition) using
%   a coarse SNR-only state and a low-dimensional discrete action set.
%
%   State    : (SNR bin)                              -- 6 bins
%   Action   : (packetSize, repetition) on cfg grid   -- |P| * |R|
%   Update   : Q(s,a) <- Q(s,a) + alpha*(r + gamma*max_a'Q(s',a') - Q(s,a))
%
%   Fixed parameters: QPSK modulation, TTI = 4 ms. This deliberately
%   reflects the *non-cross-layer* nature of prior work -- the proposed
%   DQN framework lifts these restrictions.
%
%   Unchanged from the version you were handed. It is compatible as-is
%   with the new src/NBIoTRLEnv.m: it calls reset(env)/step(env, action)
%   using MATLAB's function-call syntax on a handle object, and reads
%   env.ActionTable, both of which NBIoTRLEnv provides with the same
%   shape ([packet, rep, modIdx, tti] columns) that mapToEnvAction below
%   expects.

    properties
        Cfg
        SNRBinsDb  = [-25 -15 -8 -3 3 10 25];   % bin edges
        Q                                       % numStates x numActions
        Alpha      = 0.1
        Epsilon    = 0.1
        ActionGrid                              % numActions x 2 (packet, rep)
        FixedMod   = "QPSK"
        FixedTti   = 4
    end

    methods
        function this = PriorRLAgent(cfg)
            this.Cfg = cfg;
            this.ActionGrid = this.buildActionGrid(cfg);
            nStates = numel(this.SNRBinsDb) - 1;
            this.Q = zeros(nStates, size(this.ActionGrid, 1));
        end

        function train(this, env, episodes)
            % Train via on-policy interaction with the supplied environment.
            gamma = this.Cfg.rl.discountFactor;
            for ep = 1:episodes
                obs = reset(env);
                done = false;
                while ~done
                    s = this.binState(obs);
                    a = this.epsGreedy(s);
                    % Map (packet, rep) to env action index via brute search:
                    envAct = this.mapToEnvAction(env.ActionTable, a);
                    [nextObs, reward, done, ~] = step(env, envAct);
                    sNext = this.binState(nextObs);
                    target = reward + gamma * max(this.Q(sNext, :));
                    this.Q(s, a) = this.Q(s, a) + this.Alpha*(target - this.Q(s, a));
                    obs = nextObs;
                end
            end
        end

        function action = selectAction(this, state, ~)
            s = this.binStateScalar(state.SNRdB);
            [~, a] = max(this.Q(s, :));
            grid = this.ActionGrid(a, :);
            action = struct('packet', grid(1), 'rep', grid(2), ...
                            'mod', this.FixedMod, 'tti', this.FixedTti, ...
                            'name', "PriorRL");
        end
    end

    methods (Access = private)
        function s = binState(this, obs)
            s = this.binStateScalar(obs(1));
        end

        function s = binStateScalar(this, snrDb)
            s = find(snrDb < this.SNRBinsDb(2:end), 1, 'first');
            if isempty(s); s = numel(this.SNRBinsDb) - 1; end
        end

        function a = epsGreedy(this, s)
            if rand() < this.Epsilon
                a = randi(size(this.Q, 2));
            else
                [~, a] = max(this.Q(s, :));
            end
        end

        function envAct = mapToEnvAction(this, envTable, a)
            % Find the env action that matches (packet, rep, QPSK, tti=4).
            grid    = this.ActionGrid(a, :);
            modIdx  = find(strcmp(string(this.Cfg.phy.modulations), this.FixedMod), 1);
            target  = [grid(1), grid(2), modIdx, this.FixedTti];
            diffs   = sum(abs(envTable - target), 2);
            [~, envAct] = min(diffs);
        end
    end

    methods (Static, Access = private)
        function grid = buildActionGrid(cfg)
            P = cfg.phy.packetSizesBytes(:);
            R = cfg.phy.repetitionFactors(:);
            [Pg, Rg] = ndgrid(P, R);
            grid = [Pg(:), Rg(:)];
        end
    end
end
