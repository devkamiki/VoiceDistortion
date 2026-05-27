clear; close all; clc;

%basically what I am doing here is to put the distorted version and
%ordinary file together and visualize their differences, 
%so we can have better adjustments as well. the bar graph is the average
%value of each 10 hz, and for figure 3 I manually shifted signal two 5 hz
%to the right in case better see the differences.

% ---------- Load two audio files ----------
Inputfile = fullfile('inputfiles', 'music-sample.wav');
Outputfile = fullfile('outputs', 'equalized_voice.wav');

[x1, fs1] = audioread(Inputfile);       % Signal 1
[x2, fs2] = audioread(Outputfile);     % Signal 2

% ---------- Convert stereo to mono if needed ----------
x1 = mean(x1, 2);
x2 = mean(x2, 2);

% ---------- Check sampling rates ----------
if fs1 ~= fs2
    error('The two audio files must have the same sampling rate.');
end

fs = fs1;

% ---------- Make both signals same length ----------
N = min(length(x1), length(x2));
x1 = x1(1:N);
x2 = x2(1:N);

% ---------- Normalize both signals ----------
x1 = x1 / max(abs(x1));
x2 = x2 / max(abs(x2));

% ---------- Time axis ----------
t = (0:N-1) / fs;



%% ============================================================
% FIGURE 1: TWO TIME DOMAIN GRAPHS
% ============================================================

figure(1);

subplot(2,1,1);
plot(t, x1, 'b', 'LineWidth', 1.2);
title('Time Domain - Signal 1');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

subplot(2,1,2);
plot(t, x2, 'r', 'LineWidth', 1.2);
title('Time Domain - Signal 2');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;



%% ============================================================
% FREQUENCY DOMAIN CALCULATION
% ============================================================

% FFT
X1 = fft(x1);
X2 = fft(x2);

% Use positive frequency half
N_half = floor(N/2);

f = (0:N-1) * (fs/N);
f_pos = f(1:N_half);

mag1 = abs(X1(1:N_half));
mag2 = abs(X2(1:N_half));

% ---------- Create 10 Hz average bins ----------
binWidth = 10;   % 10 Hz

maxFreq = max(f_pos);
binEdges = 0:binWidth:maxFreq;
binCenters = binEdges(1:end-1) + binWidth/2;

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



%% ============================================================
% FIGURE 2: TWO FREQUENCY DOMAIN GRAPHS WITH DIFFERENT COLOR BAR GRAPHS
% ============================================================

figure(2);

% ---------- Signal 1 frequency domain + bar graph ----------
subplot(2,1,1);

% Actual FFT curve: blue
hLine1 = plot(f_pos, mag1, 'b', 'LineWidth', 1.2);
hold on;

% Bar graph: yellow, different from blue

bar1 = bar(binCenters, avgMag1, 1.0, ...
    'FaceColor', [1 0.4 0.7], ...
    'EdgeColor', 'none', ...
    'FaceAlpha', 0.5);


title('Frequency Domain - Signal 1 with 10 Hz Average Bars');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
legend('Signal 1 FFT', 'Signal 1 10 Hz Average');
grid on;
hold off;


% ---------- Signal 2 frequency domain + bar graph ----------
subplot(2,1,2);

% Actual FFT curve: red
hLine2 = plot(f_pos, mag2, 'r', 'LineWidth', 1.2);
hold on;

% Bar graph: green, different from red
bar2 = bar(binCenters, avgMag2, 1.0, ...
    'FaceColor', [0.1 0.7 0.2], ...
    'EdgeColor', 'none', ...
    'FaceAlpha', 0.5);

title('Frequency Domain - Signal 2 with 10 Hz Average Bars');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
legend('Signal 2 FFT', 'Signal 2 10 Hz Average');
grid on;
hold off;



%% ============================================================
% FIGURE 3: ONLY TWO OVERLAPPING BAR GRAPHS, BOTH 50% TRANSPARENT
% ============================================================

%% ============================================================
% FIGURE 3: ONLY TWO OVERLAPPING BAR GRAPHS, BOTH 50% TRANSPARENT
% ============================================================

figure(3);
clf;
set(gcf, 'Renderer', 'opengl');

% Shift amount in Hz
shiftHz = 5;

% Shift bar positions
binCenters1 = binCenters;        % Signal 1 stays unchanged
binCenters2 = binCenters + 5;    % Signal 2 shifts right 5 Hz

bar1_compare = bar(binCenters1, avgMag1, 1.0, ...
    'FaceColor', [1 0.4 0.7], ...
    'EdgeColor', 'none');
hold on;

bar2_compare = bar(binCenters2, avgMag2, 1.0, ...
    'FaceColor', [0.1 0.7 0.2], ...
    'EdgeColor', 'none');

alpha(bar1_compare, 0.5);
alpha(bar2_compare, 0.5);

title('Comparison of 10 Hz Average Frequency Magnitudes');
xlabel('Frequency (Hz)');
ylabel('Average Magnitude per 10 Hz');
legend('Signal 1 10 Hz Average', 'Signal 2 10 Hz Average');
grid on;
xlim([0 5000]);
hold off;