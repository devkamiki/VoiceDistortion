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
    % noise reduction
    F = fft(audio);
    mag = abs(F);
    phase = angle(F);
    maxMag = max(mag);
    mag_clean = mag .* (mag > noiseGateThreshold * maxMag);
    F_clean = mag_clean .* exp(1j * phase);
    output = real(ifft(F_clean));
    output = output / max(abs(output));

    fprintf('Noise reduction completed (threshold = %.3f)\n', noiseGateThreshold);
end