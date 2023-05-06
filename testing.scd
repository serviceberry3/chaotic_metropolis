/*CHAOTIC METROPOLIS, A CPSC 432 final project composition By Noah Weiner (nsw25)

INSTRUCTIONS FOR PLAYING: click to the right of the left parenthesis on line
13. Then run that code block THREE TIMES, waiting for it to complete each time. Each time you run it, you should see "a Task" in the Post window.

For some reason, this was the only way I was able to get it to load all of the soundfiles using Buffer.read. I tried for a long time experimenting with Server.sync, Condition variables, Buffer.read() actions, etc. No matter what I did, one of the sample mp3 files would never load unless I ran the code block three separate times.

Once that first code block is run THREE times, scroll down to the bottom of the document and run the line "t.play(~tc);" to hear the song.

Any time you stop the song using CMD + ., you'll need to re-run the first code block before running "t.play(~tc);" again.
*/


//r = Recorder(s);
//r.record(numChannels:2);
//Server.default.record;

Env.new(levels: [1, 1, 0], times: [5, 5]).plot;


(


//BEGIN SYNTHDEFS------------------------------------------------------------

SynthDef(\loveandlust, {| buf, out = 0, ampl = 0.1, kernel|
	var in, freqdom, res, line, noise;

	//play the buffer into a var
	in = PlayBuf.ar(1, buf, BufRateScale.kr(buf)*0.6, loop: 0);
	//run FFT
	freqdom = FFT(LocalBuf(2048), in);

	noise = LFNoise2.kr(1, 180, 180);
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

	noise = LFNoise2.kr(1, 180, 180);

	freqdom = PV_PhaseShift(freqdom, SinOsc.kr(0.2, 0, 180, 180));

	res = 0.2 * IFFT(freqdom);

	res = PartConv.ar(res, ~fftsz, ~impResp, 0.7) * 0.1;

	//res = CombC.ar(in, 1, SinOsc.kr(0.5, 0, 0.5, 0.6), 0.2);

	//TO AVOID POPPING: once sample plays, fade it out slowly and free synth
	env = Env.new([1, 1, 0], [5, 2]).kr(2);

	//output signal mult by env
	Out.ar(out, res*env*ampl ! 2);
}).add;



SynthDef(\ideserve, { | buf, out = 0, ampl 0.5 |
	var in, env, sig;

	in = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * 0.9, loop: 0);

	//free self when the sound fades below certain threshold
	//DetectSilence.ar(in, 0.1, 0.1, doneAction: 2);

	//TO AVOID POPPING: once sample plays, fade it out slowly and free synth
	env = Env.new([1, 1, 0], [5, 2]).kr(2);

	//RLPF: SC uses reciprocal of Q (RQ). Max Q value is 1.
	//smaller rq values -> narrower bandwidth of band stop zone. higher Q -> closer the filter to being perfect
	sig = RLPF.ar(in, SinOsc.ar(0.125, mul: 200, add: 500), 0.01);

	Out.ar(out, sig*ampl*env ! 2);
}).add;



SynthDef(\staticy, { | out = 0, ampl = 1, freq = 69.30, gate = 1 |
	//carrier amplitudes
	var amps = [1, 1, 1, 1].normalizeSum; //makes these ampls sum to 1

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

	//gate arg functions as trigger for the env
	pop = BrownNoise.ar(EnvGen.kr(env, doneAction: 2));

	sig = Pan2.ar(pop, pan);

	echo = Greyhole.ar(sig, 0.1, 0.1, 1, 0.707, 0.1, 0.01, 2
    );

	Out.ar(out, echo * ampl);
}).add;



