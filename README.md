# Voice Distortion Tool

## Using the functions to distort the voice

There are five main functions that could be called to process a certain audio.

### Requirements of input

The input format should be `.wav` or `.m4a`. For `.m4a` files, it's required to run the `preprocessing` function in advance to transform it into `.wav` format.

### Introduction of functions

For each function, it takes one parameter as input, that is to say, the path of the audio file. The output is then written in `\output` path of this folder with the name of `[function name].wav`.

If you provide empty parameter, for example, `filtering()`, it will fallback to process the sample audio of our choice.

|Effect|Fallback sample audio to process|
|---|---|
|Bandpass filter|Soft music|
|Equalizer|Soft music|
|Chorus|Cappella female solo|
|Robotic distortion|Voice of speaking|
|Gender style conversion|Voice of speaking|

#### `filtering()`

This is a direct DFT bandpass filter.

This function takes the DFT of the entire signal at once  (`fft`), builds a binary frequency-domain mask that is 1 between 300 Hz and 3000 Hz and 0 everywhere else, multiplies the spectrum by that mask (zeroing out all energy outside the passband), then recovers the time-domain signal with `ifft`. This is the most direct application of the convolution theorem: multiplication in the frequency domain equals convolution with a rectangular filter in the time domain. 

#### `Gender_style_conversion()`

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




#### 

### Main conclusions from spectrum analysis

`Visualize_compare.m`

### Robust analysis

#### Noise robustness

#### Resolution

### Web app rewritten in JavaScript