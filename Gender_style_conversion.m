function [outputSignal, Fs] = Gender_style_conversion(inputFile, targetStyle)
if nargin < 1
    inputFile = 'inputfiles/voice-sample.wav';
end
if nargin < 2
    targetStyle = "feminine";
end

outputFile = 'outputs/gender_style_smooth.wav';

if ~exist('outputs', 'dir')
    mkdir('outputs');
end

% ============================================================
% READ AUDIO
% ============================================================

[x, fs] = audioread(inputFile);

if size(x, 2) > 1
    x = mean(x, 2);
end

x = x(:);
x = x / max(abs(x) + eps);

fprintf('Input duration: %.2f seconds\n', length(x) / fs);
fprintf('Sampling rate: %d Hz\n', fs);

% ============================================================
% PARAMETERS
% ============================================================

switch targetStyle

    case "feminine"
        pitchShiftSemitones = 2.0;
        formantScale = 1.06;

    case "masculine"
        medianF0 = estimateMedianF0(x, fs);
        targetF0 = 145;
        pitchShiftSemitones = 12 * log2(targetF0 / medianF0);
        pitchShiftSemitones = max(min(pitchShiftSemitones, -1.5), -6.0);
        formantScale = 2^(pitchShiftSemitones / 30);
        formantScale = max(min(formantScale, 0.97), 0.86);
        fprintf('Estimated median F0: %.2f Hz\n', medianF0);
        fprintf('Target F0: %.2f Hz\n', targetF0);

    otherwise
        error('targetStyle must be "feminine" or "masculine".');
end

% ============================================================
% PROCESSING
% ============================================================

y_pitch = smoothPitchShiftMultiStage(x, fs, pitchShiftSemitones);
fprintf('After pitch shift: max = %.6f, RMS = %.6f\n', max(abs(y_pitch)), rms(y_pitch));

y_formant = smoothFormantStyle(y_pitch, fs, formantScale);
fprintf('After formant style: max = %.6f, RMS = %.6f\n', max(abs(y_formant)), rms(y_formant));

y_final = smoothVoiceEQ(y_formant, fs, targetStyle);
y_final = shortFadeInOut(y_final, fs, 0.015);

if max(abs(y_final)) < 1e-6
    error('Output is almost silent. Processing failed.');
end

y_final = y_final / max(abs(y_final) + eps) * 0.95;

% ============================================================
% SAVE AND PLAY
% ============================================================

audiowrite(outputFile, y_final, fs);
sound(y_final, fs);
fprintf('Output saved to: %s\n', outputFile);

figure;
subplot(2,1,1);
plot(x);
title('Original waveform');
subplot(2,1,2);
plot(y_final);
title(sprintf('Gender-style converted waveform (%s)', targetStyle));

outputSignal = y_final;
Fs = fs;

end

% ============================================================
% LOCAL FUNCTIONS
% ============================================================

function y = smoothFormantStyle(x, fs, formantScale)
    x = x(:);
    N = length(x);
    windowLength = 2048;
    overlap = round(0.75 * windowLength);
    win = hamming(windowLength, 'periodic');
    [S, ~, ~] = stft(x, fs, 'Window', win, 'OverlapLength', overlap, ...
        'FFTLength', windowLength, 'Centered', false);
    mag = abs(S);
    phase = angle(S);
    numBins = size(S, 1);
    numFrames = size(S, 2);
    magNew = zeros(size(mag));
    binIndex = (1:numBins)';
    smoothBins = 55;
    for n = 1:numFrames
        currentMag = mag(:, n);
        logMag = log(currentMag + 1e-8);
        envelope = movmean(logMag, smoothBins);
        detail = logMag - envelope;
        sourceIndex = (binIndex - 1) / formantScale + 1;
        sourceIndex(sourceIndex < 1) = 1;
        sourceIndex(sourceIndex > numBins) = numBins;
        warpedEnvelope = interp1(binIndex, envelope, sourceIndex, 'linear');
        gainLog = min(max((warpedEnvelope + detail) - logMag, log(0.55)), log(1.6));
        magNew(:, n) = exp(logMag + gainLog);
    end
    Y = magNew .* exp(1i * phase);
    y = istft(Y, fs, 'Window', win, 'OverlapLength', overlap, ...
        'FFTLength', windowLength, 'Centered', false);
    y = matchLength(real(y), N);
