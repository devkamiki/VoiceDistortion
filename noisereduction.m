clear; close all; clc;
SourceFilename=input('Enter the filename of the audio to be noise reduced (e.g., music-sample.wav): ', 's');
inputFile = ['inputfiles/', SourceFilename];
[noise_reduced_audio, fs] = preprocessing(inputFile, 0.08);
audiowrite(['outputs/', SourceFilename, '_noiseReduced.wav'], noise_reduced_audio, fs);