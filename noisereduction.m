clear; close all; clc;
SourceFilename=input('Enter the filename of the audio to be noise reduced (e.g., music-sample.wav): ', 's');
Strength = input('Enter the noise reduction strength (e.g., 0.08 for moderate reduction): ');
inputFile = ['inputfiles/', SourceFilename];
[noise_reduced_audio, fs] = preprocessing(inputFile, Strength);
audiowrite(['outputs/', SourceFilename, '_noiseReduced.wav'], noise_reduced_audio, fs);