SynthDef(\ping, { | out = 0, ampl = 0.1 |
	var imp, sig, env;

	//generate impulses
	imp = Impulse.ar([2, 3], [0, 0.3], 0.15);

	//pass impulses into ringing filter
	sig = Ringz.ar(imp, [250, 500], 3);

	sig = Mix.ar(sig);

	Out.ar(out, sig*ampl ! 2);
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



SynthDef(\flute, { arg scl = 0.2, freq = 440, ipress = 0.9, ibreath = 0.09, ifeedbk1 = 0.4, ifeedbk2 = 0.4, dur = 3, gate = 0.5, amp = 1;

		var kenv1, kenv2, kenvibr, kvibr, sr, cr, block;
		var poly, signalOut, ifqc;
		var aflow1, asum1, asum2, afqc, atemp1, ax, apoly, asum3, avalue, atemp2, aflute1;
		var fdbckArray;

		sr = SampleRate.ir;
		cr = ControlRate.ir;
		block = cr.reciprocal;

		ifqc = freq;

		// noise envelope
		kenv1 = EnvGen.kr(Env.new(
			[ 0.0, 1.1 * ipress, ipress, ipress, 0.0 ], [ 0.06, 0.2, dur - 0.46, 0.2 ], 'linear' )
		);
		// overall envelope
		kenv2 = EnvGen.kr(Env.new(
			[ 0.0, amp, amp, 0.0 ], [ 0.1, dur - 0.02, 0.1 ], 'linear' ), doneAction: 2
		);
		// vibrato envelope
		kenvibr = EnvGen.kr(Env.new( [ 0.0, 0.0, 1, 1, 0.0 ], [ 0.5, 0.5, dur - 1.5, 0.5 ], 'linear') );

		// create air flow and vibrato
		aflow1 = LFClipNoise.ar( sr, kenv1 );
		kvibr = SinOsc.ar( 5, 0, 0.1 * kenvibr );

		asum1 = ( ibreath * aflow1 ) + kenv1 + kvibr;
		afqc = ifqc.reciprocal - ( asum1/20000 ) - ( 9/sr ) + ( ifqc/12000000 ) - block;

		fdbckArray = LocalIn.ar( 1 );

		aflute1 = fdbckArray;
		asum2 = asum1 + ( aflute1 * ifeedbk1 );

		//ax = DelayL.ar( asum2, ifqc.reciprocal * 0.5, afqc * 0.5 );
		ax = DelayC.ar( asum2, ifqc.reciprocal - block * 0.5, afqc * 0.5 - ( asum1/ifqc/cr ) + 0.001 );

		apoly = ax - ( ax.cubed );
		asum3 = apoly + ( aflute1 * ifeedbk2 );
		avalue = LPF.ar( asum3, 2000 );

		aflute1 = DelayC.ar( avalue, ifqc.reciprocal - block, afqc );

		fdbckArray = [ aflute1 ];

		LocalOut.ar( fdbckArray );

		signalOut = avalue;

		OffsetOut.ar( 0, [ signalOut * kenv2, signalOut * kenv2 ] );

	}).add;


SynthDef(\risset, {|out = 0, pan = 0, freq = 400, amp = 0.05, att = 0.005, rel = 1, gate = 1,vibFreq=7, vibAmp=0,vibAdd=0.5|
		var amps = #[1, 0.67, 1, 1.8, 2.67, 1.67, 1.46, 1.33, 1.33, 1, 1.33];
		var durs = #[1, 0.9, 0.65, 0.55, 0.325, 0.35, 0.25, 0.2, 0.15, 0.1, 0.075];
		var frqs = #[0.56, 0.56, 0.92, 0.92, 1.19, 1.7, 2, 2.74, 3, 3.76, 4.07];
		var dets = #[0, 1, 0, 1.7, 0, 0, 0, 0, 0, 0, 0];
		var doneActionEnv = EnvGen.ar(Env.linen(0, att+rel, 0), gate, doneAction: 2);
		var src = Mix.fill(11, {|i|
			var env = EnvGen.ar(Env.perc(att, rel * durs[i], amps[i], att.explin(0.005, 4, -4.5, 0)), gate);
			SinOsc.ar(freq*frqs[i] + dets[i], 0, amp*env);
		});
        src = src * SinOsc.kr(vibFreq*15, mul:vibAmp, add:vibAdd);
		src = src * doneActionEnv * 0.5; // make sure it releases node after the end.
	    Out.ar(out, Pan2.ar(src, pan));
	}).add;


//END SYNTHDEFS------------------------------------------------------------




//get the server instance
~server = Server.local;

//set up tempo and TempoClock
~bpm = 60;
~tc = TempoClock(~bpm / 60);

//FFT window size for Conv operations
~fftsz = 2048;

~bufsz = PartConv.calcBufSize(~fftsz, ~irChurchFar);
~impResp = Buffer.alloc(~server, ~bufsz, 1);
~impResp.preparePartConv(~irChurchFar, ~fftsz);


//wild irish roses seq notes: d, c, f. g, f, d.
//in midi: 50, 48, 53. 55, 53, 50.

~cond = Condition.new;

//read in audio files
~l = Buffer.read(~server, "samp/kl_love.mp3".resolveRelative, 44100 * 3.7, 44100 * 1);
~w = Buffer.read(~server, "samp/irish_roses.mp3".resolveRelative, 44100 * 6.5, 44100 * 0.4);
~c = Buffer.read(~server, "samp/coldheart.mp3".resolveRelative, 44100 * 71.8, 44100 * 4.1);
~d = Buffer.read(~server, "samp/ideservepiano.mp3".resolveRelative, 44100 * 44, 44100 * 3);
~irChurchFar = Buffer.read(~server, "sf/st_georges_far.wav".resolveRelative);


~task = Task.new({
//create a condition variable to control execution of the Routine


//when all asynchronous server ops have run,
~server.sync(~cond);


~sminoNotes = [156, 146, 180, 200, 180, 156];

~smino = { | freq=156, dur=1, note1=0.35, rest1=0.4, note2=0.35, rest2=0.4, note3=0.35, rest3=0.2 |
	Pbind(\instrument, \rose, \dur, Pseq([dur], 1), \freq, freq);
};

~pop = { | ampl = 0.05 |
		Pbind(\instrument, \balloonpop, \dur, Pseq([1, Rest(), 1, Rest()], 1), \ampl, Pseq([ampl], 1), \pan, rrand(-1, 1));
};

//wild irish roses synth sequence
~sminoSeq = Ptpar([0, ~smino.value(~sminoNotes[0], 1.2), 1.2, ~smino.value(~sminoNotes[1], 1.2), 2.4, ~smino.value(~sminoNotes[2], 4), 6, ~smino.value(~sminoNotes[3], 1.2), 7.2, ~smino.value(~sminoNotes[4], 1.2), 8.4, ~smino.value(~sminoNotes[5], 4)]);



l = Pbind(\instrument, \loveandlust, \buf, ~l, \ampl, Pseq([0.3], 1));
r = Pbind(\instrument, \rose_sweep, \mul_start, 1, \mul_end, 3, \sweepDur, Pseq([3], 1), \ampl, Pseq([1], 1));

c = Pbind(\instrument, \longtime, \buf, ~c, \ampl, Pseq([0.4], 1));
d = Pbind(\instrument, \longtime_muted, \buf_main, ~c, \buf_convwith, ~d, \dur, Pseq([0.5], 1));


//pinging
p = Pbind(\instrument, \ping, \ampl, Pseq([0.1], 1));

//crackly staticy drone
x = Pbind(\instrument, \pulsedrone, \ampl, Pseq([0.5], 1));

b = Pbind(\instrument, \bd, \freq, 50, \ampl, Pseq([0.3], 1));

q = Pbind(\instrument, \rose, \dur, 0.5, \freq, Pbrown(0, 1, 0.1, inf).linexp(0, 1, 150, 300));



~opening_stat = Pmono(\staticy, \ampl, 0.5, \dur, Pseq([2, 2, 0.3, 0.3, 2]), \freq, Pseq([70, 100, 103, 80, 70]));

~ideserve = Pbind(\instrument, \ideserve, \buf, ~d, \ampl, Pseq([0.2], 1));

//bass drum sequence
~bdSeq = Ptpar([0, b, 0.2, b, 0.4, b, 0.8, b]);

~bdSeq2 = Ptpar([0, ~bdSeq, 1, ~bdSeq]);

~bdSeq3 = Ptpar([0, ~bdSeq2, 3, ~bdSeq2]);

//create FULL song
~song = Ptpar([0, l, 2, ~opening_stat, 9, r, 9, ~pop.value(), 13, ~sminoSeq, 17, c, 23, d, 27, ~ideserve, 30, p, 30, x, 32, ~bdSeq3, 35, ~bdSeq3, 38, ~bdSeq3]);
~song.play(~tc);

});

)


~task.play(~tc);


Synth(\flute);
Synth(\risset);
Synth(\ping);

Synth(\pulsedrone);



