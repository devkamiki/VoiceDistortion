function noiseRobustnessAnalysis()
    outputDir = fullfile('results', 'noise_robustness');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    snrLevels = [30, 20, 10, 0];  % dB

    tests = { ...
        struct('name','Robotic',  'func',@roboticdistortion, 'input','inputfiles/voice-sample.wav'), ...
        struct('name','Equalizer','func',@graphicEqualizer,  'input','inputfiles/music-sample.wav'), ...
        struct('name','Filter',   'func',@filtering,         'input','inputfiles/music-sample.wav'), ...
        struct('name','Chorus',   'func',@chorusOrig,        'input','inputfiles/singingm4a-sample.wav') ...
        struct('name','Gender',   'func',@Gender_style_conversion,        'input','inputfiles/singingm4a-sample.wav') ...
    };

    for t = 1:length(tests)
        test = tests{t};
        fprintf(' %s \n', test.name);

        [cleanSig, Fs] = audioread(test.input);
        cleanSig = mean(cleanSig, 2);
        cleanSig = cleanSig / max(abs(cleanSig) + eps);

        % Baseline
        cleanPath = fullfile(tempdir, sprintf('clean_%s.wav', test.name));
        audiowrite(cleanPath, cleanSig, Fs);
        cleanProc = runEffectQuiet(test.func, cleanPath);
        cleanProc = cleanProc(:) / max(abs(cleanProc) + eps);

        N = 8192;
        freq = (0:N/2-1) * (Fs / N);
        half = 1:N/2;

        Y_cleanOut = abs(fft(cleanProc, N));

        fig = figure('Position', [100 100 1000 600], 'Visible', 'off');
        plot(freq, 20*log10(Y_cleanOut(half)/max(Y_cleanOut)+eps), 'k', 'LineWidth', 1.5);
        hold on;
        legendEntries = {'Clean'};

        for i = 1:length(snrLevels)
            snrIn = snrLevels(i);
            noisySig = addNoise(cleanSig, snrIn);
            noisySig = noisySig / max(abs(noisySig) + eps);

            noisyPath = fullfile(tempdir, sprintf('noisy_%s_%02d.wav', test.name, snrIn));
            audiowrite(noisyPath, noisySig, Fs);
            noisyProc = runEffectQuiet(test.func, noisyPath);
            noisyProc = noisyProc(:) / max(abs(noisyProc) + eps);

            L = min(length(cleanProc), length(noisyProc));
            cp = cleanProc(1:L);
            np = noisyProc(1:L);

            Y_noisyOut = abs(fft(np, N));
            outSNR = 10*log10(sum(cp.^2) / (sum((cp - np).^2) + eps));
            fprintf('  Input SNR=%2d dB | Output SNR=%6.2f dB\n', snrIn, outSNR);

            plot(freq, 20*log10(Y_noisyOut(half)/max(Y_noisyOut)+eps), 'LineWidth', 1);
            legendEntries{end+1} = sprintf('SNR_{in}=%d dB', snrIn); %#ok<AGROW>
        end

        title(sprintf('%s - output freq spectrum with regard of frequency domain', test.name));
        xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
        legend(legendEntries); grid on; xlim([0 Fs/2]); ylim([-80 5]);
        saveas(fig, fullfile(outputDir, sprintf('%s.png', test.name)));
        close(fig);
    end

    fprintf('\nDone. Figures saved in: %s\n', outputDir);
end

function noisy = addNoise(sig, snrDb)
    Psig = mean(sig.^2);
    Pn = Psig / 10^(snrDb/10);
    noisy = sig + sqrt(Pn) * randn(size(sig));
end

function out = runEffectQuiet(fn, inputPath)
    [~, out] = evalc('fn(inputPath)');
    try
        clear playsnd
    catch
    end
end
