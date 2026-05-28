clear; close all; clc;

% ============================================================
% INPUT / OUTPUT
% ============================================================

inputFile = 'inputfiles/voice-sample.wav';
outputFile = 'outputs/gender_style_converted.wav';

% Choose target style:
% "feminine"  -> brighter / higher
% "masculine" -> deeper / lower
targetStyle = "feminine";

% Create output folder if it does not exist
if ~exist('outputs', 'dir')
    mkdir('outputs');
end

% ============================================================
% READ AUDIO
% ============================================================

[x, fs] = audioread(inputFile);

% Convert stereo to mono
if size(x, 2) > 1
    x = mean(x, 2);
end

x = x(:);
x = x / max(abs(x) + eps);

fprintf('Input length: %d samples\n', length(x));
fprintf('Sampling rate: %d Hz\n', fs);
fprintf('Input duration: %.2f seconds\n', length(x) / fs);

% ============================================================
% PARAMETERS
% ============================================================

windowLength = 2048;
hopSize = windowLength / 4;   % 75 percent overlap

switch targetStyle

    case "feminine"
        pitchShiftSemitones = 2.5;
        formantScale = 1.08;

    case "masculine"
        pitchShiftSemitones = -3.0;
        formantScale = 0.90;

    otherwise
        error('targetStyle must be "feminine" or "masculine".');
end

fprintf('Target style: %s\n', targetStyle);
fprintf('Pitch shift: %.2f semitones\n', pitchShiftSemitones);
fprintf('Formant scale: %.2f\n', formantScale);

% ============================================================
% PROCESSING
% ============================================================

% Step 1: FFT-based pitch shift
y_pitch = fftPitchShiftOLA(x, fs, pitchShiftSemitones, windowLength, hopSize);

fprintf('After pitch shift: max = %.8f, RMS = %.8f\n', ...
    max(abs(y_pitch)), rms(y_pitch));

if max(abs(y_pitch)) < 1e-6
    error('Pitch shift output is almost silent. Check FFT pitch shifting stage.');
end

% Step 2: safer formant/tone shifting
y_formant = safeFormantShiftSTFT(y_pitch, fs, formantScale, windowLength, hopSize);

fprintf('After formant shift: max = %.8f, RMS = %.8f\n', ...
    max(abs(y_formant)), rms(y_formant));

if max(abs(y_formant)) < 1e-6
    warning('Formant shift output is very quiet. Using pitch-shifted signal instead.');
    y_formant = y_pitch;
end

% Step 3: smooth EQ for more natural tone
y_final = smoothVoiceEQ(y_formant, fs, targetStyle);

fprintf('After EQ: max = %.8f, RMS = %.8f\n', ...
    max(abs(y_final)), rms(y_final));

% Safety normalization
if max(abs(y_final)) < 1e-6
    error('Final output is almost silent. Processing failed.');
end

y_final = y_final / max(abs(y_final) + eps) * 0.95;

% ============================================================
% SAVE AND PLAY
% ============================================================

audiowrite(outputFile, y_final, fs);
sound(y_final, fs);

fprintf('Output saved to: %s\n', outputFile);

% Optional waveform comparison
figure;
subplot(2,1,1);
plot(x);
title('Original Audio');
xlabel('Sample');
ylabel('Amplitude');

subplot(2,1,2);
plot(y_final);
title('Processed Audio');
xlabel('Sample');
ylabel('Amplitude');

% ============================================================
% FUNCTION 1: FFT-BASED PITCH SHIFT WITH OVERLAP-ADD
% ============================================================

function y = fftPitchShiftOLA(x, fs, semitones, windowLength, hopSize)

    x = x(:);
    N = length(x);

    alpha = 2^(semitones / 12);

    win = hamming(windowLength, 'periodic');

    numFrames = floor((N - windowLength) / hopSize) + 1;

    y = zeros(N, 1);
    winSum = zeros(N, 1);

    halfN = floor(windowLength / 2);

    for frameIdx = 1:numFrames

        startIdx = (frameIdx - 1) * hopSize + 1;
        frameRange = startIdx:startIdx + windowLength - 1;

        frame = x(frameRange);
        frameWindowed = frame .* win;

        X = fft(frameWindowed);
        Y = zeros(size(X));

        % Move positive-frequency bins
        for k = 2:halfN

            newK = round((k - 1) * alpha) + 1;

            if newK >= 2 && newK <= halfN
                Y(newK) = Y(newK) + X(k);
            end

        end

        % Preserve DC
        Y(1) = X(1);

        % Preserve Nyquist bin approximately
        Y(halfN + 1) = real(Y(halfN + 1));

        % Rebuild negative frequencies for real output
        for k = 2:halfN
            Y(windowLength - k + 2) = conj(Y(k));
        end

        frameOut = real(ifft(Y));

        % Synthesis window
        frameOut = frameOut .* win;

        % Overlap-add
        y(frameRange) = y(frameRange) + frameOut;
        winSum(frameRange) = winSum(frameRange) + win.^2;

    end

    % Normalize overlap-add window energy
    valid = winSum > 1e-8;
    y(valid) = y(valid) ./ winSum(valid);

    % Match input level roughly
    if max(abs(y)) > 1e-8
        y = y / max(abs(y) + eps) * max(abs(x));
    end

    y = real(y);

