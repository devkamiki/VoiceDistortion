clear; close all; clc;

inputFile = 'inputfiles/singing-sample.wav';           
outputFile = 'outputs/chorus.wav';

numVoices = 21; % number of chorus voices
pitchShifts = -8.0:2.0:8.0;   % semitones

minDelay = 0.0;   % seconds
maxDelay = 0.1;   % seconds

delays = minDelay + (maxDelay - minDelay) * rand(numVoices,1);


% Quantize delays (group similar ones)
binSize = 0.005;  % 5 ms resolution
delayBins = round(delays / binSize);

% Count occurrences
[uniqueBins, ~, idx] = unique(delayBins);
counts = accumarray(idx, 1);


% STFT params
windowLength = 1024;
overlap = round(0.75 * windowLength);

[x, fs] = audioread(inputFile);
if size(x,2) > 1
    x = mean(x, 2);
end
x = x(:);

y = zeros(size(x));

for v = 1:numVoices

    ps = pitchShifts(v);
    dl = delays(v);

    % Find how many voices share same delay bin
    binIndex = find(uniqueBins == delayBins(v));
    weight = counts(binIndex);   % more voices → stronger

    fprintf('Voice %d | shift = %.2f st | delay = %.3f s | weight = %d \n', ...
            v, ps, dl, weight);

    shifted = pitchShift(x, fs, ps, windowLength, overlap);

    delaySamples = round(dl * fs);

    if delaySamples >= 0
        delayed = [zeros(delaySamples,1); shifted(1:end-delaySamples)];
    else
        delayed = [shifted(-delaySamples+1:end); zeros(-delaySamples,1)];
    end

    % Apply weighting
    y = y + (weight * delayed) / numVoices;
end



y = y / max(abs(y)) * 0.95;
audiowrite(outputFile, y, fs);

sound(y, fs);
