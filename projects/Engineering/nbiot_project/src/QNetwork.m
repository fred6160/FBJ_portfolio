classdef QNetwork < handle
%QNETWORK Minimal fully-connected Q-network (inputDim -> 64 -> 64 ->
%   numActions), implemented in plain MATLAB matrix operations (manual
%   forward/backward pass + Adam optimiser). No Deep Learning Toolbox or
%   Reinforcement Learning Toolbox dependency.
%
%   WHY A CUSTOM NETWORK: the report (Section 3.2.2) describes using
%   rlDQNAgent / rlQValueRepresentation / featureInputLayer / adamupdate
%   from MATLAB's Reinforcement Learning + Deep Learning Toolboxes.
%   Since toolbox availability on your machine couldn't be confirmed,
%   this project ships a self-contained equivalent so the whole pipeline
%   runs with base MATLAB only. Architecture matches the report's stated
%   design: "Hidden layers: 64 neurons each with ReLU activation."
%   If you do have both toolboxes licensed, you can swap this class out
%   for rlDQNAgent without changing NBIoTRLEnv or any evaluation script,
%   since DQNAgentCustom only needs selectAction(obs, greedy) and
%   env.ActionTable to interoperate with the rest of the pipeline.

    properties
        W1; b1; W2; b2; W3; b3
        mW1; vW1; mb1; vb1
        mW2; vW2; mb2; vb2
        mW3; vW3; mb3; vb3
        t = 0
        LearningRate = 1e-3
        Beta1 = 0.9
        Beta2 = 0.999
        Eps = 1e-8
        ObsMean
        ObsStd
    end

    methods
        function this = QNetwork(inputDim, hiddenDim, numActions, obsMean, obsStd)
            initScale = @(nIn) sqrt(2/nIn);
            this.W1 = randn(hiddenDim, inputDim)   * initScale(inputDim);
            this.b1 = zeros(hiddenDim, 1);
            this.W2 = randn(hiddenDim, hiddenDim)  * initScale(hiddenDim);
            this.b2 = zeros(hiddenDim, 1);
            this.W3 = randn(numActions, hiddenDim) * initScale(hiddenDim);
            this.b3 = zeros(numActions, 1);

            this.mW1 = zeros(size(this.W1)); this.vW1 = zeros(size(this.W1));
            this.mb1 = zeros(size(this.b1)); this.vb1 = zeros(size(this.b1));
            this.mW2 = zeros(size(this.W2)); this.vW2 = zeros(size(this.W2));
            this.mb2 = zeros(size(this.b2)); this.vb2 = zeros(size(this.b2));
            this.mW3 = zeros(size(this.W3)); this.vW3 = zeros(size(this.W3));
            this.mb3 = zeros(size(this.b3)); this.vb3 = zeros(size(this.b3));

            this.ObsMean = obsMean(:);
            this.ObsStd  = max(obsStd(:), eps);
        end

        function x = normalize(this, obs)
            x = (obs - this.ObsMean) ./ this.ObsStd;
        end

        function [q, cache] = forward(this, X)
            % X: inputDim x batch (already normalised)
            Z1 = this.W1 * X + this.b1;   A1 = max(Z1, 0);
            Z2 = this.W2 * A1 + this.b2;  A2 = max(Z2, 0);
            Z3 = this.W3 * A2 + this.b3;  % linear output = Q-values
            q = Z3;
            cache = struct('X', X, 'Z1', Z1, 'A1', A1, 'Z2', Z2, 'A2', A2);
        end

        function trainStep(this, X, actionIdx, targetQ)
            % X: inputDim x batch (already normalised)
            % actionIdx: 1 x batch (1-indexed chosen action per sample)
            % targetQ: 1 x batch (TD target for the chosen action)
            batch = size(X, 2);
            [q, cache] = this.forward(X);

            dZ3 = zeros(size(q));
            linIdx = sub2ind(size(q), actionIdx, 1:batch);
            dZ3(linIdx) = (q(linIdx) - targetQ) / batch;   % MSE gradient, chosen action only

            dW3 = dZ3 * cache.A2';
            db3 = sum(dZ3, 2);

            dA2 = this.W3' * dZ3;
            dZ2 = dA2 .* (cache.Z2 > 0);
            dW2 = dZ2 * cache.A1';
            db2 = sum(dZ2, 2);

            dA1 = this.W2' * dZ2;
            dZ1 = dA1 .* (cache.Z1 > 0);
            dW1 = dZ1 * cache.X';
            db1 = sum(dZ1, 2);

            this.t = this.t + 1;
            [this.W1, this.mW1, this.vW1] = this.adamUpdate(this.W1, dW1, this.mW1, this.vW1);
            [this.b1, this.mb1, this.vb1] = this.adamUpdate(this.b1, db1, this.mb1, this.vb1);
            [this.W2, this.mW2, this.vW2] = this.adamUpdate(this.W2, dW2, this.mW2, this.vW2);
            [this.b2, this.mb2, this.vb2] = this.adamUpdate(this.b2, db2, this.mb2, this.vb2);
            [this.W3, this.mW3, this.vW3] = this.adamUpdate(this.W3, dW3, this.mW3, this.vW3);
            [this.b3, this.mb3, this.vb3] = this.adamUpdate(this.b3, db3, this.mb3, this.vb3);
        end

        function [Wnew, m, v] = adamUpdate(this, W, dW, m, v)
            m = this.Beta1 * m + (1 - this.Beta1) * dW;
            v = this.Beta2 * v + (1 - this.Beta2) * (dW .^ 2);
            mHat = m / (1 - this.Beta1 ^ this.t);
            vHat = v / (1 - this.Beta2 ^ this.t);
            Wnew = W - this.LearningRate * mHat ./ (sqrt(vHat) + this.Eps);
        end

        function net = copy(this)
            net = QNetwork(size(this.W1, 2), size(this.W1, 1), size(this.W3, 1), ...
                           this.ObsMean, this.ObsStd);
            net.W1 = this.W1; net.b1 = this.b1;
            net.W2 = this.W2; net.b2 = this.b2;
            net.W3 = this.W3; net.b3 = this.b3;
        end

        function softUpdateFrom(this, source, tau)
            this.W1 = tau*source.W1 + (1-tau)*this.W1;
            this.b1 = tau*source.b1 + (1-tau)*this.b1;
            this.W2 = tau*source.W2 + (1-tau)*this.W2;
            this.b2 = tau*source.b2 + (1-tau)*this.b2;
            this.W3 = tau*source.W3 + (1-tau)*this.W3;
            this.b3 = tau*source.b3 + (1-tau)*this.b3;
        end
    end
end
