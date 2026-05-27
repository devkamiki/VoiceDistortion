% This is a function to convert .m4a files to .wav and perform simple noise reduction using DFT.
function [output, fs] = preprocessing(inputFile, noiseGateThreshold)
    [~, ~, ext] = fileparts(inputFile);
    if strcmpi(ext, '.m4a')
        fprintf('Converting %s to WAV...\n', inputFile);
        [audio, fs] = audioread(inputFile);
        wavFile = strrep(inputFile, ext, '.wav');
        audiowrite(wavFile, audio, fs);
        fprintf('Saved as: %s\n', wavFile);
        inputFile = wavFile;
    end

    [audio, fs] = audioread(inputFile);
    if size(audio, 2) > 1
        audio = mean(audio, 2);
    end

    peakIn = max(abs(audio));
    if peakIn > 0
        audio = audio / peakIn;
    end

    windowSize = 2048;
    hopSize = windowSize / 2;
    window = hann(windowSize, 'periodic');
    audioPadded = [audio; zeros(windowSize, 1)];
    numFrames = floor((length(audioPadded) - windowSize) / hopSize) + 1;

    X = zeros(windowSize, numFrames);
    for k = 1:numFrames
        idx = (k-1) * hopSize + (1:windowSize);
        frame = audioPadded(idx) .* window;
        X(:, k) = fft(frame);
    end

    mag = abs(X);
    phase = angle(X);
    noiseFloor = median(mag, 2);
    magClean = max(mag - noiseFloor * (1 + noiseGateThreshold), 0);

    XClean = magClean .* exp(1j * phase);
    out = zeros(size(audioPadded));
    weight = zeros(size(audioPadded));

    for k = 1:numFrames
        idx = (k-1) * hopSize + (1:windowSize);
        frameOut = real(ifft(XClean(:, k))) .* window;
        out(idx) = out(idx) + frameOut;
        weight(idx) = weight(idx) + window.^2;
    end

    output = out(1:length(audio)) ./ (weight(1:length(audio)) + eps);
    if max(abs(output)) > 0
        output = output * peakIn / max(abs(output));
    end

    fprintf('Noise reduction completed (threshold = %.3f)\n', noiseGateThreshold);
end
