//r = Recorder(s);
//r.record(numChannels:2);
//Server.default.record;


(
SynthDef(\loveandlust, {| buf, out = 0, ampl = 0.5, kernel|
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


SynthDef(\longtime_muted, {| buf_main, buf_convwith, out = 0, kernel|
	var in, freqdom, res, line, noise, mod;

	res = Convolution.ar(PlayBuf.ar(1, buf_main, loop:1) * 0.1, PlayBuf.ar(1, buf_convwith, loop:1) * 0.02, 2048);

	//convert back to time domain
	Out.ar(out, res ! 2);
}).add;


SynthDef(\longtime, {| buf, out = 0, kernel|
	var in, freqdom, res, line, noise, mod;

	//play the buffer into a var
	in = PlayBuf.ar(1, buf, BufRateScale.kr(buf)*0.9, loop: 0);

	mod = SinOsc.ar(70, mul: 100);

	//run FFT
	freqdom = FFT(LocalBuf(2048), in);

	noise = LFNoise2.kr(1, 180, 180);

	freqdom = PV_PhaseShift(freqdom, SinOsc.kr(0.2, 0, 180, 180));

	res = 0.2 * IFFT(freqdom);

	res = PartConv.ar(res, ~fftsz, ~impResp, 0.7) * 0.1;

	//res = CombC.ar(in, 1, SinOsc.kr(0.5, 0, 0.5, 0.6), 0.2);

	//convert back to time domain
	Out.ar(out, res ! 2);
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



SynthDef(\rose, { | out=0, sweepDur=3, freq = 156, loudness = 1, dur = 1, pan = 0.0, panDur = 3, attackTime = 0.8, releaseTime = 0.8, gate = 1, freqs = #[156, 195, 233, 295, 395, 468, 576, 602, 637, 856, 905, 953, 1409, 684, 713, 797, 857, 1205, 1336, 760, 702, 950, 1006, 1059, 1127, 1160, 1279], amplSpect = #[-47, -37.7, -34.2, -23.3, -32.9, -29.3, -34.5, -33.7, -38.2, -47, -48.3, -55.5, -53.2, -62, -44.6, -45.3, -46.8, -47.7, -55.8, -63.2, -45.4, -46, -54, -57, -65.1, -58.6, -59.2, -64.5, -64.5], freqsNoiseMult = 5, amplsNoiseMult = 0.8, vib = 0.5 |
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
				Env.linen(attackTime, dur, releaseTime, 1, \sine).kr(doneAction: 2)) * loudness + //adjust overall env ampl based on arg passed
			    partialAmplNoises + //add some slight noise variation over time to each partial amplitude
			    PinkNoise.ar(loudness * Env.linen(attackTime, dur, releaseTime, 0.005, \sine).kr(doneAction: 2)) //add in bow noise with same envelope shape as the SinOsc mul envelope
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

	Out.ar(out, s * e * loudness);
}).add;




SynthDef(\balloonpop, { | out = 0, pan = 0, ampl = 0.05 |
	var env, pop, sig, echo;

	//attacktime, releasetime
	env = Env.perc(0, 5);

	//gate arg functions as trigger for the env
	pop = BrownNoise.ar(EnvGen.kr(env, doneAction: 2));

	sig = Pan2.ar(pop, pan);

	echo = Greyhole.ar(
        sig,
        \dtime.kr(0.1),
        \damp.kr(0.1),
        \size.kr(1),
        \diff.kr(0.707),
        \fb.kr(0.1),
        \modDepth.kr(0.01),
        \modFreq.kr(2)
    );

	Out.ar(out, echo * ampl);
}).add;



s = Server.local;
~fftsz=2048;
~bufsz = PartConv.calcBufSize(~fftsz, ~irChurchFar);
~impResp = Buffer.alloc(s, ~bufsz, 1);
~impResp.preparePartConv(~irChurchFar, ~fftsz);
~l = Buffer.read(s, "samp/kl_love.mp3".resolveRelative, 44100 * 3.7, 44100 * 1, action: {});
~w = Buffer.read(s, "samp/irish_roses.mp3".resolveRelative, 44100 * 6.5, 44100 * 0.4);
~c = Buffer.read(s, "samp/coldheart.mp3".resolveRelative, 44100 * 71.8, 44100 * 4.1);
~d = Buffer.read(s, "samp/ideservepiano.mp3".resolveRelative, 44100 * 44, 44100 * 3);
~irChurchFar = Buffer.read(s, "sf/st_georges_far.wav".resolveRelative);



//smino: d, c, f. g, f, d.
//smino: 50, 48, 53. 55, 53, 50.


Task.new({

s.sync;
~bpm = 60;
~tc = TempoClock(~bpm / 60);

~sminoNotes = [156, 146, 180, 200, 180, 156];

~smino = { | freq=156, dur=1, note1=0.35, rest1=0.4, note2=0.35, rest2=0.4, note3=0.35, rest3=0.2 |
	Pbind(\instrument, \rose, \dur, Pseq([dur], 1), \freq, freq);
};

~pop = { | ampl = 0.05 |
		Pbind(\instrument, \balloonpop, \dur, Pseq([1, Rest(), 1, Rest()], 1), \ampl, Pseq([ampl], 1), \pan, rrand(-1, 1));
};

~sminoSeq = Ptpar([0, ~smino.value(~sminoNotes[0], 1.2), 1.2, ~smino.value(~sminoNotes[1], 1.2), 2.4, ~smino.value(~sminoNotes[2], 4), 6, ~smino.value(~sminoNotes[3], 1.2), 7.2, ~smino.value(~sminoNotes[4], 1.2), 8.4, ~smino.value(~sminoNotes[5], 4)]);


l = Pbind(\instrument, \loveandlust, \buf, ~l, \ampl, Pseq([0.5], 1));
r = Pbind(\instrument, \rose_sweep, \mul_start, 1, \mul_end, 3, \sweepDur, Pseq([3], 1), \ampl, Pseq([1], 1));

	c = Pbind(\instrument, \longtime, \buf, Pseq([~c], 1), \amp, Pseq([0.5], 1));
	d = Pbind(\instrument, \longtime_muted, \buf_main, Pseq([~c], 1), \buf_convwith, Pseq([~d], 1), \dur, Pseq([0.5], 1));


~opening_stat = Pmono(\staticy, \ampl, 0.5, \dur, Pseq([2, 2, 0.3, 0.3, 2]), \freq, Pseq([70, 100, 103, 80, 70]));

//play song
Ptpar([0, l, 2, ~opening_stat, 9, r, 9, ~pop.value(), 13, ~sminoSeq, 17, c, 18.5, d]).play(~tc);
}).play;
)



~pop.value().play;

Ndef(\a).play; // play to hardware output.
Ndef(\a).fadeTime = 2; // fadeTime specifies crossfade
// set the source

Ndef(\a, { SinOsc.ar([350, 351.3], 0, 0.2) });
Ndef(\a, { Pulse.ar([350, 351.3] / 4, 0.4, 0.2) });
Ndef(\a, Pbind(\dur, 0.03, \freq, Pbrown(0, 1, 0.1, inf).linexp(0, 1, 200, 350)));

Ndef(\a, { Ringz.ar(Ndef.ar(\b), [350, 351.3] * 2, 0.4) });
Ndef(\b, { Impulse.ar([5, 7] / 2, [0, 0.5], 0.15) });

Ndef.clear(3); // clear all after 3 seconds

d.play;
c.play;

Synth(\longtime, args:[\buf, ~c]);

