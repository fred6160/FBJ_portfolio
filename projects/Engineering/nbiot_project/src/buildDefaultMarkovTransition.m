function P = buildDefaultMarkovTransition(numStates)
%BUILDDEFAULTMARKOVTRANSITION Create a near-diagonal Markov transition matrix.

arguments
    numStates (1,1) double {mustBeInteger, mustBePositive}
end

P = zeros(numStates, numStates);
selfProb = 0.7;
neighborProb = 0.15;

for i = 1:numStates
    P(i,i) = selfProb;
    if i > 1
        P(i,i-1) = neighborProb;
    end
    if i < numStates
        P(i,i+1) = neighborProb;
    end
end

% Normalize rows
P = P ./ sum(P,2);
end
