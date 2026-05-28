function [outputSignal, Fs] = chorus(inputFile)
if nargin < 1
    inputFile = 'inputfiles/singing-sample.wav';  % fallback
end

outputFile = 'outputs/chorus_warm_thick.wav';
% Small pitch detune for natural thick chorus
pitchShifts = [-9,-8, -0.22, -0.10, 0, 0.10, 0.22, 0.35];   % semitones

% Manual delays, same number as pitchShifts
% Avoid 0 second delay to reduce comb filtering
delays = [0.008, 0.012, 0.016, 0.020, 0.024, 0.028, 0.032];  % seconds

numVoices = length(pitchShifts);

if length(delays) ~= numVoices
    error('The number of delays must match the number of pitch shifts.');
end


binSize = 0.004;     % 4 ms resolution
delayBins = round(delays(:) / binSize);

[uniqueBins, ~, idx] = unique(delayBins);
counts = accumarray(idx, 1);

% STFT parameters
windowLength = 2048;                    % larger window = smoother pitch shift
overlap = round(0.75 * windowLength);

% Convolution settings
reverbTime = 0.28;       % shorter, smoother room
wetMix = 0.10;           % less reverb, less metallic
dryMix = 0.90;

% Direct dry voice amount
directMix = 0.35;        % keep original voice for clarity/thickness
chorusMix = 0.65;

% reading audio input and normalization

[x, fs] = audioread(inputFile);

if size(x, 2) > 1
    x = mean(x, 2);
end

x = x(:);
x = x / max(abs(x) + eps);

y = zeros(size(x));


delayTable = table((1:numVoices)', pitchShifts(:), delays(:), ...
    round(delays(:) * fs), delayBins(:), counts(idx), ...
    'VariableNames', {'Voice', 'PitchShift_semitones', ...
    'Delay_seconds', 'Delay_samples', 'DelayBin', 'OverlapCount'});

disp(delayTable);

% chorus processing with weighted overlap-add based on delay bin counts

for v = 1:numVoices

    ps = pitchShifts(v);
    dl = delays(v);

    binIndex = find(uniqueBins == delayBins(v));
    overlapCount = counts(binIndex);

    % Softer strengthening
    weight = sqrt(overlapCount);

    fprintf('Voice %d | shift = %.2f st | delay = %.4f s | samples = %d | overlap = %d | weight = %.2f\n', ...
            v, ps, dl, round(dl * fs), overlapCount, weight);

    shifted = pitchShift(x, fs, ps, windowLength, overlap);

    delaySamples = round(dl * fs);

    if delaySamples >= length(shifted)
        warning('Delay for voice %d is longer than signal. Skipping.', v);
        continue;
    end

    delayed = [zeros(delaySamples, 1); shifted(1:end-delaySamples)];

    % Smooth fade-in to avoid clicking/stuttering
    fadeLength = round(0.01 * fs);  % 10 ms
    fadeLength = min(fadeLength, length(delayed));
    fade = linspace(0, 1, fadeLength)';
    delayed(1:fadeLength) = delayed(1:fadeLength) .* fade;

    y = y + (weight * delayed) / numVoices;

end

% Mix original dry signal back in for natural thickness
y = chorusMix * y + directMix * x;

% Normalize before convolution
y = y / max(abs(y) + eps) * 0.95;

% ============================================================
% CONVOLUTION NATURALIZATION
% ============================================================

h = createSmoothImpulseResponse(fs, reverbTime);

y_conv = conv(y, h, 'same');

y_natural = dryMix * y + wetMix * y_conv;

% ============================================================
% WARM / THICK EQ
% ============================================================

y_thick = makeWarmAndThick(y_natural, fs);

% Final normalization
y_thick = y_thick / max(abs(y_thick) + eps) * 0.95;

% ============================================================
% SAVE AND PLAY
% ============================================================

audiowrite(outputFile, y_thick, fs);
sound(y_thick, fs);

fprintf('\nOutput saved to: %s\n', outputFile);

function h = createSmoothImpulseResponse(fs, reverbTime)

    irLength = round(reverbTime * fs);
    t = (0:irLength-1)' / fs;

    % Smooth exponential decay
    decay = exp(-7 * t / reverbTime);

    h = zeros(irLength, 1);
    h(1) = 1;

    % Softer early reflections
    earlyReflectionTimes = [0.011, 0.019, 0.031, 0.044];
    earlyReflectionGains = [0.22, 0.16, 0.10, 0.07];

    for k = 1:length(earlyReflectionTimes)
        idx = round(earlyReflectionTimes(k) * fs) + 1;

        if idx <= irLength
            h(idx) = h(idx) + earlyReflectionGains(k);
        end
    end

    % Smooth diffuse tail
    noiseTail = randn(irLength, 1) .* decay;

    % Low-pass the tail to remove harsh metallic high frequencies
    [b, a] = butter(2, 3500 / (fs / 2), 'low');
    noiseTail = filter(b, a, noiseTail);

    h = h + 0.025 * noiseTail;

    h = h / max(abs(h) + eps);

end

function y = makeWarmAndThick(x, fs)

    x = x(:);
    N = length(x);

    X = fft(x);

    % Frequency vector
    f = (0:N-1)' * fs / N;

    % Mirror frequency for negative side
    fMirror = min(f, fs - f);

    gain = ones(N, 1);

    % Add body: 120–350 Hz
    bodyBand = (fMirror >= 120) & (fMirror <= 350);
    gain(bodyBand) = gain(bodyBand) * 1.35;

    % Add warmth: 350–800 Hz
    warmBand = (fMirror > 350) & (fMirror <= 800);
    gain(warmBand) = gain(warmBand) * 1.15;

    % Reduce harshness: above 3500 Hz
    harshBand = (fMirror >= 3500);
    gain(harshBand) = gain(harshBand) * 0.82;

    % Slightly reduce very low rumble below 60 Hz
    rumbleBand = (fMirror < 60);
    gain(rumbleBand) = gain(rumbleBand) * 0.70;

    Y = X .* gain;

    y = real(ifft(Y));

end

outputSignal = audioread('outputs/chorus.wav');   
[~, Fs] = audioread(inputFile);   
end