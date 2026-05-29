function [outputSignal, Fs] = chorusOrig(inputFile)
if nargin < 1
    inputFile = 'inputfiles/singing2.wav';
end

outputFile = 'outputs/chorusOrig.wav';

numVoices = 21;
pitchShifts = -8.0:0.8:8.0;  % semitones
delays = 0.1:-0.005:0;        % seconds

windowLength = 1024;
overlap = round(0.75 * windowLength);

[x, fs] = audioread(inputFile);
if size(x, 2) > 1
    x = mean(x, 2);
end
x = x(:);

y = zeros(size(x));

for v = 1:numVoices
    fprintf('Processing voice %d (shift: %.1f semitones)\n', v, pitchShifts(v));

    shifted = pitchShift(x, fs, pitchShifts(v), windowLength, overlap);

    delaySamples = round(delays(v) * fs);
    if delaySamples >= 0
        delayed = [zeros(delaySamples, 1); shifted(1:end-delaySamples)];
    else
        delayed = [shifted(-delaySamples+1:end); zeros(-delaySamples, 1)];
    end

    y = y + delayed / numVoices;
end

y = y / max(abs(y)) * 0.95;
audiowrite(outputFile, y, fs);
sound(y, fs);

outputSignal = y;
Fs = fs;
end
