clear; close all; clc;
inputFile = 'outputs/noiseReduced.wav';  % Path to your input noise-reduced audio file
cutoffLow = 300;   % Hz
cutoffHigh = 3000; % Hz
[audio, fs] = audioread(inputFile);
X = fft(audio);
f = (0:N-1)*(fs/N);
% bandpass filter
filter = (f >= cutoffLow) & (f <= cutoffHigh);
X_filtered = X .* filter';
% Inverse FFT
audio_filtered = real(ifft(X_filtered));
% Normalize and play
audio_filtered = audio_filtered / max(abs(audio_filtered));
audiowrite('outputs/filtered.wav', audio_filtered, fs);