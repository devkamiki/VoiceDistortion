function y = pitchShift(x, fs, semitones, windowLength, overlap)
    if nargin < 5
        overlap = round(0.75 * windowLength);
    end
    hop = windowLength - overlap;

    % Pitch shift ratio
    alpha = 2^(semitones/12); 

    % STFT 
    win = hamming(windowLength, 'periodic');
    [S, F, ~] = stft(x, fs, 'Window', win, 'OverlapLength', overlap, ...
                     'FFTLength', windowLength, 'Centered', false);

    % Phase shift
    numFrames = size(S, 2);
    phi = zeros(size(S));
    phi(:,1) = angle(S(:,1));

    for n = 2:numFrames
        delta_phi_ana = 2*pi * F * hop / fs;
        delta_phi = angle(S(:,n)) - angle(S(:,n-1)) - delta_phi_ana;
        delta_phi = delta_phi - 2*pi * round(delta_phi/(2*pi)); 
        delta_phi_syn = delta_phi * alpha + 2*pi * F * hop * (alpha - 1) / fs;
        phi(:,n) = phi(:,n-1) + delta_phi_syn;
    end

    Y = abs(S) .* exp(1i * phi);

    % ISTFT Synthesis
    y = istft(Y, fs, 'Window', win, 'OverlapLength', overlap, ...
              'FFTLength', windowLength, 'Centered', false);

    %  Safe length trimming
    originalLength = length(x);
    if length(y) > originalLength
        y = y(1:originalLength);
    elseif length(y) < originalLength
        y = [y; zeros(originalLength - length(y), 1)];
    end

    y = real(y);  % Ensure real signal
end