end

% ============================================================
% FUNCTION 2: SAFE FORMANT SHIFT USING STFT ENVELOPE
% ============================================================

function y = safeFormantShiftSTFT(x, fs, formantScale, windowLength, hopSize)

    x = x(:);
    N = length(x);

    overlap = windowLength - hopSize;
    win = hamming(windowLength, 'periodic');

    [S, ~, ~] = stft(x, fs, ...
        'Window', win, ...
        'OverlapLength', overlap, ...
        'FFTLength', windowLength, ...
        'Centered', false);

    mag = abs(S);
    phase = angle(S);

    numBins = size(S, 1);
    numFrames = size(S, 2);

    magNew = zeros(size(mag));

    binIndex = (1:numBins)';

    smoothBins = 45;

    for n = 1:numFrames

        currentMag = mag(:, n);
        logMag = log(currentMag + 1e-8);

        % Smooth spectral envelope
        envelope = movmean(logMag, smoothBins);

        % Fine harmonic structure
        detail = logMag - envelope;

        % Shift spectral envelope
        sourceIndex = (binIndex - 1) / formantScale + 1;

        % Clamp instead of extrapolating
        sourceIndex(sourceIndex < 1) = 1;
        sourceIndex(sourceIndex > numBins) = numBins;

        warpedEnvelope = interp1(binIndex, envelope, sourceIndex, 'linear');

        newLogMag = warpedEnvelope + detail;

        % Limit extreme changes to avoid silence or spikes
        gainLog = newLogMag - logMag;

        maxBoost = log(2.0);
        maxCut = log(0.35);

        gainLog = min(max(gainLog, maxCut), maxBoost);

        stableLogMag = logMag + gainLog;

        magNew(:, n) = exp(stableLogMag);

    end

    Y = magNew .* exp(1i * phase);

    y = istft(Y, fs, ...
        'Window', win, ...
        'OverlapLength', overlap, ...
        'FFTLength', windowLength, ...
        'Centered', false);

    y = matchLength(y, N);
    y = real(y);

end

% ============================================================
% FUNCTION 3: SMOOTH VOICE EQ
% ============================================================

function y = smoothVoiceEQ(x, fs, targetStyle)

    x = x(:);
    N = length(x);

    X = fft(x);

    f = (0:N-1)' * fs / N;
    fMirror = min(f, fs - f);

    gain = ones(N, 1);

    switch targetStyle

        case "feminine"

            % Reduce low rumble
            gain(fMirror < 100) = gain(fMirror < 100) * 0.75;

            % Add some brightness
            gain(fMirror >= 2500 & fMirror <= 7000) = ...
                gain(fMirror >= 2500 & fMirror <= 7000) * 1.12;

            % Avoid harsh high noise
            gain(fMirror > 9000) = gain(fMirror > 9000) * 0.85;

        case "masculine"

            % Add body
            gain(fMirror >= 100 & fMirror <= 300) = ...
                gain(fMirror >= 100 & fMirror <= 300) * 1.30;

            % Add warmth
            gain(fMirror > 300 & fMirror <= 800) = ...
                gain(fMirror > 300 & fMirror <= 800) * 1.12;

            % Reduce sharp high frequencies
            gain(fMirror >= 3000) = gain(fMirror >= 3000) * 0.78;

            % Remove sub-bass rumble
            gain(fMirror < 55) = gain(fMirror < 55) * 0.65;

    end

    Y = X .* gain;
    y = real(ifft(Y));

end

% ============================================================
% HELPER FUNCTION: MATCH LENGTH
% ============================================================

function y = matchLength(y, targetLength)

    y = y(:);

    if length(y) > targetLength
        y = y(1:targetLength);
    elseif length(y) < targetLength
        y = [y; zeros(targetLength - length(y), 1)];
    end

end