// CroneEngine_Warb
// pulse wave with perc envelopes, triggered on freq
Engine_Warb : CroneEngine {
	var pg;
	var amp=0.5;
	var endfreq=40;
	var sustain=1;
	var release=1;
	var wobble=3;
	var pan=0;
	
	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		pg = ParGroup.tail(context.xg);
	        SynthDef("Warb", {
			arg out, freq=440, amp=amp, endfreq=endfreq, release=release, sustain=sustain, wobble=wobble, pan=pan;
			var player, env;
			freq = XLine.ar(freq,endfreq,sustain/4);
			freq = freq.cpsmidi + (LFNoise2.ar(3).range(-1,1) * (1/12));
			freq = freq.midicps;
			player = RLPF.ar(Saw.ar(freq, 0.1)+WhiteNoise.ar(0.05), SinOsc.ar(wobble/sustain).range(20000,80), XLine.ar(0.2,0.9,sustain));
			player= Compander.ar(player, player, 0.1, 1, 1/8, 0.002, 0.01);
			env = Env.perc(level:amp, releaseTime:release).kr(2);
			Out.ar(out, Pan2.ar((player*env), pan));
		}).add;

		this.addCommand("hz", "f", { arg msg;
			var val = msg[1];
Synth("Warb", [\out, context.out_b, \freq,val,\amp,amp,\endfreq,endfreq,\release,release,\sustain,sustain,\wobble,wobble,\pan,pan], target:pg);
		});

		this.addCommand("amp", "f", { arg msg;
			amp = msg[1];
		});

		this.addCommand("release", "f", { arg msg;
			release = msg[1];
		});

		this.addCommand("endfreq", "f", { arg msg;
			endfreq = msg[1];
		});
		
		this.addCommand("wobble", "f", { arg msg;
			wobble = msg[1];
		});
		
		this.addCommand("pan", "f", { arg msg;
		  postln("pan: " ++ msg[1]);
			pan = msg[1];
		});
	}
}
