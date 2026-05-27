clear; close all; clc;
inputFile = 'inputfiles/music-sample.wav';   
[noise_reduced_audio, fs] = preprocessing(inputFile, 0.008);  
audiowrite('outputs/noiseReduced.wav', noise_reduced_audio, fs);