end

function y = smoothVoiceEQ(x, fs, targetStyle)
    x = x(:);
    N = length(x);
    X = fft(x);
    f = (0:N-1)' * fs / N;
    fMirror = min(f, fs - f);
    gain = ones(N, 1);
    switch targetStyle
        case "feminine"
            gain(fMirror < 90) = gain(fMirror < 90) * 0.75;
            gain(fMirror >= 2200 & fMirror <= 6000) = gain(fMirror >= 2200 & fMirror <= 6000) * 1.08;
            gain(fMirror > 9000) = gain(fMirror > 9000) * 0.88;
        case "masculine"
            gain(fMirror >= 90  & fMirror <= 280)  = gain(fMirror >= 90  & fMirror <= 280)  * 1.30;
            gain(fMirror > 280  & fMirror <= 750)  = gain(fMirror > 280  & fMirror <= 750)  * 1.15;
            gain(fMirror >= 1800 & fMirror <= 3500) = gain(fMirror >= 1800 & fMirror <= 3500) * 0.90;
            gain(fMirror > 3500) = gain(fMirror > 3500) * 0.78;
            gain(fMirror < 55)  = gain(fMirror < 55)  * 0.65;
    end
    y = real(ifft(X .* gain));
end

function y = shortFadeInOut(x, fs, fadeSeconds)
    y = x(:);
    fadeLength = min(round(fadeSeconds * fs), floor(length(y) / 2));
    y(1:fadeLength) = y(1:fadeLength) .* linspace(0, 1, fadeLength)';
    y(end-fadeLength+1:end) = y(end-fadeLength+1:end) .* linspace(1, 0, fadeLength)';
end

function y = matchLength(y, targetLength)
    y = y(:);
    if length(y) > targetLength
        y = y(1:targetLength);
    elseif length(y) < targetLength
        y = [y; zeros(targetLength - length(y), 1)];
    end
end

function medianF0 = estimateMedianF0(x, fs)
    x = x(:);
    frameLength = round(0.040 * fs);
    hop = round(0.010 * fs);
    minLag = floor(fs / 450);
    maxLag = ceil(fs / 80);
    numFrames = floor((length(x) - frameLength) / hop) + 1;
    f0List = [];
    win = hamming(frameLength, 'periodic');
    for i = 1:numFrames
        startIdx = (i - 1) * hop + 1;
        frame = x(startIdx:startIdx + frameLength - 1) .* win;
        if rms(frame) < 0.01 * rms(x)
            continue;
        end
        r = xcorr(frame);
        r = r(frameLength:end);
        [peakVal, peakIdx] = max(r(minLag:maxLag));
        if peakVal > 0.25 * r(1)
            lag = peakIdx + minLag - 1;
            f0 = fs / lag;
            if f0 >= 80 && f0 <= 450
                f0List(end+1, 1) = f0; %#ok<AGROW>
            end
        end
    end
    if isempty(f0List)
        warning('Could not estimate F0 reliably. Using fallback value 220 Hz.');
        medianF0 = 220;
    else
        medianF0 = median(f0List);
    end
end

