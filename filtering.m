function [outputSignal, Fs] = filtering(inputFile)
if nargin < 1
    inputFile = 'inputfiles/music-sample.wav';  % fallback
end

cutoffLow = 300;   % Hz
cutoffHigh = 3000; % Hz
[audio, fs] = audioread(inputFile);
X = fft(audio);
f = (0:length(audio)-1) * (fs / length(audio));  % Frequency vector
% bandpass filter
filter = (f >= cutoffLow) & (f <= cutoffHigh);
X_filtered = X .* filter';
% Inverse FFT
audio_filtered = real(ifft(X_filtered));
% Normalize
audio_filtered = audio_filtered / max(abs(audio_filtered));
audiowrite('outputs/filtered.wav', audio_filtered, fs);

outputSignal = audioread('outputs/filtered.wav');   
[~, Fs] = audioread(inputFile);   
end