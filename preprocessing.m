% This is a function to convert .m4a files to .wav
function [output, fs] = preprocessing(inputFile)
    [audio, fs] = audioread(inputFile);
    [folder, name, ~] = fileparts(inputFile);
    wavFile = fullfile(folder, [name, '.wav']);
    audiowrite(wavFile, audio, fs);
    fprintf('Saved as: %s\n', wavFile);
    output = wavFile;
end
