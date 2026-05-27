# Voice Distortion Tool

## License 

The code from this repository is licensed under [AGPL-3.0](https://github.com/devkamiki/VoiceDistortion?tab=AGPL-3.0-1-ov-file).

All the sample audio clips except `singing-sample.wav` are downloaded from https://samplefile.com, and usages of them must follow their [ToS](https://samplefile.com/terms-of-service). `singing-sample.wav` is downloaded from https://samplefocus.com/, license of which could be found [here](https://samplefocus.com/license).

## Roadmaps

### Flowchart
```mermaid
flowchart TD
  
  A[Deciding Goals of voice distortion program] --> B[Search for similar projects and how they realized it] --> C[Note down theories and functions used in the program] --> D[Code implementation]
  E[Deciding Goals for web app] --> F[Research for necessary tools for frontend] --> G[Code the frontend]
 E --> H[Research for necessary tools for backend] --> I[Code the backend]
 J[Deploy the website to vercel]
 D --> J
 G --> J
 I --> J
 K[Write the video script, including narrative and scenes]
 L[Record the video]
 J --> L
 K --> L
 N[Reflection on AI assisted reasoning]
 O["run_me" file]
 L --> M[Submitting source code, video, and reflection]
 O --> M
 N --> M
 P[Code robust analysis]
 P-->O
```
### Core
- [x] Low/high pass filtering
- [ ] Equalizer
- [x] Robotic distortion
- [ ] Chorus
- [x] Noise elimination

Preprocessing is a function, to do robotic distortion, run these: in order `noisereduction.m` -> `roboticdistortion.m` 

### Frontend

### Backend

### Robustness Analysis

### Misc
- [ ] `run_me`
- [ ] adjustable extend/strength of effect

```mermaid
flowchart TD

A[noisereduction.m] --> B[roboticdistortion.m]

A --> C[filtering.m]

A --> D[equalizer.m]


```

## Tutorials on how to use sample files
`music-sample.wav` is for testing `filtering.m`.

`voice-sample.wav` is for testing `roboticdistortion.m`.