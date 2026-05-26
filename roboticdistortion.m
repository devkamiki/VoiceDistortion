clear; close all;

inputFile = 'outputs/noiseReduced.wav';  % Path to your input noise-reduced audio file

[audio, fs] = audioread(inputFile); 
audio = audio(:,1);  
audio = audio / max(abs(audio));  % Normalize
% Parameters
windowSize = 1024;      % FFT size 
hopSize = windowSize / 4;  % Overlap, 75%
shiftAmount = 0.001; %  how much we shift the frequencies, smaller=more natural
phaseRand = 0.3; % phase randomization amount
noiseGateThreshold = 0.15; % decides how much noise to remove, higher = more aggressive
% Process with STFT 
numWindows = floor((length(audio) - windowSize)/hopSize) + 1;
output = zeros(size(audio));

for i = 1:numWindows
    startIdx = (i-1)*hopSize + 1;
    frame = audio(startIdx:startIdx+windowSize-1);
    % Apply window
    win = hamming(windowSize);
    frameWindowed = frame .* win;
    % DFT
    F = fft(frameWindowed);
    
    % ROBOT EFFECT 
    % Frequency shift, makes it sound mechanical
    shift = round(length(F) * shiftAmount);  % shift by shiftAmount% of spectrum
    F_robot = [F(shift+1:end); zeros(shift,1)];  % simple shift
    % Randomize phase for more metallic sound
    mag = abs(F_robot);
    % uncomment one of the two lines below for random or zero phase
    phase = angle(F_robot) + (rand(size(F_robot))-0.5)*phaseRand; % random phase
    phase = zeros(size(F_robot));   % zero phase instead of random, for more robotic sound
    F_robot = mag .* exp(1j * phase);
    
    % Inverse DFT
    frameOut = real(ifft(F_robot));
    frameOut = frameOut .* win;  % window again
    % Overlap-add
    output(startIdx:startIdx+windowSize-1) = output(startIdx:startIdx+windowSize-1) + frameOut;
end
% Normalize and play
output = output / max(abs(output));
sound(output, fs);
% Save output
audiowrite('outputsrobotic_voice.wav', output, fs);