% FFT Audio Modifier
% Parameters: observation window, DFT size, frequency resolution
% Usage: place a .wav file in the same folder, set filename below

clear; clc; close all;

%% --- USER PARAMETERS ---
filename        = 'inputfiles/music-sample.wav';   % your wav file
window_start    = 0.0;           % start time (seconds)
window_end      = 2.0;           % end time (seconds)  <- observation window
N_dft           = 4096;          % DFT size (power of 2, e.g. 512 1024 2048 4096)
freq_resolution = 200;           % keep frequencies BELOW this Hz (lowpass cutoff)
                                 % acts as a simple filter to show effect of resolution

%% --- LOAD AUDIO ---
[x, fs] = audioread(filename);
x = mean(x, 2);                  % convert stereo to mono if needed

%% --- APPLY OBSERVATION WINDOW ---
i_start = max(1, round(window_start * fs));
i_end   = min(length(x), round(window_end * fs));
x_win   = x(i_start:i_end);
N_win   = length(x_win);

fprintf('Sample rate     : %d Hz\n', fs);
fprintf('Window length   : %.3f s  (%d samples)\n', N_win/fs, N_win);
fprintf('DFT size (N)    : %d\n', N_dft);
fprintf('Freq resolution : %.2f Hz  (lowpass cutoff)\n', freq_resolution);

%% --- INPUT SPECTRUM ---
% zero-pad signal to N_dft if N_dft > N_win, else truncate
x_pad = zeros(N_dft, 1);
n_copy = min(N_win, N_dft);
x_pad(1:n_copy) = x_win(1:n_copy);

X = fft(x_pad, N_dft);           % DFT
freqs = (0:N_dft-1) * fs / N_dft; % frequency axis (Hz)

%% --- PLOT INPUT SPECTRUM ---
figure;
subplot(2,1,1);
half = 1:floor(N_dft/2);         % one-sided
plot(freqs(half), 20*log10(abs(X(half)) + 1e-10), 'b');
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title(sprintf('Input spectrum  |  window: %.1f–%.1f s  |  N=%d', ...
    window_start, window_end, N_dft));
grid on;

%% --- APPLY FREQUENCY RESOLUTION FILTER ---
% zero out all bins above freq_resolution (simple brickwall lowpass)
cutoff_bin = round(freq_resolution / (fs / N_dft));
cutoff_bin = max(1, min(cutoff_bin, floor(N_dft/2)));

X_filt = X;
X_filt(cutoff_bin+1 : N_dft-cutoff_bin+1) = 0;   % zero high-freq bins

%% --- RECONSTRUCT AUDIO ---
x_out = real(ifft(X_filt, N_dft));  % inverse FFT
x_out = x_out(1:N_win);             % trim back to original window length
x_out = x_out / max(abs(x_out) + 1e-10);  % normalise to [-1, 1]

%% --- PLOT OUTPUT SPECTRUM ---
X_out = fft(x_out, N_dft);
subplot(2,1,2);
plot(freqs(half), 20*log10(abs(X_out(half)) + 1e-10), 'r');
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title(sprintf('Output spectrum  |  lowpass cutoff: %d Hz', freq_resolution));
grid on;

%% --- SAVE OUTPUT ---
output_file = 'output.wav';
audiowrite(output_file, x_out, fs);
fprintf('Output saved to : %s\n', output_file);