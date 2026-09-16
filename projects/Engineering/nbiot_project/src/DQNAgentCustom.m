classdef DQNAgentCustom < handle
%DQNAGENTCUSTOM Deep Q-Network agent (experience replay + target network)
%   built on top of QNetwork.m. Mirrors the rlDQNAgent-equivalent design
%   described in report Section 3.2.2: epsilon-greedy exploration,
%   experience replay, and target-network soft updates governed by
%   cfg.rl.targetSmoothFactor.
%
%   This is the class that scripts/train_rl_agent.m trains and saves to
%   trainedAgent.mat, and that evaluate_baselines.m / generate_figures.m
%   load back for the "ProposedDQN" policy.

    properties
        Cfg
        Env
        QNet
        TargetNet
        Epsilon
        EpsilonMin      = 0.05
        EpsilonDecay    = 0.995
        Buffer                          % preallocated ring buffer of struct entries
        BufferLen       = 0
        BufferCapacity
        BufferIdx       = 1
    end

    methods
        function this = DQNAgentCustom(cfg, env)
            this.Cfg = cfg;
            this.Env = env;
            this.Epsilon = 0.3;

            obsDim = env.obsDim();
            nAct   = env.numActions();

            % Rough observation normalisation constants (order-of-
            % magnitude, not fitted from data -- adequate for gradient
            % stability with ReLU + Adam on this state space).
            obsMean = [-5; cfg.energy.batteryJ/2; 0.3; 2; 10];
            obsStd  = [15; cfg.energy.batteryJ/2; 0.3; 3; 8];

            this.QNet      = QNetwork(obsDim, 64, nAct, obsMean, obsStd);
            this.TargetNet = this.QNet.copy();

            % cfg.rl.experienceBufferLen (1e6) is impractically large for
            % an in-memory struct array in plain MATLAB; capped to a
            % practical working size.
            this.BufferCapacity = min(cfg.rl.experienceBufferLen, 50000);
            this.Buffer = struct('obs', cell(1, this.BufferCapacity), ...
                                 'action', cell(1, this.BufferCapacity), ...
                                 'reward', cell(1, this.BufferCapacity), ...
                                 'nextObs', cell(1, this.BufferCapacity), ...
                                 'done', cell(1, this.BufferCapacity));
        end

        function a = selectAction(this, obs, greedy)
            if nargin < 3; greedy = false; end
            if ~greedy && rand() < this.Epsilon
                a = randi(this.Env.numActions());
            else
                x = this.QNet.normalize(obs);
                q = this.QNet.forward(x);
                [~, a] = max(q);
            end
        end

        function remember(this, obs, action, reward, nextObs, done)
            idx = this.BufferIdx;
            this.Buffer(idx).obs     = obs;
            this.Buffer(idx).action  = action;
            this.Buffer(idx).reward  = reward;
            this.Buffer(idx).nextObs = nextObs;
            this.Buffer(idx).done    = done;
            this.BufferIdx = mod(idx, this.BufferCapacity) + 1;
            this.BufferLen = min(this.BufferLen + 1, this.BufferCapacity);
        end

        function trainStats = train(this, numEpisodes, verbose)
            if nargin < 3; verbose = true; end
            gamma     = this.Cfg.rl.discountFactor;
            batchSize = min(this.Cfg.rl.miniBatchSize, 64);
            tau       = this.Cfg.rl.targetSmoothFactor;

            episodeReward = zeros(numEpisodes, 1);
            avgReward     = zeros(numEpisodes, 1);

            for ep = 1:numEpisodes
                obs = this.Env.reset();
                done = false;
                totalR = 0;

                while ~done
                    a = this.selectAction(obs);
                    [nextObs, r, done, ~] = this.Env.step(a);
                    this.remember(obs, a, r, nextObs, done);
                    obs = nextObs;
                    totalR = totalR + r;

                    if this.BufferLen >= batchSize
                        this.learnFromBatch(batchSize, gamma);
                        this.TargetNet.softUpdateFrom(this.QNet, tau);
                    end
                end

                this.Epsilon = max(this.EpsilonMin, this.Epsilon * this.EpsilonDecay);
                episodeReward(ep) = totalR;
                avgReward(ep) = mean(episodeReward(max(1, ep-9):ep));

                if verbose && (mod(ep, 10) == 0 || ep == 1 || ep == numEpisodes)
                    fprintf('  episode %4d/%4d | reward %10.2f | avg10 %10.2f | eps %.3f\n', ...
                        ep, numEpisodes, totalR, avgReward(ep), this.Epsilon);
                end
            end

            trainStats = table((1:numEpisodes)', episodeReward, avgReward, ...
                'VariableNames', {'Episode', 'EpisodeReward', 'AverageReward'});
        end

        function learnFromBatch(this, batchSize, gamma)
            idx = randi(this.BufferLen, 1, batchSize);
            samples = this.Buffer(idx);

            obsMat     = [samples.obs];
            nextObsMat = [samples.nextObs];
            actions    = [samples.action];
            rewards    = [samples.reward];
            dones      = [samples.done];

            X     = this.QNet.normalize(obsMat);
            Xnext = this.TargetNet.normalize(nextObsMat);

            qNext    = this.TargetNet.forward(Xnext);
            maxQNext = max(qNext, [], 1);

            targetQ = rewards + gamma * maxQNext .* (~dones);

            this.QNet.trainStep(X, actions, targetQ);
        end
    end
end
