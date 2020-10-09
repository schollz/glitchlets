## glitchlets

lets glitch with glitchlets.

![Image](https://user-images.githubusercontent.com/6550035/95544203-52eb2100-09af-11eb-8cce-6699f4ccd043.gif)


this script glitches incoming audio. everything is quantized to the global tempo so it stays somewhat in beat. this script is inspired by a [supercollider script glitching the "amen break"](https://sccode.org/1-1e) and a [recent track by John Frusciante](https://www.youtube.com/watch?v=1q8Yf-vlZg4).

there are five voices for glitching. each voice has individual volume, panning, gating, positions and probabilities. each voice basically is a softcut loop with random tape modulations. along with each voice there is a supercollider engine that adds a wobbly resonant low pass filter to each glitch to get that 90's feel.

future directions:

- fix all the 🐛🐛🐛

### Requirements

- audio input
- norns

### Documentation

**quickstart:** find some music/beat. set norns global tempo in `clock -> tempo` to the music/beat. open glitchlets and press K1+K2. enjoy.

- hold K1 to turn off glitches
- K2 manually glitches
- K3 or K1+K3 switch glitchlet
- E1 switchs parameters
- E2/E3 modulate parameters
- K1+K2 randomizes everything

*note:* make sure to restart norns the first time you install because it has a new supercollider engine that needs to be compiled.

## demo 

<p align="center"><a href="https://www.instagram.com/p/CGG1TPdhdCO/"><img src="https://user-images.githubusercontent.com/6550035/95542191-f89b9180-09a9-11eb-8aac-0f7963cf4135.png" alt="Demo of playing" width=80%></a></p>

## my other norns

- [barcode](https://github.com/schollz/barcode): replays a buffer six times, at different levels & pans & rates & positions, modulated by lfos on every parameter.
- [blndr](https://github.com/schollz/blndr): a quantized delay with time morphing
- [clcks](https://github.com/schollz/clcks): a tempo-locked repeater
- [oooooo](https://github.com/schollz/oooooo): digital tape loops
- [piwip](https://github.com/schollz/piwip): play instruments while instruments play.

## license 

mit 