function y = smoothPitchShiftMultiStage(x, fs, totalSemitones)
    x = x(:);
    numStages = max(1, ceil(abs(totalSemitones) / 1.5));
    stepShift = totalSemitones / numStages;
    y = x;
    fprintf('Applying pitch shift in %d stages of %.2f semitones each\n', numStages, stepShift);
    for s = 1:numStages
        y = smoothPitchShiftPV(y, fs, stepShift);
        if max(abs(y)) < 1e-7
            warning('Stage %d produced nearly silent output. Falling back.', s);
            y = x;
            break;
        end
        y = removeTinyClicksSafe(y, fs);
        fprintf('  Stage %d/%d complete | max = %.6f | RMS = %.6f\n', s, numStages, max(abs(y)), rms(y));
    end
    y = matchLength(y, length(x));
end

function y = smoothPitchShiftPV(x, fs, semitones)
    x = x(:);
    originalLength = length(x);
    alpha = 2^(semitones / 12);
    stretched = phaseVocoderTimeStretch(x, fs, alpha);
    if max(abs(stretched)) < 1e-8
        warning('Time-stretch produced near silence. Returning original signal.');
        y = x;
        return;
    end
    y = interp1((1:length(stretched))', stretched, ...
        linspace(1, length(stretched), originalLength)', 'pchip', 0);
    y = matchLength(y(:), originalLength);
    if max(abs(y)) > 1e-8
        y = y / max(abs(y) + eps) * max(abs(x));
    else
        warning('Pitch shifted output is near silent. Returning original signal.');
        y = x;
    end
end

function y = phaseVocoderTimeStretch(x, fs, stretchFactor)
    x = x(:);
    stretchFactor = max(min(stretchFactor, 1.25), 0.75);
    N = length(x);
    windowLength = 2048;
    analysisHop = windowLength / 4;
    synthesisHop = round(analysisHop * stretchFactor);
    win = hann(windowLength, 'periodic');
    numFrames = floor((N - windowLength) / analysisHop) + 1;
    if numFrames < 2
        y = x;
        return;
    end
    outputLength = synthesisHop * (numFrames - 1) + windowLength;
    y = zeros(outputLength, 1);
    winSum = zeros(outputLength, 1);
    omega = 2 * pi * (0:windowLength-1)' / windowLength;
    previousPhase = zeros(windowLength, 1);
    synthesisPhase = zeros(windowLength, 1);
    for frameIndex = 1:numFrames
        inputStart = (frameIndex - 1) * analysisHop + 1;
        frame = x(inputStart:inputStart + windowLength - 1) .* win;
        X = fft(frame);
        mag = abs(X);
        phase = angle(X);
        if frameIndex == 1
            synthesisPhase = phase;
        else
            deltaPhase = phase - previousPhase - omega * analysisHop;
            deltaPhase = deltaPhase - 2*pi*round(deltaPhase / (2*pi));
            synthesisPhase = synthesisPhase + (omega + deltaPhase / analysisHop) * synthesisHop;
        end
        previousPhase = phase;
        outputStart = (frameIndex - 1) * synthesisHop + 1;
        outputRange = outputStart:outputStart + windowLength - 1;
        frameOut = real(ifft(mag .* exp(1i * synthesisPhase))) .* win;
        y(outputRange) = y(outputRange) + frameOut;
        winSum(outputRange) = winSum(outputRange) + win.^2;
    end
    valid = winSum > 1e-8;
    y(valid) = y(valid) ./ winSum(valid);
    y = real(y);
    if max(abs(y)) > 1e-8
        y = y / max(abs(y) + eps) * max(abs(x));
    end
end

function y = removeTinyClicksSafe(x, fs)
    y = x(:);
    fadeLength = min(round(0.008 * fs), floor(length(y) / 2));
    if fadeLength > 1
        y(1:fadeLength) = y(1:fadeLength) .* linspace(0, 1, fadeLength)';
        y(end-fadeLength+1:end) = y(end-fadeLength+1:end) .* linspace(1, 0, fadeLength)';
    end
    smoothing = 0.04;
    for n = 2:length(y)
        y(n) = (1 - smoothing) * y(n) + smoothing * y(n-1);
    end
end
