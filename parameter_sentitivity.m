% DFT Size Comparison — bar spectra at 10 Hz resolution
clear; clc; close all;

%% --- PARAMETERS ---
filename   = 'inputfiles/music-sample.wav';
window_end = 2.0;    % seconds to analyse
max_freq   = 4000;   % Hz to display on x-axis
bin_width  = 10;     % Hz per bar
hop        = 256;    % hop size (fixed across all DFT sizes)

%% --- LOAD & CROP ---
[x, fs] = audioread(filename);
x = mean(x, 2);
x = x(1 : min(end, round(window_end * fs)));

%% --- STFT RECONSTRUCT FOR EACH DFT SIZE ---
function x_out = stft_reconstruct(x, N, hop)
    num_frames = floor((length(x) - N) / hop) + 1;
    x_out      = zeros(length(x), 1);
    win        = hann(N);
    for f = 1:num_frames
        i1    = (f-1)*hop + 1;
        i2    = i1 + N - 1;
        frame = x(i1:i2) .* win;
        X     = fft(frame, N);
        rec   = real(ifft(X, N)) .* win;   % overlap-add
        x_out(i1:i2) = x_out(i1:i2) + rec;
    end
    x_out = x_out / max(abs(x_out) + 1e-10);
end

%% --- COMPUTE AVERAGE MAGNITUDE PER 10 Hz BIN ---
function mag_bins = compute_bins(x, fs, N, bin_width, max_freq)
    X        = abs(fft(x, N));
    X        = X(1:floor(N/2));
    freqs    = (0:floor(N/2)-1) * fs/N;
    edges    = 0 : bin_width : max_freq;
    mag_bins = zeros(1, length(edges)-1);
    for i = 1:length(edges)-1
        idx = freqs >= edges(i) & freqs < edges(i+1);
        if any(idx), mag_bins(i) = mean(X(idx)); end
    end
end

%% --- PROCESS & SAVE ---
sizes = {4096, 2048, 1024, 512};
recons = cell(1,4);
for k = 1:4
    N          = sizes{k};
    recons{k}  = stft_reconstruct(x, N, hop);
    audiowrite(sprintf('outputs/output_N%d.wav', N), recons{k}, fs);
end

%% --- COMPUTE BINS ---
centers = (bin_width/2 : bin_width : max_freq - bin_width/2);
shift   = 5;
bins = cell(1,4);
for k = 1:4
    bins{k} = compute_bins(recons{k}, fs, sizes{k}, bin_width, max_freq);
end

%% --- PLOT ---
labels = {'4096','2048','1024','512'};
colors = [0.2 0.5 0.9;
          0.9 0.4 0.2;
          0.2 0.8 0.4;
          0.8 0.2 0.6];

