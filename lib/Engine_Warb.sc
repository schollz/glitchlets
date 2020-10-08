// CroneEngine_Warb
// pulse wave with perc envelopes, triggered on freq
Engine_Warb : CroneEngine {
	var pg;
	var amp=0.5;
	var endfreq=40;
	var attack=0.01;
	var release=1;
	var sustain=0.1;
	var wobble=3;
	var pan=0;
	var bufnum=2;
	
	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
	    var  buffer1 = Buffer.alloc(context.server,44100 * 1, 2,bufnum:bufnum); 
		pg = ParGroup.tail(context.xg);
	        SynthDef("Warb", {
			arg out, inL=0, inR=1, freq=440, amp=amp, endfreq=endfreq, attack=attack, release=release, sustain=sustain, wobble=wobble, pan=pan;
			var player, env;
			freq = XLine.ar(freq,endfreq,sustain/4);
			freq = freq.cpsmidi + (LFNoise2.ar(3).range(-1,1) * (1/12));
			freq = freq.midicps;
			RecordBuf.ar(In.ar([inL, inR]), bufnum, doneAction:2, loop: 0);
			player = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum) * 1, Impulse.ar(freq), startPos: Rand(0,20), doneAction:2, loop: 1) ;
			player = RLPF.ar(player, SinOsc.ar(wobble/sustain).range(20000,80), XLine.ar(0.2,0.9,sustain)) ;
			player= 4*Compander.ar(player, player, 0.1, 1,0.5, 0.01, 0.01);
			env=Env.linen(attackTime:attack, sustainTime: sustain, releaseTime: release, level: amp, curve: 'lin').kr(2);
			Out.ar(out, Pan2.ar((player*env), pan));
		}).add;

	    // Sync with audio norns' sc server
		context.server.sync;

		this.addCommand("hz", "f", { arg msg;
			var val = msg[1];
Synth("Warb", [\out, context.out_b,\inL, context.in_b[0].index,\inR, context.in_b[1].index, \freq,val,\amp,amp,\endfreq,endfreq,\attack,attack,\release,release,\sustain,sustain,\wobble,wobble,\pan,pan], target:pg);
		});

		this.addCommand("amp", "f", { arg msg;
			amp = msg[1];
		});

		this.addCommand("release", "f", { arg msg;
			release = msg[1];
		});

		this.addCommand("attack", "f", { arg msg;
			attack = msg[1];
		});

		this.addCommand("sustain", "f", { arg msg;
			sustain = msg[1];
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
