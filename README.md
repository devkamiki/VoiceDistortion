# Voice Distortion Tool

## Using the functions to distort the voice

There are five main functions that could be called to process a certain audio.

### Requirements of input

The input format should be `.wav` or `.m4a`. For `.m4a` files, it's required to run the `preprocessing` function in advance to transform it into `.wav` format.

### Introduction of functions

For each function, it takes one parameter as input (except `Gender_style_conversion()`, specified below), that is to say, the path of the audio file. The output is then written in `\output` path of this folder with the name of `[function name].wav`.

If you provide empty parameter, for example, `filtering()`, it will fallback to process the sample audio of our choice.

|Effect|Fallback sample audio to process | Default style |
|---|---|---|
|Bandpass filter|Soft music| Drop < 300 Hz $\land$ > 3000 Hz |
|Equalizer|Soft music| Low band 1.5x, high band 0.6x |
|Chorus|Cappella female solo|See description below|
|Robotic distortion|Voice of speaking|See description below|
|Gender style conversion|Voice of speaking|Feminine effect|

#### `filtering()`

This is a direct DFT bandpass filter.

This function takes the DFT of the entire signal at once  (`fft`), builds a binary frequency-domain mask that is 1 between 300 Hz and 3000 Hz and 0 everywhere else, multiplies the spectrum by that mask (zeroing out all energy outside the passband), then recovers the time-domain signal with `ifft`. This is the most direct application of the convolution theorem: multiplication in the frequency domain equals convolution with a rectangular filter in the time domain. 



#### `graphicEqualizer()`

Processes the signal in overlapping 1024-sample frames (75% overlap, Hamming window). For each frame it computes the FFT, then applies three different scalar gains to three frequency regions defined as index fractions of N: low band × 1.5, mid band × 1.0, high band × 0.6. The scaled spectrum is sent through `ifft` and the frames are reassembled via overlap-add.

#### `roboticdistortion()`

Same 1024-sample / 75%-overlap STFT structure as the equalizer. For each frame it computes the FFT, circularly shifts the entire spectrum by a small number of bins, and then add to all phases a random phase jittering or resetting all phases to zero (uncomment one of the lines in the function to switch between them). The magnitude envelope is preserved while all phase information is destroyed or jittered. After `ifft` this produces the characteristic flat, metallic robotic sound.

#### `chorus()`

This main function calls a function which is a realization of phase vocoder: `pitchShift(x, fs, semitones, windowLength, overlap)`. It executes the following steps:

- `stft` decomposes the signal into frames, giving a time-frequency grid of complex values
- For each frame and bin, the instantaneous frequency deviation is estimated from the phase difference between consecutive frames.
- To shift pitch by a ratio $\alpha = 2^{(semitones/12)}$, the synthesis phase is accumulated at a scaled rate: $\phi_{syn} = \phi_{syn,prev} + \alpha·\delta \phi + \frac{2\pi·k·hop·(\alpha−1)}{fs}$. This stretches or compresses the instantaneous frequency of every bin by $\alpha$ without changing the playback speed
- `istft` reconstructs the time-domain signal from the modified phases and original magnitudes

`chorus.m` calls `pitchShift` eight times with different semitone values `(−9, −8, −0.22, −0.10, 0, +0.10, +0.22, +0.35)`, delays each voice, and mixes them. It also runs a final DFT-domain EQ (makeWarmAndThick) that boosts 120–350 Hz and 350–800 Hz and rolls off above 3500 Hz, using a single whole-signal `fft`/`ifft` with a smooth frequency-dependent gain curve.

#### `Gender_style_conversion()`

This function takes two variables instead of one: the path to the file to be processed, and the target effect (`masculine` or `feminine`).

Call it as `Gender_style_conversion(inputFile, targetStyle)`.

The core of this function is similar to `chorus()`.

This function converts vocal character between feminine and masculine styles through three successive DFT-based processing steps.
- Pitch shift with `pitchShift` function. Instantaneous frequency per bin is tracked from inter-frame phase differences and accumulated at a scaled rate, then the signal is resampled back to original length. Applied in small stages (≤1.5 semitones each) to avoid artefacts
- Formant scaling. STFT magnitude per frame is split into a smooth spectral envelope `movmean` and harmonic detail. The envelope is warped by interpolating at scaled bin indices (simulating vocal tract length change), then recombined with the detail before ISTFT
- Voice EQ. Single whole-signal `fft`, frequency-dependent scalar gain applied per bin (e.g. boost body/warmth for masculine, boost presence for feminine), then `ifft`.




## Main conclusions from spectrum analysis

`Visualize_compare.m`

## Robust analysis

### Noise robustness

### Resolution

## Web app rewritten in JavaScript