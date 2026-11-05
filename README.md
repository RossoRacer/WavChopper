WavChopper
==========

WavChopper splits a wavetable .wav file into individual single-cycle waves.

<img width="909" height="459" alt="image" src="https://github.com/user-attachments/assets/c8b3a8f3-d915-4446-b5ae-64794cdc500f" />


How to use
----------
1. Choose the cycle size with the row of buttons at the top:
   128, 256, 512, 1024 or 2048 samples.
2. Drag one or more .wav files onto the drop area.
3. The app creates a new folder next to each original file, named after it
   with the cycle size added, e.g. "MyTable_2048".
4. Inside that folder, each cycle is saved as its own .wav file, numbered in
   order, e.g. "MyTable_2048_001.wav", "MyTable_2048_002.wav", and so on.

Notes
-----
- The audio is copied as-is into each new file, so sample rate, bit depth
  (16/24/32-bit integer or 32-bit float) and channel count are unchanged.
  Nothing is resampled or converted.
- The total length of the source file must divide evenly by the chosen cycle
  size. If it doesn't, nothing is written and the log in the window explains why.
- The log at the bottom of the window shows a result line for each file dropped.
- The app needs permission to create folders next to your files. When building
  in Xcode, remove App Sandbox under Signing & Capabilities.

## Getting the code

**Clone with git**

```
git clone https://github.com/RossoRacer/WavChopper.git
cd WavChopper
open WavChopper.xcodeproj
```

**Or download a ZIP**

1. On the repo page, click the green **Code** button.
2. Choose **Download ZIP** and unzip it.
3. Double-click `WavChopper.xcodeproj` to open it in Xcode.

## Building

1. Open `WavChopper.xcodeproj` in Xcode (macOS only).
2. If Xcode complains about signing, select the WavChopper target, go to
   Signing & Capabilities, and choose your own team or "Sign to Run Locally".
3. Press Run (⌘R).

The app needs App Sandbox turned off so it can create folders next to the
files you drop. This is already set in the project.
