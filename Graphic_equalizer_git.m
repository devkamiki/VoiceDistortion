clear; close all;

inputFile = fullfile('inputfiles', 'music-sample.wav');

[audio, fs] = audioread(inputFile);
audio = audio(:,1);
audio = audio / max(abs(audio));

% Parameters
windowSize = 1024;
hopSize = windowSize / 4;

% ========= GRAPHIC EQ SETTINGS =========
lowGain  = 1.5;   % boost bass
midGain  = 1.0;   % keep middle
highGain = 0.6;   % reduce treble
% =======================================

numWindows = floor((length(audio) - windowSize)/hopSize) + 1;
output = zeros(size(audio));

for i = 1:numWindows
    
    startIdx = (i-1)*hopSize + 1;
    frame = audio(startIdx:startIdx+windowSize-1);

    % Window
    win = hamming(windowSize);
    frameWindowed = frame .* win;

    % FFT
    F = fft(frameWindowed);

    % ======================
    % 🔹 GRAPHIC EQUALIZER
    % ======================
    N = length(F);

    % Frequency vector (only conceptual, index-based)
    gain = ones(N,1);

    % Split bands
    lowEnd  = floor(N * 0.2);
    midEnd  = floor(N * 0.6);

    % Apply gains
    gain(1:lowEnd) = lowGain;
    gain(lowEnd+1:midEnd) = midGain;
    gain(midEnd+1:end) = highGain;

    % Apply EQ
    F_eq = F .* gain;

    % ======================
    % iFFT
    % ======================
    frameOut = real(ifft(F_eq));

    % Window again
    frameOut = frameOut .* win;

    % Overlap-add
    output(startIdx:startIdx+windowSize-1) = ...
        output(startIdx:startIdx+windowSize-1) + frameOut;
end

% Normalize
output = output / max(abs(output));

% Play
sound(output, fs);

% Save
audiowrite('outputs/equalized_voice.wav', output, fs);