figure('Position', [100 100 1100 750]);
for p = 1:3
    subplot(3,1,p);
    bar(centers,       bins{p},   0.8, 'FaceColor', colors(p,:),   'FaceAlpha', 0.5, 'EdgeColor', 'none'); hold on;
    bar(centers+shift, bins{p+1}, 0.8, 'FaceColor', colors(p+1,:), 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    xlabel('Frequency (Hz)'); ylabel('Magnitude');
    title(sprintf('N = %s  vs  N = %s', labels{p}, labels{p+1}));
    legend(sprintf('N=%s', labels{p}), sprintf('N=%s (+%dHz)', labels{p+1}, shift), 'Location','northeast');
    xlim([0 max_freq]); grid on;
end
sgtitle('DFT Size Comparison — STFT reconstruct, avg magnitude per 10 Hz bin');

%% --- FIGURE 2: HOP SIZE COMPARISON (fixed N=16384) ---
N_fixed    = 8192;
hops       = {256, 512, 1024, 2048};
hop_labels = {'256','512','1024','2048'};
hop_colors = [0.3 0.7 0.9;
              0.9 0.6 0.1;
              0.4 0.85 0.5;
              0.75 0.3 0.75];

hop_recons = cell(1,4);
hop_bins   = cell(1,4);
for k = 1:4
    hop_recons{k} = stft_reconstruct(x, N_fixed, hops{k});
    audiowrite(sprintf('outputs/output_hop%d.wav', hops{k}), hop_recons{k}, fs);
    hop_bins{k}   = compute_bins(hop_recons{k}, fs, N_fixed, bin_width, max_freq);
end

figure('Position', [200 100 1100 750]);
for p = 1:3
    subplot(3,1,p);
    bar(centers,       hop_bins{p},   0.8, 'FaceColor', hop_colors(p,:),   'FaceAlpha', 0.5, 'EdgeColor', 'none'); hold on;
    bar(centers+shift, hop_bins{p+1}, 0.8, 'FaceColor', hop_colors(p+1,:), 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    xlabel('Frequency (Hz)'); ylabel('Magnitude');
    title(sprintf('hop = %s  vs  hop = %s', hop_labels{p}, hop_labels{p+1}));
    legend(sprintf('hop=%s', hop_labels{p}), sprintf('hop=%s (+%dHz)', hop_labels{p+1}, shift), 'Location','northeast');
    xlim([0 max_freq]); grid on;
end
sgtitle('Hop Size Comparison — N=16384 fixed, avg magnitude per 10 Hz bin');

%% --- FIGURE 3: OBSERVATION WINDOW LENGTH COMPARISON ---
fs_fig3    = 22500;
win_lens   = {0.1, 1.0, 5.0, 20.0};
win_labels = {'0.1s','1.0s','5.0s','20.0s'};
win_colors = [0.2 0.6 0.9;
              0.9 0.3 0.3;
              0.3 0.8 0.4;
              0.85 0.6 0.1];

% resample audio to fs_fig3 and loop to fill if needed
x_rs = resample(x, fs_fig3, fs);
n_needed = round(20.0 * fs_fig3);
while length(x_rs) < n_needed
    x_rs = [x_rs; x_rs];
end
x_rs = x_rs(1:n_needed);

win_bins = cell(1,4);
for k = 1:4
    % crop to exact window length — this IS the full observation window
    N_w    = round(win_lens{k} * fs_fig3);
    x_crop = x_rs(1:N_w);
    df     = fs_fig3 / N_w;
    fprintf('Window=%.1fs  N_w=%d  Δf=%.4f Hz\n', win_lens{k}, N_w, df);
    audiowrite(sprintf('outputs/output_win%s.wav', win_labels{k}), x_crop, fs_fig3);
    win_bins{k} = compute_bins(x_crop, fs_fig3, N_w, bin_width, max_freq);
end

figure('Position', [300 100 1100 750]);
for p = 1:3
    subplot(3,1,p);
    N_lo  = round(win_lens{p}   * fs_fig3);
    N_hi  = round(win_lens{p+1} * fs_fig3);
    df_lo = fs_fig3 / N_lo;
    df_hi = fs_fig3 / N_hi;

    bar(centers,       win_bins{p},   0.8, 'FaceColor', win_colors(p,:),   'FaceAlpha', 0.5, 'EdgeColor', 'none'); hold on;
    bar(centers+shift, win_bins{p+1}, 0.8, 'FaceColor', win_colors(p+1,:), 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    xlabel('Frequency (Hz)'); ylabel('Magnitude');
    title(sprintf('win=%s (Δf=%.3fHz)  vs  win=%s (Δf=%.3fHz)', ...
        win_labels{p}, df_lo, win_labels{p+1}, df_hi));
    legend(win_labels{p}, sprintf('%s (+%dHz)', win_labels{p+1}, shift), 'Location','northeast');
    xlim([0 max_freq]); grid on;
end
sgtitle('Observation Window Comparison — fs=22500Hz, full window, avg magnitude per 10 Hz bin');