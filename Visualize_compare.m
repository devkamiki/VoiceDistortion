function visualizeAudioCompare(inputFile, outputFile, binWidth, shiftHz, maxPlotFreq)
% visualizeAudioCompare
%
% Compare an original audio file and a processed/distorted audio file.
%
% This function visualizes:
%   1. Time-domain waveforms
%   2. Frequency-domain FFT curves with 10 Hz average bar graphs
%   3. Overlapping average frequency bars for direct comparison
%
% Usage:
%   visualizeAudioCompare('inputfiles/voice-sample.wav', ...
%                         'outputs/gender_style_smooth.wav');
%
% Optional:
%   visualizeAudioCompare(inputFile, outputFile, binWidth, shiftHz, maxPlotFreq);
%
% Inputs:
%   inputFile   - path to original audio file
%   outputFile  - path to processed/distorted audio file
%   binWidth    - frequency bin width in Hz, default = 10
%   shiftHz     - shift amount for Signal 2 bars in Figure 3, default = 5
%   maxPlotFreq - max frequency shown in Figure 3, default = 5000 Hz

    % ============================================================
    % DEFAULT PARAMETERS
    % ============================================================

    if nargin < 3
        binWidth = 10;      % Hz
    end

    if nargin < 4
        shiftHz = 5;        % Hz
    end

    if nargin < 5
        maxPlotFreq = 5000; % Hz
    end

    % ============================================================
    % LOAD TWO AUDIO FILES
    % ============================================================

    [x1, fs1] = audioread(inputFile);    % Original signal
    [x2, fs2] = audioread(outputFile);   % Processed/distorted signal

    % ============================================================
    % CONVERT STEREO TO MONO IF NEEDED
    % ============================================================

    if size(x1, 2) > 1
        x1 = mean(x1, 2);
    end

    if size(x2, 2) > 1
        x2 = mean(x2, 2);
    end

    % ============================================================
    % CHECK SAMPLING RATES
    % ============================================================

    if fs1 ~= fs2
        error('The two audio files must have the same sampling rate.');
    end

    fs = fs1;

    % ============================================================
    % MAKE BOTH SIGNALS SAME LENGTH
    % ============================================================

    N = min(length(x1), length(x2));

    x1 = x1(1:N);
    x2 = x2(1:N);

    % ============================================================
    % NORMALIZE BOTH SIGNALS
    % ============================================================

    x1 = x1 / max(abs(x1) + eps);
    x2 = x2 / max(abs(x2) + eps);

    % ============================================================
    % TIME AXIS
    % ============================================================

    t = (0:N-1) / fs;

    % ============================================================
    % FIGURE 1: TIME DOMAIN COMPARISON
    % ============================================================

    figure(1);
    clf;

    subplot(2,1,1);
    plot(t, x1, 'b', 'LineWidth', 1.2);
    title('Time Domain - Original Signal');
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;

    subplot(2,1,2);
    plot(t, x2, 'r', 'LineWidth', 1.2);
    title('Time Domain - Processed Signal');
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;

    % ============================================================
    % FREQUENCY DOMAIN CALCULATION
    % ============================================================

    X1 = fft(x1);
    X2 = fft(x2);

    N_half = floor(N / 2);

    f = (0:N-1) * (fs / N);
    f_pos = f(1:N_half);

    mag1 = abs(X1(1:N_half));
    mag2 = abs(X2(1:N_half));

    % ============================================================
    % CREATE AVERAGE FREQUENCY BINS
    % ============================================================

    maxFreq = max(f_pos);

    binEdges = 0:binWidth:maxFreq;
    binCenters = binEdges(1:end-1) + binWidth / 2;

    avgMag1 = zeros(size(binCenters));
    avgMag2 = zeros(size(binCenters));

    for k = 1:length(binCenters)

        idx = f_pos >= binEdges(k) & f_pos < binEdges(k+1);

        if any(idx)
            avgMag1(k) = mean(mag1(idx));
            avgMag2(k) = mean(mag2(idx));
        else
            avgMag1(k) = 0;
            avgMag2(k) = 0;
        end

    end

    % ============================================================
    % FIGURE 2: FFT CURVES WITH AVERAGE BAR GRAPHS
    % ============================================================

    figure(2);
    clf;

    % ---------- Original signal ----------
    subplot(2,1,1);

    plot(f_pos, mag1, 'b', 'LineWidth', 1.2);
    hold on;

    bar(binCenters, avgMag1, 1.0, ...
        'FaceColor', [1 0.4 0.7], ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.5);

    title(sprintf('Frequency Domain - Original Signal with %.0f Hz Average Bars', binWidth));
    xlabel('Frequency (Hz)');
    ylabel('Magnitude');
    legend('Original Signal FFT', 'Original Signal Average');
    grid on;
    hold off;

    % ---------- Processed signal ----------
    subplot(2,1,2);

    plot(f_pos, mag2, 'r', 'LineWidth', 1.2);
    hold on;

    bar(binCenters, avgMag2, 1.0, ...
        'FaceColor', [0.1 0.7 0.2], ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.5);

    title(sprintf('Frequency Domain - Processed Signal with %.0f Hz Average Bars', binWidth));
    xlabel('Frequency (Hz)');
    ylabel('Magnitude');
    legend('Processed Signal FFT', 'Processed Signal Average');
    grid on;
    hold off;

    % ============================================================
    % FIGURE 3: OVERLAPPING BAR GRAPH COMPARISON
    % ============================================================

    figure(3);
    clf;
    set(gcf, 'Renderer', 'opengl');

    binCenters1 = binCenters;
    binCenters2 = binCenters + shiftHz;

    bar1_compare = bar(binCenters1, avgMag1, 1.0, ...
        'FaceColor', [1 0.4 0.7], ...
        'EdgeColor', 'none');
    hold on;

    bar2_compare = bar(binCenters2, avgMag2, 1.0, ...
        'FaceColor', [0.1 0.7 0.2], ...
        'EdgeColor', 'none');

    alpha(bar1_compare, 0.5);
    alpha(bar2_compare, 0.5);

    title(sprintf('Comparison of %.0f Hz Average Frequency Magnitudes', binWidth));
    xlabel('Frequency (Hz)');
    ylabel(sprintf('Average Magnitude per %.0f Hz', binWidth));
    legend('Original Signal Average', 'Processed Signal Average');
    grid on;
    xlim([0 maxPlotFreq]);
    hold off;

    % ============================================================
    % COMMAND WINDOW SUMMARY
    % ============================================================

    fprintf('\nAudio comparison complete.\n');
    fprintf('Original file:  %s\n', inputFile);
    fprintf('Processed file: %s\n', outputFile);
    fprintf('Sampling rate:  %d Hz\n', fs);
    fprintf('Signal length:  %.2f seconds\n', N / fs);
    fprintf('Bin width:      %.2f Hz\n', binWidth);
    fprintf('Figure 3 shift: %.2f Hz\n', shiftHz);

end