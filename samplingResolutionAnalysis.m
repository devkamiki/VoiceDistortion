function samplingResolutionAnalysis()

    outputDir = fullfile('results', 'sampling_resolution');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Integer downsampling factors relative to each file's native Fs.
    % factor 1 = full rate (the original / baseline reference).
    % Each extra factor = one more full (expensive) effect run per test, so
    % we keep just the original plus one representative heavy downsample.
    factors = [1, 4];

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

        procRef  = processAtRate(test.func, cleanSig, Fs);
        procRef  = procRef(:) / max(abs(procRef) + eps);
        Yref     = avgSpectrum(procRef, N);     % averaged over whole signal
        refDb    = 20*log10(Yref(half)/max(Yref) + eps);
        freqRef  = (0:N/2-1) * (Fs / N);

        fig = figure('Position', [100 100 1100 800], 'Visible', 'off');

        ax1 = subplot(2,1,1, 'Parent', fig);
        hold(ax1, 'on');
        legend1 = {};

       
        dsFreq = cell(1, length(factors));
        dsDb   = cell(1, length(factors));

        for k = 1:length(factors)
            M = factors(k);
            FsDs = round(Fs / M);

            if M == 1
                freq = freqRef;
                yDb  = refDb;
            else
                sigDs = resample(cleanSig, 1, M);           % polyphase + LPF
                procDs = processAtRate(test.func, sigDs, FsDs);
                procDs = procDs(:) / max(abs(procDs) + eps);
                freq = (0:N/2-1) * (FsDs / N);
                Y    = avgSpectrum(procDs, N);
                yDb  = 20*log10(Y(half)/max(Y) + eps);
            end

            dsFreq{k} = freq;
            dsDb{k}   = yDb;

            plot(ax1, freq, yDb, 'LineWidth', 1.2);
            if M == 1
                legend1{end+1} = sprintf('M=1  ORIGINAL (Fs=%d Hz, Ny=%d Hz)', ...
                                         Fs, round(Fs/2)); %#ok<AGROW>
            else
                legend1{end+1} = sprintf('M=%d  (Fs=%d Hz, Ny=%d Hz)', ...
                                         M, FsDs, round(FsDs/2)); %#ok<AGROW>
            end
        end

        title(ax1, sprintf(['%s  -  original (M=1) vs downsampled ' ...
            '(band ends at each Nyquist)'], test.name));
        xlabel(ax1, 'Frequency (Hz)'); ylabel(ax1, 'Magnitude (dB)');
        legend(ax1, legend1, 'Location', 'southwest');
        grid(ax1, 'on'); xlim(ax1, [0 Fs/2]); ylim(ax1, [-80 5]);

        % ============ Subplot 2: deviation from the original ==============
        % For each downsampled spectrum, interpolate the ORIGINAL onto the
        % same (finer) frequency grid over the shared band [0, Fs_ds/2] and
        % plot (downsampled - original) in dB. Flat ~0 means the spectral
        % conclusions are unchanged by downsampling.
        ax2 = subplot(2,1,2, 'Parent', fig);
        hold(ax2, 'on');
        legend2 = {};

        for k = 2:length(factors)                            % skip M=1 (==0)
            freq = dsFreq{k}(:);
            refOnGrid = interp1(freqRef, refDb, freq, 'linear');
            diffDb = dsDb{k}(:) - refOnGrid(:);              % force column: avoid N/2 x N/2 broadcast
            plot(ax2, freq, diffDb, 'LineWidth', 1.0);
            FsDs = round(Fs / factors(k));
            legend2{end+1} = sprintf('M=%d  (vs original, band to %d Hz)', ...
                                     factors(k), round(FsDs/2)); %#ok<AGROW>
        end
        yline(ax2, 0, 'k--');

        title(ax2, sprintf(['%s  -  deviation of downsampled spectrum ' ...
            'from the original (dB)'], test.name));
        xlabel(ax2, 'Frequency (Hz)'); ylabel(ax2, '\Delta Magnitude (dB)');
        legend(ax2, legend2, 'Location', 'southwest');
        grid(ax2, 'on'); xlim(ax2, [0 Fs/2]); ylim(ax2, [-40 40]);

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

% --- Welch-style averaged magnitude spectrum over the WHOLE signal --------
% Avoids the trap of fft(sig, N) using only the first N samples, which can
% be silent (vocoder latency / leading delays) and yield max(Y)=0 -> NaN.
function mag = avgSpectrum(sig, N)
    sig = sig(:);
    if numel(sig) < N
        sig = [sig; zeros(N - numel(sig), 1)];
    end
    win  = hann(N, 'periodic');
    hop  = N / 2;                                   % 50% overlap
    nFr  = 1 + floor((numel(sig) - N) / hop);
    acc  = zeros(N, 1);
    for i = 1:nFr
        s     = (i-1)*hop + 1;
        frame = sig(s:s+N-1) .* win;
        acc   = acc + abs(fft(frame));
    end
    mag = acc / max(nFr, 1);
end
