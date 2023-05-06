/*
CHAOTIC METROPOLIS, A CPSC 432 final project composition By Noah Weiner (nsw25)

INSTRUCTIONS FOR PLAYING:

1. Boot the server.
2. Click to the right of the left parenthesis on line 21. Then run that code block, waiting for it to complete. You should see "a Task" in the Post window.
3. Once that first code block is run, scroll down to the bottom of the document to line 761 and run the line "t.play(~tc);" to hear the song.

Any time you stop the song using CMD + ., you'll need to re-run the first code block before running "t.play(~tc);" again.
*/


//r = Recorder(s);
//r.record(numChannels:2);
//Server.default.record;

Env.new(levels: [1, 1, 0], times: [5, 5]).plot;


(
//get the server instance
~server = Server.local;

//run buffer read-ins and synthdefs in a task, waiting for asynchronous ops to finish
Task.new({

//set up tempo and TempoClock
~bpm = 60;
~tc = TempoClock(~bpm / 60);


//wild irish roses seq notes: d, c, f. g, f, d.
//in midi: 50, 48, 53. 55, 53, 50.

~sr = 44100;


//read in audio files
~l = Buffer.read(~server, "samp/kl_love.mp3".resolveRelative, ~sr * 3.7, ~sr * 1);
~w = Buffer.read(~server, "samp/irish_roses.mp3".resolveRelative, ~sr * 6.5, ~sr * 0.4);
~c = Buffer.read(~server, "samp/coldheart.mp3".resolveRelative, ~sr * 71.8, ~sr * 4.1);
~d = Buffer.read(~server, "samp/ideservepiano.mp3".resolveRelative,  ~sr * 44, ~sr * 3);
~irChurchFar = Buffer.read(~server, "sf/st_georges_far.wav".resolveRelative);

~server.sync;

//FFT window size for Conv operations
~fftsz = 2048;

~bufsz = PartConv.calcBufSize(~fftsz, ~irChurchFar);
~impResp = Buffer.alloc(~server, ~bufsz, 1);
~impResp.preparePartConv(~irChurchFar, ~fftsz);

~server.sync;

//BEGIN SYNTHDEFS------------------------------------------------------------

SynthDef(\loveandlust, {| buf, out = 0, ampl = 0.1, kernel|
	var in, freqdom, res, line, noise;

	//play the buffer into a var
	in = PlayBuf.ar(1, buf, BufRateScale.kr(buf)*0.6, loop: 0);
	//run FFT
	freqdom = FFT(LocalBuf(2048), in);

	line = Line.kr(360, 1, 1);

	//shift phase
	freqdom = PV_PhaseShift(freqdom, line);

	res = 0.2 * IFFT(freqdom);

	res = ampl * PartConv.ar(res, ~fftsz, ~impResp, 0.7);

	//free self when the convolution pitters out
	DetectSilence.ar(res, 0.001, 0.1, doneAction: 2);

	//convert back to time domain
	Out.ar(out, res ! 2);
}).add;



SynthDef(\longtime_muted, {| buf_main, buf_convwith, out = 0, ampl = 0.5, kernel|
	var in, freqdom, res, line, noise, mod, env;

	res = Convolution.ar(PlayBuf.ar(1, buf_main, loop:0) * 0.1, PlayBuf.ar(1, buf_convwith, loop:0) * 0.02, 2048);

	//TO AVOID POPPING: once sample plays, fade it out slowly and free synth
	env = Env.new([1, 1, 0], [5, 2]).kr(2);

	//convert back to time domain
	Out.ar(out, res*env*ampl ! 2);
}).add;



SynthDef(\longtime, {| buf, out = 0, kernel, ampl = 0.5|
	var in, freqdom, res, line, noise, mod, env;

	//play the buffer into a var
	in = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * 0.9, loop: 0);

	mod = SinOsc.ar(70, mul: 100);

	//run FFT
	freqdom = FFT(LocalBuf(2048), in);

	freqdom = PV_PhaseShift(freqdom, SinOsc.kr(0.2, 0, 180, 180));

	res = 0.2 * IFFT(freqdom);

	res = PartConv.ar(res, ~fftsz, ~impResp, 0.7) * 0.1;

	//res = CombC.ar(in, 1, SinOsc.kr(0.5, 0, 0.5, 0.6), 0.2);

	//TO AVOID POPPING: once sample plays, fade it out slowly and free synth
	env = Env.new([1, 1, 0], [5, 2]).kr(2);

	//output signal mult by env
	Out.ar(out, res*env*ampl ! 2);
}).add;


SynthDef(\longtimesweep, { | buf, out = 0, ampl = 0.01 |
	var in, env;

	in = PlayBuf.ar(1, buf, BufRateScale.kr(buf)*0.8, loop: 0);

	in = in * SinOsc.ar(Line.kr(1, 700, 5));

	//TO AVOID POPPING: once sample plays, fade it out slowly and free synth
	env = Env.new([1, 1, 0], [4, 1]).kr(2);

	Out.ar(out, in * ampl * env ! 2);
}).add;


SynthDef(\ideserve, { | buf, out = 0, ampl 0.4 |
	var in, env, sig;

	in = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * 0.9, loop: 0);

	//once sample plays, fade it out slowly and free synth
	env = Env.new([1, 1, 0], [5, 2]).kr(2);

	//RLPF: SC uses reciprocal of Q (RQ). Max Q value is 1.
	//smaller rq values -> narrower bandwidth of band stop zone. higher Q -> closer the filter to being perfect
	sig = RLPF.ar(in, SinOsc.ar(0.125, mul: 200, add: 500), 0.01);

	Out.ar(out, sig*ampl*env ! 2);
}).add;



//MULTI-CARRIER F
SynthDef(\staticy, { | out = 0, ampl = 1, freq = 69.30, gate = 1 |
	//carrier amplitudes
	var amps = [1, 3, 0.2, 1].normalizeSum; //makes these ampls sum to 1

	//the modulator
	var mod = SinOsc.ar(freq, mul: 500);

	//the carriers
	var car1 = SinOsc.ar(freq*1 + mod, mul: amps[0]) * LFNoise1.kr(10, 1);
	var car2 = SinOsc.ar(freq*1.5 + mod, mul: amps[1]) * LFNoise1.kr(10, 1);
	var car3 = SinOsc.ar(freq*6 + mod, mul: amps[2]) * LFNoise1.kr(10, 1);
	var car4 = SinOsc.ar(freq*4.79 + mod, mul: amps[3]) * LFNoise1.kr(10, 1);

	var env;

	s = car1 + car2 + car3 + car4;

	e = EnvGen.kr(Env.adsr(0.2, 0.1, 1, 0.8, 1, \sin), doneAction: 2, gate: gate);

	//adsr args: attacktime, decaytime, sustainlvl (fraction of peak lvl), releasetime, peaklevel, curve
	Out.ar(out, s * e * ampl ! 2);
}).add;


//MULTI-MODULATOR FM (chained)
SynthDef(\mmfm, { | freq = 50, out = 0, ampl = 0.04 |
	var mod1, mod2, car, env;

	//I2 multiplier = number of sig sidebands in modulator
	mod2 = SinOsc.ar(freq, mul: 50);

	//I1 multiplier = total output sidebands
	mod1 = SinOsc.ar(100 + mod2, mul: 300);

		car = Pan2.ar(SinOsc.ar(mod1 + XLine.kr(1, 500, 10)), SinOsc.kr(XLine.kr(1, 50, 10)));

	//fade out after a while
	env = Env.new(levels: [1, 1, 0], times: [20, 5]).kr(2);
	Out.ar(out, car * ampl * env);
}).add;


SynthDef(\rose_sweep, { | out=0, mul_start=1, mul_end=3, sweepDur=3, freq = 150, ampl = 1, dur = 3.0, pan = 0.0, panDur = 3, attackTime = 0.8, releaseTime = 0.9, gate = 1, freqsNoiseMult = 10, amplsNoiseMult = 2, freqs = #[156, 195, 233, 295, 395, 468, 576, 602, 637, 856, 905, 953, 1409, 684, 713, 797, 857, 1205, 1336, 760, 702, 950, 1006, 1059, 1127, 1160, 1279], amplSpect = #[-47, -37.7, -34.2, -23.3, -32.9, -29.3, -34.5, -33.7, -38.2, -47, -48.3, -55.5, -53.2, -62, -44.6, -45.3, -46.8, -47.7, -55.8, -63.2, -45.4, -46, -54, -57, -65.1, -58.6, -59.2, -64.5, -64.5] |
	var numPartials, partialFreqNoises, partialAmplNoises, env;

	//number of total partials we have
	numPartials = freqs.size;

	//fill an array with some LFNoise1 objects to slightly vary each of the partials' frequencies over time
	partialFreqNoises = Array.fill(numPartials, { |i|
		LFNoise1.kr(10, freqsNoiseMult);
	}
	);

	//fill an array with some LFNoise1 objects to slightly vary each of the partials' amplitudes over time
	partialAmplNoises = Array.fill(numPartials, { |i|
		LFNoise1.kr(10, amplsNoiseMult);
	}
	);

	//convert db to amplitudes
	a = 10.pow(amplSpect / 20);


	b = Pan2.ar( //pan to position (user-passed arg)
		SinOsc.ar(freq: freqs*Line.kr(mul_start, mul_end, sweepDur) + partialFreqNoises, mul: a + partialAmplNoises), Line.kr(-1, 1, panDur));

	//wrapped it in BandStop filter because the low-freq tail ampl was too big
	c = BBandStop.ar(HPF.ar(b + BPF.ar(BrownNoise.ar(), 25, 1), 150), freq: 25, bw: 10);

	//cut out high-freq components
	10.do {
		c = LPF.ar(c, 700);
	};

	//attacktime, decaytime, sustainlvl, releasetime, peaklvl, curve
	env = EnvGen.kr(Env.adsr(0.2, 0.8, 0.2, 10, 1, -4), doneAction: 2, gate: gate);

	s = FreeVerb.ar(c, 0.33, 0.8);

	Out.ar(out, s * env * ampl);
}).add;



SynthDef(\rose, { | out=0, sweepDur=3, freq = 156, ampl = 1, dur = 1, pan = 0.0, panDur = 3, attackTime = 0.8, releaseTime = 0.8, gate = 1, freqs = #[156, 195, 233, 295, 395, 468, 576, 602, 637, 856, 905, 953, 1409, 684, 713, 797, 857, 1205, 1336, 760, 702, 950, 1006, 1059, 1127, 1160, 1279], amplSpect = #[-47, -37.7, -34.2, -23.3, -32.9, -29.3, -34.5, -33.7, -38.2, -47, -48.3, -55.5, -53.2, -62, -44.6, -45.3, -46.8, -47.7, -55.8, -63.2, -45.4, -46, -54, -57, -65.1, -58.6, -59.2, -64.5, -64.5], freqsNoiseMult = 5, amplsNoiseMult = 0.8, vib = 0.5 |
	var numPartials, partialFreqNoises, partialAmplNoises, vibMultiplier, mults;

	mults = [ 1.0, 1.25, 1.4935897435897, 1.8910256410256, 2.5320512820513, 3.0, 3.6923076923077, 3.8589743589744, 4.0833333333333, 5.4871794871795, 5.8012820512821, 6.1089743589744, 9.0320512820513, 4.3846153846154, 4.5705128205128, 5.1089743589744, 5.4935897435897, 7.724358974359, 8.5641025641026, 4.8717948717949, 4.5, 6.0897435897436, 6.4487179487179, 6.7884615384615, 7.224358974359, 7.4358974358974, 8.1987179487179 ];

	f = freq * mults;

	//number of total partials we have
	numPartials = freqs.size;

	vibMultiplier = 0.3;

	//fill an array with some LFNoise1 objects to slightly vary each of the partials' frequencies over time
	partialFreqNoises = Array.fill(numPartials, { |i|
		LFNoise1.kr(10, freqsNoiseMult);
	}
	);

	//fill yet another array with some more LFNoise1 objects to slightly vary each of the partials' amplitudes over time
	//fill an array with some LFNoise1 objects to slightly vary each of the partials' frequencies over time
	partialAmplNoises = Array.fill(numPartials, { |i|
		LFNoise1.kr(10, amplsNoiseMult);
	}
	);

	//convert db to amplitudes
	a = 10.pow(amplSpect / 20);

	b = Pan2.ar( //pan to position (user-passed arg)
		Mix( //mix down to single channel
			SinOsc.ar(
				freq: f + partialFreqNoises + //add some slight noise variation over time to each partial freq
				(SinOsc.ar(5, mul: vibMultiplier * freq) * //add vibrato using frequency oscillation
				Env.linen(3.0, dur, 0.9, 1, \sine).kr() //vibrato should fade in (not start right away)
				),
				mul: a * //amplitudes array
				Env.linen(attackTime, dur, releaseTime, 1, \sine).kr(doneAction: 2)) * ampl + //adjust overall env ampl based on arg passed
			    partialAmplNoises + //add some slight noise variation over time to each partial amplitude
			    PinkNoise.ar(ampl * Env.linen(attackTime, dur, releaseTime, 0.005, \sine).kr(doneAction: 2)) //add in bow noise with same envelope shape as the SinOsc mul envelope
		),
		pan);

	//to try to better mimic freqscope of original, I made some PinkNoise and filtered it until I saw the flat low-freq tail around -70 dB that's present on the original. I added this to the rest of signal
	//wrapped it in BandStop filter because the low-freq tail ampl was too big
	c = BBandStop.ar(HPF.ar(b + BPF.ar(PinkNoise.ar(), 25, 1) ! 2, 150), freq: 25, bw: 10);

	//hella high-order lowpass filter to really cut out a lot of the high-freq components (which is necessary based on freqscope of original)
	10.do {
		c = LPF.ar(c, 800);
	};

	e = EnvGen.kr(Env.adsr(0.2, 0.1, 1, 0.8, 1, \sin), doneAction: 2, gate: gate);

	s = FreeVerb.ar(c, 0.33, 0.8);

	Out.ar(out, s * e * ampl);
}).add;



SynthDef(\balloonpop, { | out = 0, pan = 0, ampl = 0.05 |
	var env, pop, sig, echo;

	//attacktime, releasetime
	env = Env.perc(0, 5);

	//create the content using low-freq noise
	pop = BrownNoise.ar(EnvGen.kr(env, doneAction: 2));

	sig = Pan2.ar(pop, pan);

	//create echo/verb
	echo = Greyhole.ar(sig, 0.1, 0.1, 1, 0.707, 0.1, 0.01, 2
    );

	Out.ar(out, echo * ampl);
}).add;



SynthDef(\ping, { | out = 0, ampl = 0.1, pan=0 |
	var imp, sig, env;

	//generate impulses
	imp = Impulse.ar([2, 3], [0, 0.3], 0.15);

	//pass impulses into ringing filter
	sig = Ringz.ar(imp, [250, 500], 3);

	sig = Pan2.ar(Mix.ar(sig), pan);

	//envelope: fade out after 20 sec of pinging
	env = Env.new(levels: [1, 1, 0], times: [0.5, 0.5]).kr(2);

	Out.ar(out, sig*ampl*env);
}).add;


//crackling staticy drone sound using pulse wave
SynthDef(\pulsedrone, { | out = 0, ampl = 0.4 |
	var sig, env;

	sig = Pulse.ar([350, 300] / 4, 0.3, 0.2);

	//reduce to depth of just 4 bits to lower quality (chiptune)
	//mix down to single channel
	sig = Mix.ar(Decimator.ar(sig, bits: 4));

	sig = Pan2.ar(sig, SinOsc.kr(1));

	//attacktime, sustaintime, releasetime, lvl, curve
	env = Env.linen(10, 10, 10, 1).kr(2);

	Out.ar(out, sig*ampl*env);
}).add;



//bass drum (like kick)
SynthDef(\bd, { | out=0, freq=50, ampl=0.4 |
	var osc, env;
	osc = FSinOsc.ar(freq);
	env = EnvGen.kr(Env.perc(0, 0.55), doneAction: 2);

	Out.ar(out, osc*env*ampl ! 2);
}).add;



SynthDef(\purity, { |out = 0, freq = 440, amp = 0.2, mix = 0.1 |
        var snd, click, env;


        snd = SinOsc.ar(freq) * EnvGen.ar(Env.perc(0.03, Rand(3.0, 4.0), 1, -7), doneAction: 2);

        snd = HPF.ar( LPF.ar(snd, 380), 120);
		env = EnvGen.ar(Env.perc(0.001, 0.01));

		//Klank: bank of Ringz filters (resonant filters)
        click = Klank.ar(
			//first arg: array of 3 arrays (freqs, ampls, ring times)
			`[
            [100 * ExpRand(0.97, 1.02), 2000 * ExpRand(0.97, 1.02), 3000 * ExpRand(0.97, 1.02)], //these are filter
            [-9, 0, -5].dbamp, //convert these dbs to amplitudes
            [0.8, 0.07, 0.08] //ring times
        ], BPF.ar(PinkNoise.ar, 6500, 0.1) * env) * 0.1;

        snd = (snd*mix) + (click*(1-mix));

		Out.ar(out, Pan2.ar(Mix.ar(snd), 0, amp));
    }).add;



SynthDef(\blips, {arg out = 0, freq = 440, numharm = 11, att = 0.01, rel = 1, amp = 0.2, pan = 0.3;
	var snd, env;
	env = Env.perc(att, rel, amp).kr(doneAction: 2);

	snd = BPF.ar(LeakDC.ar(Mix(Blip.ar([freq, freq*1.01], numharm, env))), 440, 0.4);

	Out.ar(out, Pan2.ar(snd, pan));
}).add;


//hollow metal tube sound (found on sccode.org)
SynthDef(\metaltube, {| out = 0, pan = 0, freq = 400, amp = 0.2, attackTime = 0.005, releaseTime = 1, gate = 1, vibFreq = 7, vibAmp = 0.1, vibAdd=0.5 |

	var amps = #[1, 0.67, 1, 1.8, 2.67, 1.67, 1.46, 1.33, 1.33, 1, 1.33];

	var durs = #[1, 0.9, 0.65, 0.55, 0.325, 0.35, 0.25, 0.2, 0.15, 0.1, 0.075];

	var frqs = #[0.56, 0.56, 0.92, 0.92, 1.19, 1.7, 2, 2.74, 3, 3.76, 4.07];

	var dets = #[0, 1, 0, 1.7, 0, 0, 0, 0, 0, 0, 0];

	var env1 = EnvGen.ar(Env.linen(0, attackTime + releaseTime, 0), gate, doneAction: 2);

	//mix a bunch of stuff down to single channel
	var src = Mix.fill(11, {|i|
	var env2 = EnvGen.ar(Env.perc(attackTime, releaseTime * durs[i], amps[i], attackTime.explin(0.005, 4, -4.5, 0)), gate);

SinOsc.ar(freq * frqs[i] + dets[i], 0, amp * env2);
		});

        src = src * SinOsc.kr(vibFreq * 15, mul: vibAmp, add: vibAdd);
		src = src * env1 * 0.5;

	    Out.ar(out, Pan2.ar(src, pan));
}).add;


//function that finds all factors of a number
~divisors = { | n |
	//make new list and clear contents (like calloc)
	~divs = List.newClear(0);

	for(1, floor(sqrt(n)),
	{ | i | //the iteration idx

		//find all divisors of n and add them to list, not adding duplicates
		if (n % i == 0,
		{
			~divs.add(i);

			if (n.div(i) != i,
			{
				~divs.add(n.div(i));
			}
			)
		}
		);
	}
	);

	//sort list of divisors
	~divs.sort;
	~divs;
};


//additive: create a stack of a bunch of sin waves of different freqs
SynthDef(\addsynth, { | out=0, freqs = #[1], amp = 0.5, sustain = 1 |
    var sig, env;

	//create a SinOsc that's a UGen obj, but basically empty
	sig = SinOsc.ar(1, mul: 0);

	//for each item in divs array, stack another sine wave value
	freqs.do(
		{ | item, idx |
			sig = sig + SinOsc.ar(item, mul: amp);
		}
	);

	//linen: attacktime, sustaintime, releasetime, lvl
	sig = sig * EnvGen.kr(Env.linen(0.001, sustain, 0.1), doneAction: 2);

	Out.ar(out, sig ! 2)
}).add;


//chaotic gongish/metal clanking sounds
SynthDef(\chaos, { | out = 0, ampl = 0.3 |
	var ctr1, ctr2, sig, sig2, env;

		//pulsecount: every time trigger sig goes from <0 to >0, the var gets incremented (it counts pulses)
	ctr1 = PulseCount.ar(Impulse.ar(500));
	ctr2 = PulseCount.ar(Impulse.ar(5000));

	sig = 0.1 *
			(
				((ctr1 * 20) & (ctr1 >> 5)) |
				((ctr1 * 5) & (ctr1 >> [3, 3])) % 256
			) / 400;

	//use random math
	sig2 = LPF.ar(HPF.ar(ctr1 + ctr2, WhiteNoise.ar() * 2000 + 1000), 20);

	//multiply the two sigs together
	sig2 = sig2 * sig;

	//Splay: spread array of channels over stereo field
	sig = ampl * Splay.ar(Limiter.ar(Greyhole.ar(sig + sig2, sig, 0.5, sig),
0.5).flatten);

	//fade out after a while
	env = Env.new(levels: [1, 1, 0], times: [30, 5]).kr(2);

	Out.ar(out, Pan2.ar(sig * env, LFNoise1.kr()));
}).add;



SynthDef(\blipsweepnoise, { | out = 0, freq = 50, ampl = 0.5 |
	var sig, noise, sine, env;

	//LFNoise will generate noise between -1 and 1
	noise = LFNoise1.kr(100).linlin(-1, 1, 1, 30);

	sig = Blip.ar(freq, noise, 0.2);

	//fade out after a while
	env = Env.new(levels: [1, 1, 0], times: [10, 3]).kr(2);

	Out.ar(out, sig * env * ampl ! 2);
}).add;



SynthDef(\blipsweepsine, { | out = 0, freq = 50, ampl = 0.5 |
	var sig, noise, sine, env;

	sine = SinOsc.kr(1).linlin(-1, 1, 1, 10);

	sig = Blip.ar(freq, sine, 0.2);

	//fade out after a while
	env = Env.new(levels: [1, 1, 0], times: [10, 3]).kr(2);

	Out.ar(out, sig * env * ampl ! 2);
}).add;


//taken from sccode.org example
SynthDef(\gong, {
	arg ratio1 = 0.9, ratio2=0.55, ratio3 = 1.03, index2=2, index3=4, amp = 0.4, dur = 7, pan=0;

	var sig, op1, op2, op3, env1, env2, env3;

	env3 = EnvGen.kr(Env.new([0, 1, 1, 0], [0.4, 0.3, dur]), doneAction:2);
	env2 = EnvGen.kr(Env.new([0, 1, 1, 0], [0, 0.3, dur]), doneAction:2);
	env1 = EnvGen.kr(Env.new([0, 1, 1, 0], [0.003, 0.3, dur - 0.5]), doneAction:2);

	op3 = SinOsc.ar(([67, 70, 74].midicps * ratio3), mul:[67, 70, 74].midicps * ratio3 * index3) * env3;
	op2 = SinOsc.ar((([67, 70, 74].midicps * ratio2) + op3), mul:[67, 70, 74].midicps * ratio2 * index2) * env2;
	op1 = SinOsc.ar(([67, 70, 74].midicps * ratio1) + op2);
	sig = op1 * env1 * amp;
	sig = Splay.ar(sig);

	sig = Balance2.ar(sig[0], sig[1], Line.kr(1, -1, dur));

	Out.ar(0, sig);
}).add;


SynthDef(\string, { | out = 0, freq = 440, ampl = 0.1, c3 = 20, pan = 0, gate = 1 |
    var env = Env.new([0, 1, 1, 0], [0.001, 0.006, 0.0005], [5, -5, -8]);

    var inp = ampl * LFClipNoise.ar(2000) * EnvGen.ar(env,gate);

    var son = DWGPlucked.ar(freq, ampl, gate, 0.1, 1, c3, inp);

	var chain = FFT(LocalBuf(2048), son);

	//run some rapid oscillating phaseshift on the string pluck
	chain = PV_PhaseShift(chain, SinOsc.kr(0.125, 0, 180, 180));

    DetectSilence.ar(son, 0.001, doneAction:2);

	Out.ar(out, 0.1 * Pan2.ar(IFFT(chain).dup, pan));
    //Out.ar(out, Pan2.ar(son * 0.1, pan));
}).add;


}).play; //run the Task



//END SYNTHDEFS------------------------------------------------------------





//wild irish roses seq notes: d, c, f. g, f, d.
//in midi: 50, 48, 53. 55, 53, 50.



~task = Task.new({
//create a condition variable to control execution of the Routine


//when all asynchronous server ops have run,
~server.sync(~cond);


~sminoNotes = [156, 146, 180, 200, 180, 156];


//BEGIN SYNTHDEF PBIND WRAPPER FUNCTIONS---------------------------
~smino = { | freq=156, dur=1, note1=0.35, rest1=0.4, note2=0.35, rest2=0.4, note3=0.35, rest3=0.2 |
	Pbind(\instrument, \rose, \dur, Pseq([dur], 1), \freq, freq);
};

~pop = { | ampl = 0.05 |
	Pbind(\instrument, \balloonpop, \dur, Pseq([1, Rest(), 1, Rest()], 1), \ampl, Pseq([ampl], 1), \pan, rrand(-1, 1));
};

~ping = { | ampl = 0.1 |
	//get ping with pan randomly chosen: one of -1, 1, 0
	Pbind(\instrument, \ping, \ampl, Pseq([ampl], 1), \pan, [-1, 1, 0].choose);
};

//END SYNTHDEF PBIND WRAPPER FUNCTIONS------------------------------




//wild irish roses synth sequence
~sminoSeq = Ptpar([0, ~smino.value(~sminoNotes[0], 1.2), 1.2, ~smino.value(~sminoNotes[1], 1.2), 2.4, ~smino.value(~sminoNotes[2], 4), 6, ~smino.value(~sminoNotes[3], 1.2), 7.2, ~smino.value(~sminoNotes[4], 1.2), 8.4, ~smino.value(~sminoNotes[5], 4)]);



l = Pbind(\instrument, \loveandlust, \buf, ~l, \ampl, Pseq([0.3], 1));
r = Pbind(\instrument, \rose_sweep, \mul_start, 1, \mul_end, 3, \sweepDur, Pseq([3], 1), \ampl, Pseq([1], 1));

c = Pbind(\instrument, \longtime, \buf, ~c, \ampl, Pseq([0.4], 1));
d = Pbind(\instrument, \longtime_muted, \buf_main, ~c, \buf_convwith, ~d, \dur, Pseq([0.5], 1));
e = Pbind(\instrument, \longtime_muted, \buf_main, ~c, \buf_convwith, ~d, \dur, Pseq([1], 1));

~longTimeSweep = Pbind(\instrument, \longtimesweep, \buf, ~c, \ampl, Pseq([0.05], 1));


//crackly staticy drone
x = Pbind(\instrument, \pulsedrone, \ampl, Pseq([0.5], 1));

//bass drum
b = Pbind(\instrument, \bd, \freq, 50, \ampl, Pseq([0.3], 1));

//rose synth, randomly wandering (sounds kind of like wind)
q = Pbind(\instrument, \rose, \dur, 0.5, \ampl, 1.5, \freq, Pbrown(0, 1, 0.1, 100).linexp(0, 1, 150, 300));


//gong
g = Pbind(\instrument, \gong, \amp, Pseq([0.4], 1), \dur, 7);


//create a scale
~scale = Scale.new(
    #[0, 1, 3, 5, 7, 8, 10], //degrees
    12, //pitches per octave
    Tuning.new([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]), //tuning
);


~stringSeq1 = Pbind(
    \instrument, \string,
    \scale, ~scale,
	\delta, Pseq([1, 1, 0.4, 0.4, 1, 0.8] * 0.25, 20), //how many beats to wait until next event
    \dur, 2,
    \degree, Pseq([8, 1, 2, 7, 0, 9], inf),
    \ampl, Pwhite(0.05, 0.3), //vary amplitude randomly
    \c3, Pseq([Pseq([1400], 24), Pseq([300], 24)], 20), //different decay times
    \pan, Pwhite(-1, 1), //vary pan randomly
);

~stringSeq2 = Pbind(
    \instrument, \string,
    \scale, ~scale,
	\delta, Pseq([1, 1, 0.4, 0.4, 1, 0.8] * 0.25, 20), //how many beats to wait until next event
    \dur, 2,
    \degree, Pseq([4, 10, 1, 3, 0, 2], inf),
    \ampl, Pwhite(0.05, 0.3), //vary amplitude randomly
    \c3, Pseq([Pseq([1400], 24), Pseq([300], 24)], 20), //different decay times
    \pan, Pwhite(-1, 1), //vary pan randomly
);


//additive synth patterns using my \addsynth and ~divisors to get lists of freqs
~additive1 = Pbind(\instrument, \addsynth,
	\amp, 0.01,
	\dur, Pseq([0.15, 0.15, 0.15], 20),
	\freqs, Pseq([~divisors.value(1000), ~divisors.value(1001), ~divisors.value(1002)], 20)
);

~additive2 = Pbind(\instrument, \addsynth,
	\amp, 0.01,
	\dur, Pseq([0.2, 0.2, 0.2], 20),
	\freqs, Pseq([~divisors.value(500), ~divisors.value(501), ~divisors.value(502)], 20),
);

~additive3 = Pbind(\instrument, \addsynth,
	\amp, 0.01,
	\dur, Pseq([0.2, 0.4, 0.15, 0.2], 20),
	\freqs, Pseq([~divisors.value(2000), ~divisors.value(2001), ~divisors.value(2002), ~divisors.value(4500)], 20),
);

~additive4 = Pbind(\instrument, \addsynth,
	\amp, 0.01,
	\dur, Pseq([0.4, 0.2, 0.2, 0.2, 0.5], 20),
		\freqs, Pseq([~divisors.value(100), ~divisors.value(800), ~divisors.value(40), ~divisors.value(400), ~divisors.value(5000)], 20),
);

~chaos = Pbind(\instrument, \chaos, \ampl, Pseq([0.2], 1));


~opening_stat = Pmono(\staticy, \ampl, 0.5, \dur, Pseq([2, 2, 0.3, 0.3, 2]), \freq, Pseq([70, 100, 103, 80, 70]));

~ideserve = Pbind(\instrument, \ideserve, \buf, ~d, \ampl, Pseq([0.1], 1));

//bass drum sequence
~bdSeq = Ptpar([0, b, 0.2, b, 0.4, b, 0.8, b]);

~bdSeq2 = Ptpar([0, ~bdSeq, 1, ~bdSeq]);

~bdSeq3 = Ptpar([0, ~bdSeq2, 3, ~bdSeq2]);

//ping sequence
~pingSeq = Pseq(Array.fill(20, { |i| ~ping.value(); }));

~higher_stat = Pmono(\staticy, \ampl, 0.4, \dur, Pseq([1, 1, 0.3, 0.3, 2], 2), \freq, Pseq([400, 650, 200, 180, 250], 2));

~mmfm = Pbind(\instrument, \mmfm, \ampl, Pseq([0.04], 1));

~blipSweepNoise = Pbind(\instrument, \blipsweepnoise, \ampl, Pseq([0.5], 1), \freq, 100);

~blipSweepSine = Pbind(\instrument, \blipsweepsine, \ampl, Pseq([0.5], 1), \freq, 50);

~metalTube = Pbind(\instrument, \metaltube, \amp, Pseq([0.1], 1));
~purity = Pbind(\instrument, \purity, \amp, Pseq([0.4], 1));

~clonks = Ptpar([0, ~purity, 0.1, ~metalTube, 0.2, ~purity, 0.3, ~metalTube,], 4);

//piece together the FULL song
~song = Ptpar([0, l, 2, ~opening_stat, 9, r, 9, ~pop.value(), 13, ~sminoSeq, 17, c, 23, d, 27, ~ideserve, 30, ~pingSeq, 30, x, 32, ~bdSeq3, 35, ~bdSeq3, 38, ~bdSeq3, 48, ~additive1, 57, ~additive2, 63, ~longTimeSweep, 68, q, 72, ~stringSeq1, 92, g, 100, ~stringSeq2, 100, ~chaos, 120, ~additive3, 132, ~higher_stat, 139, r, 143, x, 143, l, 150, ~pop.value(), 150, ~mmfm, 160, ~additive1, 165, e, 170, ~blipSweepNoise, 174, ~pingSeq, 180, ~sminoSeq, 190, ~blipSweepSine, 198, ~additive2, 205, ~clonks, 210, l, 212, ~opening_stat, 215, ~mmfm, 220, x, 225, ~bdSeq3, 225, ~additive4, 230, ~longTimeSweep, 230, ~chaos, 232, ~blipSweepSine, 234, ~additive1, 235, g, 237, ~clonks, 240, ~ideserve, 241, ~purity, 242, ~purity, 243, ~purity, 244, ~purity, 245, ~purity, 245, ~purity, 246, ~purity, 247, ~purity, 248, ~purity, 248, l]);


//output the song
~song.play(~tc);


});

)

//Server.default.record;
//PLAY THE FULL SONG ON SPEAKERS
~task.play(~tc);



//BEGIN SYNTH TESTING----------------------------------------------
Synth(\loveandlust, args:[\buf, ~l]);
Synth(\flute);
Synth(\metaltube);
Synth(\ping);
Synth(\pulsedrone);
Synth(\flute2);
Synth(\purity);
Synth(\blips);
Synth(\addsynth, args:[\freqs, [[[100, 200, 300]]]]);
Synth(\chaos);
Synth(\blipsweepnoise);
Synth(\blipsweepsine, args: [\freq, 50]);
Synth(\longtimesweep, args: [\buf, ~c]);
Synth(\gong);
Synth(\mmfm, args: [\freq, 400]);
Synth(\staticy, args: [\freq, 300]);
Synth(\ideserve, args:[\buf, ~d]);
Synth(\staticy);
//END SYNTH TESTING------------------------------------------------










//how to chg tempoclock dynamically (found online):
t = TempoClock(120 / 60).permanent_(true);

(
~change_clock_tempo = {|clock, tempo, beats=1|
    beats.do {|beat|
        var stepTempo = beat.linexp(0, beats-1, clock.tempo, tempo);
        clock.schedAbs(clock.nextBar + beat, {
            "New Tempo: ".post; (stepTempo*60).post; " BPM".postln;
            clock.tempo_(stepTempo);
        });
    };
    nil;
};
Pbindef(\n,
    \octave, 4,
    \dur, 0.5,
    \degree, Pseq((0..7), inf)
).play(t, quant: 4);
);

~change_clock_tempo.value(t, 200/60, 16);
~change_clock_tempo.value(t, 50/60, 8);
t.tempo*60




