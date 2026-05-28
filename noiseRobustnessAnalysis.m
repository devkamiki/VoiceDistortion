function noiseRobustnessAnalysis()
    outputDir = fullfile('results', 'noise_robustness');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    snrLevels = [30, 20, 15, 10, 5, 0];  % dB

    tests = { ...
        struct('name','Robotic',  'func',@roboticdistortion, 'input','inputfiles/voice-sample.wav'), ...
        struct('name','Equalizer','func',@graphicEqualizer,  'input','inputfiles/music-sample.wav'), ...
        struct('name','Filter',   'func',@filtering,         'input','inputfiles/music-sample.wav'), ...
        struct('name','Chorus',   'func',@chorus,            'input','inputfiles/singing-sample.wav') ...
    };

    summary = cell(length(tests), 1);

    for t = 1:length(tests)
        test = tests{t};
        fprintf('=== %s Noise Test ===\n', test.name);

        [cleanSig, Fs] = audioread(test.input);
        cleanSig = mean(cleanSig, 2);
        cleanSig = cleanSig / max(abs(cleanSig) + eps);

        % Baseline: process the clean signal once for reference
        cleanPath = fullfile(tempdir, sprintf('clean_%s.wav', test.name));
        audiowrite(cleanPath, cleanSig, Fs);
        cleanProc = runEffectQuiet(test.func, cleanPath);
        cleanProc = cleanProc(:);
        cleanProc = cleanProc / max(abs(cleanProc) + eps);

        metrics = zeros(length(snrLevels), 4); % [snrIn, outSNR, specDist, corr]

        for i = 1:length(snrLevels)
            snrIn = snrLevels(i);
            noisySig = addNoise(cleanSig, snrIn);
            noisySig = noisySig / max(abs(noisySig) + eps);

            % Save noisy input and feed it through the effect
            noisyPath = fullfile(tempdir, sprintf('noisy_%s_%02d.wav', test.name, snrIn));
            audiowrite(noisyPath, noisySig, Fs);
            noisyProc = runEffectQuiet(test.func, noisyPath);
            noisyProc = noisyProc(:);
            noisyProc = noisyProc / max(abs(noisyProc) + eps);

            % Align lengths for fair comparison
            L = min(length(cleanProc), length(noisyProc));
            cp = cleanProc(1:L);
            np = noisyProc(1:L);

            % DFT analysis
            N = 8192;
            freq = (0:N/2-1) * (Fs / N);
            half = 1:N/2;

            Y_cleanIn  = abs(fft(cleanSig, N));
            Y_noisyIn  = abs(fft(noisySig, N));
            Y_cleanOut = abs(fft(cp, N));
            Y_noisyOut = abs(fft(np, N));

            specDist = mean(abs(20*log10((Y_cleanOut(half)+eps) ./ (Y_noisyOut(half)+eps))));
            corrVal  = corr(Y_cleanOut(half), Y_noisyOut(half));
            outSNR   = 10*log10(sum(cp.^2) / (sum((cp - np).^2) + eps));

            metrics(i,:) = [snrIn, outSNR, specDist, corrVal];

            fprintf('  Input SNR=%2d dB | Output SNR=%6.2f dB | SpecDist=%5.2f dB | Corr=%.3f\n', ...
                snrIn, outSNR, specDist, corrVal);

            % Per-SNR detailed plot
            fig = figure('Position', [100 100 1400 800], 'Visible', 'off');

            subplot(2,2,1);
            plot(freq, 20*log10(Y_cleanIn(half)/max(Y_cleanIn)+eps), 'b', 'LineWidth', 1.2); hold on;
            plot(freq, 20*log10(Y_noisyIn(half)/max(Y_noisyIn)+eps), 'r--', 'LineWidth', 1);
            title(sprintf('Input: Clean vs Noisy (SNR_{in}=%d dB)', snrIn));
            xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
            legend('Clean','Noisy'); grid on; xlim([0 Fs/2]); ylim([-80 5]);

            subplot(2,2,2);
            plot(freq, 20*log10(Y_cleanOut(half)/max(Y_cleanOut)+eps), 'b', 'LineWidth', 1.2); hold on;
            plot(freq, 20*log10(Y_noisyOut(half)/max(Y_noisyOut)+eps), 'g--', 'LineWidth', 1);
            title('Output: Clean-Processed vs Noisy-Processed');
            xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
            legend('Clean-Proc','Noisy-Proc'); grid on; xlim([0 Fs/2]); ylim([-80 5]);

            subplot(2,2,3);
            plot(freq, 20*log10((Y_noisyIn(half)+eps)./(Y_cleanIn(half)+eps)), 'r', 'LineWidth', 1);
            grid on; xlim([0 Fs/2]);
            title('Input deviation: Noisy/Clean (dB)');
            xlabel('Frequency (Hz)'); ylabel('dB');

            subplot(2,2,4);
            plot(freq, 20*log10((Y_noisyOut(half)+eps)./(Y_cleanOut(half)+eps)), 'g', 'LineWidth', 1);
            grid on; xlim([0 Fs/2]);
            title('Output deviation: Noisy-Proc/Clean-Proc (dB)');
            xlabel('Frequency (Hz)'); ylabel('dB');

            sgtitle(sprintf('%s - Noise Robustness (Input SNR=%d dB)', test.name, snrIn));
            saveas(fig, fullfile(outputDir, sprintf('%s_snr_%02d.png', test.name, snrIn)));
            close(fig);
        end

        % Per-effect summary across SNR levels
        fig = figure('Position', [100 100 1400 400], 'Visible', 'off');
        subplot(1,3,1);
        plot(metrics(:,1), metrics(:,2), '-o','LineWidth',1.5); grid on;
        xlabel('Input SNR (dB)'); ylabel('Output SNR (dB)');
        title('Output vs Input SNR'); set(gca,'XDir','reverse');
        subplot(1,3,2);
        plot(metrics(:,1), metrics(:,3), '-o','LineWidth',1.5); grid on;
        xlabel('Input SNR (dB)'); ylabel('Spectral Distance (dB)');
        title('Spectral Distortion'); set(gca,'XDir','reverse');
        subplot(1,3,3);
        plot(metrics(:,1), metrics(:,4), '-o','LineWidth',1.5); grid on;
        xlabel('Input SNR (dB)'); ylabel('Spectral Correlation');
        title('Spectral Correlation'); set(gca,'XDir','reverse');
        sgtitle(sprintf('%s - Robustness Summary', test.name));
        saveas(fig, fullfile(outputDir, sprintf('%s_summary.png', test.name)));
        close(fig);

        summary{t} = struct('name', test.name, 'metrics', metrics);

        % Write per-test CSV for the report
        csvPath = fullfile(outputDir, sprintf('%s_metrics.csv', test.name));
        fid = fopen(csvPath, 'w');
        fprintf(fid, 'InputSNR_dB,OutputSNR_dB,SpectralDistance_dB,SpectralCorrelation\n');
        fprintf(fid, '%d,%.4f,%.4f,%.4f\n', metrics');
        fclose(fid);
    end

    save(fullfile(outputDir, 'metrics.mat'), 'summary');
    fprintf('\nNoise robustness analysis finished\n');
    fprintf('Figures saved in: %s\n', outputDir);
end

function noisy = addNoise(sig, snrDb)
    % AWGN with controlled SNR. Fall back to manual if Comms Toolbox missing.
    try
        noisy = awgn(sig, snrDb, 'measured');
    catch
        Psig = mean(sig.^2);
        Pn = Psig / 10^(snrDb/10);
        noisy = sig + sqrt(Pn) * randn(size(sig));
    end
end

function out = runEffectQuiet(fn, inputPath)
    % Suppress stdout chatter and stop any queued audio so we don't
    % drown the user in overlapping playbacks across many SNR levels.
    [~, out] = evalc('fn(inputPath)');
    try
        clear playsnd
    catch
    end
end
