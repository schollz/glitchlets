// CroneEngine_Warb
// pulse wave with perc envelopes, triggered on freq
Engine_Warb : CroneEngine {
	var pg;
	var osfun;
	var amp=0.5;
	var endfreq=40;
	var sustain=1;
	var sustainTime=0.1;
	var release=1;
	var attack=0.01;
	var wobble=3;
	var pan=0;
	var bufnum=12;
	var bufnum2=13;
	var recorder;
	var tracker;
	var buffer1;
	var buffer2;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
	    buffer1 = Buffer.alloc(context.server,44100 * 6, 2,bufnum:bufnum); 
		pg = ParGroup.tail(context.xg);
	    SynthDef("Warb", {
			arg out, inL=0, inR=1, freq=440, amp=amp, endfreq=endfreq, attack=attack, release=release, sustain=sustain,sustainTime=sustainTime, wobble=wobble, pan=pan;
			var player, env, sig;
			freq = XLine.ar(freq,endfreq,sustain/4);
			freq = freq.cpsmidi + (LFNoise2.ar(3).range(-1,1) * (1/12));
			freq = freq.midicps;
			player = PlayBuf.ar(2, bufnum2, BufRateScale.kr(bufnum2) * 1, Impulse.ar(freq), startPos: Rand(0,20), doneAction:2, loop: 4) ;
			player = RLPF.ar(player, SinOsc.ar(wobble/sustain).range(20000,80), XLine.ar(0.2,0.9,sustain));
			player= 4*Compander.ar(player, player, 0.1, 1,0.5, 0.01, 0.01);
			env=Env.linen(attackTime:attack, sustainTime: sustainTime, releaseTime: release, level: amp, curve: 'lin').kr(2);
			Out.ar(out, Pan2.ar((player*env), pan));
		}).add;

		SynthDef("Recorder",{
			arg  inL=0,inR=1;
			RecordBuf.ar(In.ar([inL,inR]), bufnum, loop: 1);
			RecordBuf.ar(In.ar([inL,inR]), bufnum2, loop: 1);
		}).add;

		SynthDef("BeatTracker",{
			arg  inL=0;
			var trackb, trackh, trackq, tempo, fft;
			fft = FFT(LocalBuf(1024), PlayBuf.ar(1,buffer1, BufRateScale.kr(buffer1),1,0,1));
			#trackb, trackh, trackq, tempo = BeatTrack.kr(fft, 0);
	        SendTrig.kr(trackb, 0, tempo);
		}).add;


	    osfun = OSCFunc(
	    	{ 
	    		arg msg, time; 
	    		// [time, msg].postln;
				NetAddr("127.0.0.1", 10111).sendMsg("heartbeat",time,msg[3]);   //sendMsg works out the correct OSC message for you
	    	},'/tr', context.server.addr);


	    // Sync with audio norns' sc server
		context.server.sync;
		recorder = Synth("Recorder", [\inL, context.in_b[0].index,\inR, context.in_b[1].index], target:pg);
		tracker = Synth("BeatTracker", [\inL, context.in_b[0].index], target:pg);

		this.addCommand("start","f", { arg msg;
			var val = msg[1];
			buffer2 = Buffer.alloc(context.server,44100 * val, 2,bufnum:bufnum2); 
		});

		this.addCommand("hz", "f", { arg msg;
			var val = msg[1];
			Synth("Warb", [\out, context.out_b,\inL, context.in_b[0].index,\inR, context.in_b[1].index, \freq,val,\amp,amp,\endfreq,endfreq,\attack,attack,\release,release,\sustainTime,sustainTime,\wobble,wobble,\pan,pan], target:pg);
		});

		this.addCommand("amp", "f", { arg msg;
			amp = msg[1];
		});

		this.addCommand("release", "f", { arg msg;
			release = msg[1];
		});

		this.addCommand("sustainTime", "f", { arg msg;
			sustainTime = msg[1];
		});

		this.addCommand("attack", "f", { arg msg;
			attack = msg[1];
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

	free {
		recorder.free;
		tracker.free;
		osfun.free;
		pg.free;
		buffer1.free;
		buffer2.free;
	}
}
