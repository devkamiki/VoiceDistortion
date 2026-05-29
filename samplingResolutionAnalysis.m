function samplingResolutionAnalysis()
% SAMPLINGRESOLUTIONANALYSIS  Stress test: sampling rate / effective resolution.
%
% For each voice-distortion effect this script reduces the sampling rate of
% the input before processing and studies the effect on the DFT-based
% conclusions. Two downsampling methods are compared at every rate:
%
%   * "resample"  - polyphase decimation WITH an anti-aliasing low-pass.
%                   Shows genuine LOSS OF INFORMATION: everything above the
%                   new Nyquist (Fs_ds/2) is removed and cannot be recovered.
%   * "decimate"  - naive keep-every-Mth-sample WITHOUT any anti-alias
%                   filter. Shows ALIASING: energy above Fs_ds/2 folds back
%                   into the baseband as spurious peaks.
%
% The frequency resolution of a length-N DFT is df = Fs/N, so lowering Fs
% (with N fixed) also makes each bin finer in Hz while shrinking the usable
% band [0, Fs/2] -- the "effective resolution" trade-off.


    outputDir = fullfile('results', 'sampling_resolution');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Integer downsampling factors relative to each file's native Fs.
    % factor 1 = full rate (baseline), 6 = aggressive (heavy band-limiting).
    factors = [1, 2, 4, 6];

    tests = { ...
        struct('name','Robotic',  'func',@roboticdistortion, 'input','inputfiles/voice-sample.wav'), ...
        struct('name','Equalizer','func',@graphicEqualizer,  'input','inputfiles/music-sample.wav'), ...
        struct('name','Filter',   'func',@filtering,         'input','inputfiles/music-sample.wav'), ...
        struct('name','Chorus',   'func',@chorusOrig,                                          'input','inputfiles/singingm4a-sample.wav'), ...
        struct('name','GenderF',  'func',@(f) Gender_style_conversion(f, "feminine"),          'input','inputfiles/voice-sample.wav'), ...
        struct('name','GenderM',  'func',@(f) Gender_style_conversion(f, "masculine"),         'input','inputfiles/vocals_F.wav') ...
    };

    N = 8192;            % DFT size used for every spectrum
    half = 1:N/2;

    for t = 1:length(tests)
        test = tests{t};
        fprintf('\n=== %s ===\n', test.name);

        [cleanSig, Fs] = audioread(test.input);
        cleanSig = mean(cleanSig, 2);                       % force mono
        cleanSig = cleanSig / max(abs(cleanSig) + eps);

        % --- Baseline: process at the original (full) sampling rate -------
        fullProc = processAtRate(test.func, cleanSig, Fs);
        fullProc = fullProc(:) / max(abs(fullProc) + eps);

        fig = figure('Position', [100 100 1100 800], 'Visible', 'off');

        % ============ Subplot 1: proper (anti-aliased) downsampling =======
        ax1 = subplot(2,1,1, 'Parent', fig);
        hold(ax1, 'on');
        legend1 = {};
        fprintf('  Anti-aliased downsampling (resample) vs naive decimation:\n');
        fprintf('  %-8s | %-9s | reconstruction SNR (dB)\n', 'factor', 'Fs (Hz)');
        fprintf('  %-8s | %-9s | %-12s %-12s\n', '', '', 'resample', 'decimate');

        for k = 1:length(factors)
            M = factors(k);
            FsDs = round(Fs / M);

            % --- proper, anti-aliased downsampling -> information loss ----
            if M == 1
                sigDs = cleanSig;
            else
                sigDs = resample(cleanSig, 1, M);           % polyphase + LPF
            end
            procDs = processAtRate(test.func, sigDs, FsDs);
            procDs = procDs(:) / max(abs(procDs) + eps);

            freq = (0:N/2-1) * (FsDs / N);
            Y = abs(fft(procDs, N));
            plot(ax1, freq, 20*log10(Y(half)/max(Y) + eps), 'LineWidth', 1.2);
            legend1{end+1} = sprintf('M=%d  (Fs=%d Hz, Ny=%d Hz)', ...
                                     M, FsDs, round(FsDs/2)); %#ok<AGROW>

            % --- naive decimation (no anti-alias) -> aliasing -------------
            if M == 1
                sigAlias = cleanSig;
            else
                sigAlias = cleanSig(1:M:end);               % keep every Mth
            end
            procAlias = processAtRate(test.func, sigAlias, FsDs);
            procAlias = procAlias(:) / max(abs(procAlias) + eps);

            % --- quantify: bring both back to full rate and compare -------
            snrResample = reconstructionSNR(procDs,    M, fullProc);
            snrDecimate = reconstructionSNR(procAlias, M, fullProc);
            fprintf('  %-8d | %-9d | %-12.2f %-12.2f\n', ...
                    M, FsDs, snrResample, snrDecimate);

            % Stash the most aggressive case for the aliasing subplot.
            if k == length(factors)
                aliasDemo = struct('FsDs',FsDs,'M',M, ...
                                   'proper',procDs,'naive',procAlias);
            end
        end

        title(ax1, sprintf(['%s  -  anti-aliased downsampling ' ...
            '(information loss above each Nyquist)'], test.name));
        xlabel(ax1, 'Frequency (Hz)'); ylabel(ax1, 'Magnitude (dB)');
        legend(ax1, legend1, 'Location', 'southwest');
        grid(ax1, 'on'); xlim(ax1, [0 Fs/2]); ylim(ax1, [-80 5]);

        % ============ Subplot 2: aliasing demonstration ===================
        ax2 = subplot(2,1,2, 'Parent', fig);
        hold(ax2, 'on');
        freqA = (0:N/2-1) * (aliasDemo.FsDs / N);

        Yp = abs(fft(aliasDemo.proper, N));
        Yn = abs(fft(aliasDemo.naive,  N));
        plot(ax2, freqA, 20*log10(Yp(half)/max(Yp) + eps), 'b', 'LineWidth', 1.2);
        plot(ax2, freqA, 20*log10(Yn(half)/max(Yn) + eps), 'r', 'LineWidth', 1.0);

        title(ax2, sprintf(['M=%d (Fs=%d Hz): anti-aliased vs naive ' ...
            'decimation - red shows aliased energy folded into the band'], ...
            aliasDemo.M, aliasDemo.FsDs));
        xlabel(ax2, 'Frequency (Hz)'); ylabel(ax2, 'Magnitude (dB)');
        legend(ax2, {'resample (anti-aliased)', 'decimate (aliased)'}, ...
               'Location', 'southwest');
        grid(ax2, 'on'); xlim(ax2, [0 aliasDemo.FsDs/2]); ylim(ax2, [-80 5]);

        saveas(fig, fullfile(outputDir, sprintf('%s.png', test.name)));
        close(fig);
    end

    fprintf('\nDone. Figures saved in: %s\n', outputDir);
end

% --- run an effect on an in-memory signal at a given sample rate ----------
function out = processAtRate(fn, sig, Fs)
    p = fullfile(tempdir, sprintf('sr_%d_%d.wav', Fs, round(rand*1e6)));
    audiowrite(p, sig / max(abs(sig) + eps), Fs);
    [~, out] = evalc('fn(p)');
    try
        clear playsnd
    catch
    end
    if exist(p, 'file'); delete(p); end
end

% --- reconstruction SNR: upsample processed-downsampled output back to ----
% --- the full rate and compare against the full-rate processed output -----
function snrVal = reconstructionSNR(procDs, M, fullProc)
    if M == 1
        up = procDs;
    else
        up = resample(procDs, M, 1);
    end
    L = min(length(up), length(fullProc));
    ref = fullProc(1:L);
    est = up(1:L);
    est = est / (max(abs(est)) + eps) * (max(abs(ref)) + eps);  % match level
    snrVal = 10*log10(sum(ref.^2) / (sum((ref - est).^2) + eps));
end
