clear; close all; clc;

inputFile = 'inputfiles/singing-sample.wav';           
outputFile = 'outputs/chorus.wav';

numVoices = 7;  % number of chorus voices
pitchShifts = [-6, -4, -8, 0, 4, 6, 8];   % semitones,半音
delays = [0.02, 0.03,0, 0.04, 0.06, 0.05, 0.01];     % seconds

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
    fprintf('Processing voice %d (shift: %.1f semitones)\n', v, pitchShifts(v));
    
    shifted = pitchShift(x, fs, pitchShifts(v), windowLength, overlap);
    
    delaySamples = round(delays(v) * fs);
    delayed = [zeros(delaySamples, 1); shifted(1:end-delaySamples)];
    
    y = y + delayed / numVoices;
end


y = y / max(abs(y)) * 0.95;
audiowrite(outputFile, y, fs);

sound(y, fs);
