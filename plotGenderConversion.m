function plotGenderConversion(inputSignal, outputSignal, targetStyle)
%PLOTGENDERCONVERSION  Plot original vs gender-style-converted waveform.
%   Extracted from Gender_style_conversion so the batch analysis scripts
%   (samplingResolutionAnalysis, noiseRobustnessAnalysis) don't pop up a
%   figure on every call. Call this manually when you actually want the
%   comparison plot, e.g.:
%
%       in = 'inputfiles/voice-sample.wav';
%       [y, ~] = Gender_style_conversion(in, "feminine");
%       [x, ~] = audioread(in);
%       plotGenderConversion(x, y, "feminine");

    if nargin < 3
        targetStyle = "";
    end

    figure;
    subplot(2,1,1);
    plot(inputSignal);
    title('Original waveform');
    subplot(2,1,2);
    plot(outputSignal);
    title(sprintf('Gender-style converted waveform (%s)', targetStyle));
end
