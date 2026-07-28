#import "Math";
#import "thegame_math";
#import "thegame_array_poly";
//This is just for array_add for the synth so maybe we can move that out eventually and then remove this import
//OR maybe we'll use this more later and also assertions and logging eventually...
#import "Basic";

//AUDIO STUFF (create a module?)
//TODO store all equal tempered frequencies somewhere
//https://en.wikipedia.org/wiki/Piano_key_frequencies
A4 :: 440.0000;
A3 :: 220.0000;
A2 :: 110.0000;
A1 :: 55.00000;
C5 :: 523.2512;
C4 :: 261.6256;
C3 :: 130.8128;
C2 :: 65.40639;
C1 :: 32.70320;

B0 		  :: 30.86771;
A_SHARP_0 :: 29.13524;
A0 		  :: 27.50000;
G_SHARP_0 :: 25.95654;
G0 		  :: 24.49971;
F_SHARP_0 :: 23.12465;
F0 		  :: 21.82676;
E0 		  :: 20.60172;
D_SHARP_0 :: 19.44544;
DO 		  :: 18.35405;
C_SHARP_0 :: 17.32391;
C0 		  :: 16.35160;

A_NEG_1   :: 13.75000; 
A_NEG_2   :: 6.875000;
A_NEG_3   :: 3.437500;

TWENTY_HERTZ :: 20.00000; //Lowest human audible frequency
ONE_HERTZ :: 1.000000;
CentsToFrequency :: #bake_arguments PitchToFrequency(note_count = 1200, compass_interval = 2);
/*
	Definition of compass interval is to generalize the notion
	of the octave to any multiple of the reference value
	Can we come up with one word for this?

	Definition of compass multiple is some multiple of the
	compass interval (eg like 2 octaves = 2^2 and 2 tritaves = 3^2)
*/
PitchToFrequency :: inline (
	compass_multiple : int,
	pitch : $T,
	note_count : int,
	compass_interval : int,
	ref_freq : float = C0)
-> float
{
	#assert(T == float || T == int);
	//TODO could make note_count, compass_interval and ref_freq
	//compile-time constant
	exponent : float = compass_multiple + (pitch / cast(float) note_count);
	frequency : float = ref_freq * pow(cast(float) compass_interval, exponent);
	return frequency;
}


//TODO Could make return value T but then if we have int then set it to float64 or something
//TODO We could have this return a float64 and then a float for frequency for synth if needed
PitchWithOctaveToFrequency :: inline (
	pitch_with_octave : $T,
	note_count : int,
	compass_interval : float64,
	ref_freq : float = C0)
-> float64
{
#assert(T == float64 || T == float || T == int);
	//TODO could make note_count, compass_interval and ref_freq compile-time constant
	//TODO Maybe we can pass this in differently so we don't need so many casts...
	exponent : float64 = pitch_with_octave / cast(float64) note_count;
	// exponent : float = cast(float) (pitch_with_octave / note_count);
	frequency : float64 = ref_freq * pow(compass_interval, exponent);
	return frequency;
}

//TODO Should this be float64 (maybe all of thegame_audio should just be float64 for accuracy)
LinearToFrequency :: inline (
	linear : float,
	compass_interval : float,
	ref_freq : float = C0)
-> float
{
	frequency : float = ref_freq * pow(compass_interval, linear);
	return frequency;
}

RatioToFrequencyOctave :: #bake_arguments RatioToFrequency(compass_interval = 2);
//TODO I Think we should switch this to float64 since pow is float64 anyways and does multiple casts
//float is still overall faster but float64 gives us more precision in case animals and plants
//have more frequency sensitivities/precision than humans.
RatioToFrequency :: inline (
	ratio : float64,
	compass_multiple : int, //octave - should this be float?
	compass_interval : float64,
	ref_freq : float = C0)
-> float64
{
	//TODO integer Pow
	compass_ratio : float64 = pow(compass_interval, cast(float) compass_multiple);
	frequency : float64 = ref_freq * ratio * compass_ratio;
	return frequency;
}

DimSpaceValueToCompassMultiple :: inline (
	value : int, 
	note_count : int) 
-> int 
{
	octave : int = value / note_count;
	//TODO not sure about this, wouldn't the value being negative be enough?
	//TODO Also can likely have a verson without this if value > 0 checked at compile-time
	//TODO Can allow this as an option depending on what the player wants to hear in the space.
	// if value < 0 octave -= 1;
	return octave;
}

DimSpaceValueToFrequency :: (
	value : int, 
	note_count : int,
	compass_interval : int,
	ref_freq : float = C0) 
-> float 
{
	octave : int = DimSpaceValueToCompassMultiple(value, note_count);
	//TODO should value be possible to be negative
	//eg if our reference frequency is A440
	fraction : int = PosMod(value, note_count);
	frequency : float = 
		PitchToFrequency(octave, fraction, note_count, compass_interval, ref_freq);
	return frequency;
}

//TODO bake eq temp 12 tone and also cent scale and possibly tritave
EqTempPitchToFrequency :: inline (
	octave : int, 
	pitch : int, 
	ref_freq : float = C0) 
-> float 
{
	frequency : float = PitchToFrequency(octave, pitch, 12, 2, ref_freq);
	return frequency;
}

EqTempDimSpaceValueToFrequency :: (value : int, ref_freq : float = C0) -> float {
	octave : int = EqTempDimSpaceValueToCompassMultiple(value);
	pitch : int = PosMod(value, 12);
	frequency : float = EqTempPitchToFrequency(octave, pitch, ref_freq);
	return frequency;
}

EqTempDimSpaceValueToCompassMultiple :: inline (value : int) -> int {
	octave : int = DimSpaceValueToCompassMultiple(value, 12);
	return octave;
}

CompassAndDegree :: struct {
	compass_multiple : int;
	tuning_degree : int;
}

NoteToCompassAndPosDegree :: inline (note : int, note_count : int) -> CompassAndDegree {
	compass_and_degree : CompassAndDegree;
	compass_and_degree.compass_multiple = DimSpaceValueToCompassMultiple(note, note_count);
	compass_and_degree.tuning_degree = PosMod(note, note_count);
	return compass_and_degree;
}

LogRatioToLinear1 :: #bake_arguments LogRatioToLinear(multiple = 1);
RatioToOctaveLinear1 :: #bake_arguments LogRatioToLinear1(base = 2.0);
RatioToTritaveLinear1 :: #bake_arguments LogRatioToLinear1(base = 3.0);

RatioToOctaveLinear :: #bake_arguments LogRatioToLinear(base = 2.0);
RatioToTritaveLinear :: #bake_arguments LogRatioToLinear(base = 3.0);
RatioToCents :: #bake_arguments LogRatioToLinear(base = 2.0, multiple = 1200);
LogRatioToLinear :: inline (
	ratio : float64, 
	base : float64, 
	multiple : int = 1) 
-> float
{
	#if 0 {
	//TODO make multiple / log(base) a compile-time constant
	linear : float = multiple * (log(ratio) / log(base));
	return linear;
	} else {
	return cast(float) LogRatioToLinear64(ratio, base, multiple);
	}
}
LogRatioToLinear64 :: inline (
	ratio : float64, 
	base : float64, 
	multiple : int = 1) 
-> float64
{
	//TODO make multiple / log(base) a compile-time constant
	linear : float64 = multiple * (log(ratio) / log(base));
	return linear;
}

//TODO For multiples of 2 we could make en efficient function with left bit shifts
//Could we do the same thing for log with bit shifts?
RatioWithOctaveBase :: inline (
	ratio : float,
	octave_index : int,
	base : float = 2.0)
-> float
{
	ratio_with_octave : float = ratio * pow(base, cast(float) octave_index);
	return ratio_with_octave;
}

//TODO Can bake in base and multiple like we do above
OctaveLogRatioToLinear :: inline (
	ratio : float,
	octave_index : int,
	base : float = 2.0, 
	multiple : int = 1)
-> float
{
	//TODO make multiple / log(base) a compile-time constant
	//Note : This adds the ratio for the corresponding octave to the
	//passed in ratio depending on the octave index
	ratio_with_octave : float = ratio * pow(base,cast(float)octave_index);
	linear : float = multiple * (log(ratio_with_octave) / log(base));
	return linear;
}

EqTempToRatio :: #bake_arguments LinearToLogRatio(base = 2.0, multiple = 12);
CentsToRatio :: #bake_arguments LinearToLogRatio(base = 2.0, multiple = 1200);
LinearToLogRatio :: inline (
	linear : float64,
	base : float64,
	multiple : int = 1)
-> float64
{
	// exponent : float = (linear * log10(base)) / multiple;
	// log_ratio : float = pow(10.0, exponent);
	exponent : float64 = (linear * log(base)) / multiple;
	log_ratio : float64 = pow(EULER_N64, exponent);
	return log_ratio;
}

LinearToCents :: inline (
	linear : float64,
	base : float64,
	multiple : int = 1)
-> int
{
	//TODO this can maybe be more efficient when converting
	//linear to cents directly
	ratio : float64 = LinearToLogRatio(linear, 2, 12);
	cents : float64 = RatioToCents(ratio);
	rounded_cents : int = round_to_int(cents);
	return rounded_cents;
}

EqTempToCents :: #bake_arguments LinearToCentsSameBase(multiple = 12);
LinearToCentsSameBase :: inline (
	linear : float,
	$multiple : int = 1)
-> int
{
	cents_over_multiple : float : 1200.0 / multiple;
	cents : float = cents_over_multiple * linear;
	//TODO this could be more efficient if we just cast(int)
	//which should be fine since < 1 cent is imperceivable 
	//to the human ear
	rounded_cents : int = round_to_int(cents);
	return rounded_cents;
}

SimpleSynth :: struct {
	synth_id : int;
	synth_name : string;
	simple_waves : [..] OscWave;
	wave_type : OscWaveType;
	envelope : VolumeEnvelope;
	//Note : used for convenience for volume envelope, vibrato depth, etc...
	//Note : amp_factor could be a time based function for more realistic synthesis possibilities
	volume : float = 0.1;
}

//TODO I think we might be able to remove this since we will simplify the OscWave once we do SubtractiveSynth
//and use synths to generate audio everywhere.
SimpleWave :: struct {
	//TODO Can we remove seconds and seconds_per_period
	//to reduce size of osc_wave?
	seconds : float;
	radians : float;
	frequency : float;
	//Note : used for convenience for volume envelope, vibrato depth, etc...
	//Note : amp_factor could be a time based function for more realistic synthesis possibilities
	// amp_factor : float = 1.0;

	//Note : convenient data for speed in synthesis calculations
	//TODO Maybe we can remove samples_per_period and seconds_per_period if we don't use those
	// samples_per_period : float;
	radians_per_sample : float;
	// seconds_per_period : float;
}
//TODO We could grab this from a pool, but I think having it like this is likely fine,
//since generally just the count will go up and down and voices double every-time starting at 8
//and we will likely have < 8 voices per row so this seemse fine and can maybe profile a wave pool later.
AddSimpleWaveFromFrequency :: inline (frequency : float, synth : *SimpleSynth, audio_data : AudioData) -> *OscWave {
	wave : *OscWave = array_add(*synth.simple_waves);
	UpdateWaveFrequency(frequency, wave, audio_data);
	return wave;
}
UpdateSimpleWaveFrequency :: inline (frequency : float, wave : *SimpleWave, sample_rate : int) {
	wave.frequency = frequency;
	samples_per_period : float = cast(float) sample_rate / wave.frequency;
	wave.radians_per_sample = TAU / samples_per_period;
	// wave.seconds_per_period = TAU / wave.radians_per_sample / audio_data.SampleRate;
}

//TODO FROM HERE neume on and neume off internally and then update this so it works with 
//simplest forms like IncrementSimpleSynthWave and VolumeCoefficientLinear
//and also can keep this 32-bit and make the other one 64-bit if that is better later
//TODO Is there some way to have seconds_per_sample as a global variable or is it better to pass it in like this?
//This can only change if the sample rate changes... Can we even allow that without restarting everything?
//FL Studio requires a project restart for example to do that.
GenerateSimpleSynthSamples :: (synth : *SimpleSynth, buffer : *float, audio_data : AudioData) {
	sample_function : SampleFunction = GetWaveFunction(synth.wave_type);
	//PROFILE : We could see if setting the waves or the buffers on the outer loop is faster eventually here.
	//In this case we do the same code more times since buffer is longer but we hope that the entire buffer is in the cache when generating samples.
	for * wave : synth.simple_waves {
		b_index : int = 0;
   	for 0..audio_data.SamplesToFill-1 {
	   	//TODO volume could be 1.0 / number of waves currently playing
	   	//right now we multiply it by 0.1 or 0.2 here and then it can be adjusted with the volume
	   	//which makes each wave the same volume and accumulates like 3x osc in fl
	   	sample_f32 := sample_function(wave.radians);
			sample_f32 *= synth.volume * VolumeCoefficient(wave, synth.envelope);
			//NOTE : This allows stereo effects directly in the buffer.
			for 0..audio_data.number_of_channels-1 {
	   		buffer[b_index] += sample_f32;
	   		b_index += 1;
	   	}
	   	IncrementWave(wave, wave.radians_per_sample, audio_data.seconds_per_sample);
	   }
   	assert(b_index == audio_data.SamplesToFill * audio_data.number_of_channels);
   }
   for * synth.simple_waves if it.seconds >= it.release_end_seconds {
   	remove it;
   }
   // if synth.seconds >= synth.envelope.release_end_seconds ResetOscWave(wave, OscWaveState.FINISHED);
}

//TODO separate synth out eventually 
//TODO Once we only use SimpleSynths then we can clear most of this out
//and then adjust the subtractive synth with lfo and filters to use the simple osc wave
//and then add whatever we need for that specifically for that synth
OscWave :: struct {
	type : OscWaveType;
	wave_on : bool;
	wave_state : OscWaveState;

	//TODO Can we remove seconds and seconds_per_period
	//to reduce size of osc_wave?
	seconds : float;
	radians : float;
	frequency : float;
	//TODO This will likely be shared between many osc_waves
	//in the same lane, so we can pull it out of here.
	envelope : VolumeEnvelope;
	release_start_seconds : float = FLOAT32_MAX;
	//We need release_end_seconds so that we can set to max and not release if we are less than max
	release_end_seconds : float = FLOAT32_MAX;

	//Note : used for convenience for volume envelope, vibrato depth, etc...
	//Note : amp_factor could be a time based function for more realistic synthesis possibilities
	amp_factor : float = 1.0;

	//Note : convenient data for speed in synthesis calculations
	//TODO Maybe we can remove samples_per_period and seconds_per_period if we don't use those
	samples_per_period : float;
	radians_per_sample : float;
	seconds_per_period : float;
}

OscWaveState :: enum u8 {
	NOT_STARTED;
	PLAYING;
	FINISHED;
}

//UPDATE if changed in Library
OscWaveType :: enum {
	SINE;
	SQUARE;
	SAW;
	TRIANGLE;

	FOURIER_SINE;
	FOURIER_SQUARE;
	FOURIER_SAW;
	FOURIER_TRIANGLE;
	FOURIER_SUMOFCOS;

	PIANO;
	PIANO_2;
	PIANO_3;
	
	NONE;
} @LibraryAsmGen

VolumeEnvelope :: struct {
	type : VolumeEnvelopeType = VolumeEnvelopeType.EXPONENTIAL;
	//TODO Remove these rom here since these are now stored in the wave
	release_start_seconds : float = FLOAT32_MAX;
	//TODO note sure we need release_end_seconds since
	//release_end_seconds = release_start_seconds + release_seconds
	release_end_seconds : float = FLOAT32_MAX;

	//TODO Could add a decay in here as well.
	//Note: 15 ms removes jarring clipping from most waveforms
	attack_seconds : float; //= 0.015;
	n_attack : float = 1.0; // Default to linear
	release_seconds : float; //= 0.015;
	n_release : float = 1.0; // Default to linear
}
VolumeEnvelopeLinear :: struct {
	release_start_seconds : float = FLOAT32_MAX;
	//TODO note sure we need release_end_seconds since
	//release_end_seconds = release_start_seconds + release_seconds
	release_end_seconds : float = FLOAT32_MAX;

	//TODO Could also add a sustain value although the volume can adjust that anyways.
	//TODO Could add decay here as well or just in SubtractiveSynth
	//Note: 15 ms removes jarring clipping from most waveforms
	attack_seconds : float; //= 0.015;
	release_seconds : float; //= 0.015;
}

VolumeEnvelopeType :: enum {
	NONE;
	LINEAR;
	EXPONENTIAL;
}

//TODO Should we change the defaults here?
//These defaults generally avoid clipping
DEFAULT_ATTACK_SECONDS : float : 0.02;
DEFAULT_RELEASE_SECONDS : float : 0.05;
MakeVolumeEnvelope :: (
	attack_seconds : float = DEFAULT_ATTACK_SECONDS, 
	release_seconds : float = DEFAULT_RELEASE_SECONDS,
	n_attack : float = 1.0,
	n_release : float = 1.5) 
-> VolumeEnvelope 
{
    env : VolumeEnvelope;
    env.attack_seconds = attack_seconds;
    env.release_seconds = release_seconds;
    env.n_attack = n_attack;
    env.n_release = n_release;
    return env;
}

SetEnvelopeRelease :: inline (release_start_seconds : float, envelope : *VolumeEnvelope) {
	envelope.release_start_seconds = release_start_seconds;
	envelope.release_end_seconds = release_start_seconds + envelope.release_seconds;
}
SetWaveRelease :: inline (release_start_seconds : float, wave : *OscWave, env : VolumeEnvelope) {
	wave.release_start_seconds = release_start_seconds;
	wave.release_end_seconds = release_start_seconds + env.release_seconds;
}
ForceEnvelopeRelease :: inline (release_start_seconds : float, release_end_seconds : float, envelope : *VolumeEnvelope) {
	envelope.release_start_seconds = release_start_seconds;
	envelope.release_end_seconds = release_end_seconds;
}
ForceWaveRelease :: inline (release_start_seconds : float, release_end_seconds : float, wave : *OscWave) {
	wave.release_start_seconds = release_start_seconds;
	wave.release_end_seconds = release_end_seconds;
}


MakeOscWave :: inline (frequency : float, type : OscWaveType,
					   audio_data : AudioData,
					   envelope : VolumeEnvelope = VolumeEnvelope.{}) -> OscWave
{
	result : OscWave;
	UpdateWaveFrequency(frequency, *result, audio_data);
	result.type = type;
	result.envelope = envelope;
	return result;
}

ResetOscWave :: inline (wave : *OscWave, $wave_state : OscWaveState = OscWaveState.NOT_STARTED) {
	wave.wave_on = false;
	wave.wave_state = wave_state;
	wave.seconds = 0;
	wave.radians = 0;
	wave.envelope.release_start_seconds = FLOAT32_MAX;
	wave.envelope.release_end_seconds = FLOAT32_MAX;
}

SetPlayOscWaveWithRelease :: inline (
	wave : *OscWave,
	end_seconds : float) 
{
	wave.wave_state = OscWaveState.PLAYING;
	wave.wave_on = true;
	//TODO should this be kept in float64
	//TODO Should this be happening at end_seconds instead of before?
	//Set it to end_seconds because seems like thats what DAWs do (tested in fl studio)
	SetEnvelopeRelease(end_seconds, *wave.envelope);
	// SetEnvelopeRelease(end_seconds - wave.envelope.release_seconds, *wave.envelope);
}

//TODO should we move out audioData and only pass in sample rate?
UpdateWaveFrequency :: inline (frequency : float, wave : *OscWave, audio_data : AudioData) {
    wave.frequency = frequency;
    wave.samples_per_period = audio_data.SampleRate / wave.frequency;
    wave.radians_per_sample = TAU / wave.samples_per_period;
    wave.seconds_per_period = TAU / wave.radians_per_sample / audio_data.SampleRate;
}

IncrementWave :: inline (wave : *OscWave, rads : float, seconds : float) {
   wave.radians += rads;
	wave.seconds += seconds;
	if wave.radians >= TAU then wave.radians -= TAU;
}

//TODO probably add dynamic arrays of these (or with a max cap)
//Likely just add as we need and then clear whenever the music stops or reset or something like that.
//This can be adjusted so that the row can be associated to anything, internal or external.
//TODO or a compile time size
Synthesizer :: struct {
	carrier : OscWave;
	oscillator : OscWave;
}

//TODO currently only have ASR but should implement ADSR eventually
//TODO profile difference between linear and pow (with and without compile optimizations)
//TODO could set volume state as an ADSR enum and check position based on state
//TODO adjust volume based on type or just exponential if thats more efficient
//TODO maybe remove linear altoghether and only compute exponential
VolumeCoefficient :: inline (seconds : float, using envelope : VolumeEnvelope) -> float {
	result : float = 1.0;
	// if type == VolumeEnvelopeType.LINEAR {
	//     if seconds < attack_seconds {
	//     	result = seconds / attack_seconds;
	//     }
	//     if seconds >= release_start_seconds + release_seconds {
	//     	result = 0;
	//     } else if seconds > release_start_seconds {
	//     	release_delta : float = seconds - release_start_seconds;
	//     	release_factor : float = 1.0 - (release_delta / release_seconds);
	//     	result = release_factor;
	//     }
	// } else if type == VolumeEnvelopeType.EXPONENTIAL {
		//TODO optimize by storing 1.0 / attack_seconds and 1.0 / release_seconds
	    if seconds < attack_seconds {
	    	result = pow(seconds / attack_seconds, 1.0/n_attack);
	    } else if seconds >= release_end_seconds {
	    	result = 0;
	    } else if seconds > release_start_seconds {
	    	release_delta : float = seconds - release_start_seconds;
	    	release_factor : float = 1.0 - pow(release_delta / release_seconds, 1.0/n_release);
	    	result = release_factor;
	    }		
	// }
    return result;
}
VolumeCoefficient :: inline (wave : OscWave, env : VolumeEnvelope) -> float {
	result : float = 1.0;
	if wave.seconds < env.attack_seconds {
		result = pow(wave.seconds / env.attack_seconds, 1.0/env.n_attack);
	} else if wave.seconds >= wave.release_end_seconds {
		result = 0;
	} else if wave.seconds > wave.release_start_seconds {
		release_delta : float = wave.seconds - wave.release_start_seconds;
		release_factor : float = 1.0 - pow(release_delta / env.release_seconds, 1.0/env.n_release);
		result = release_factor;
	}		
	return result;
}

GenerateSamples :: (using synth : *Synthesizer, audio_data : AudioData) -> [] float {
	buffer := NewArray(audio_data.SamplesToFill, float, false,, temp);
	carrier_foo : SampleFunction = GetWaveFunction(carrier.type);
	osc_foo : SampleFunction = GetWaveFunction(oscillator.type);
	//Note : if SamplesToFill == 0 then this doesnt do anything
	for 0..audio_data.SamplesToFill-1 {
		//TODO should we generate new carrier every time for natural carrier starting and ending every time
		sample_carrier : float = carrier.amp_factor * carrier_foo(carrier.radians);
		sample_carrier *= VolumeCoefficient(carrier.seconds, carrier.envelope);
		buffer[it] = sample_carrier;

		radians_per_sample : float = carrier.radians_per_sample;
		//TODO can remove this if statement by having a separate GenerateSamples function if oscillator.wave_on
		//TODO could also just run this evertyime and if it does nothing the amp_factor or env_factor = 0
		//so nothing would happen to the carrier wave. Also, the osc_foo could do nothing maybe.
		if oscillator.wave_on {
			//TODO separate this with pitch shifter with envelope and any waveform
			sample_osc : float = osc_foo(oscillator.radians);
			env_factor : float = VolumeCoefficient(oscillator.seconds, oscillator.envelope);
			osc_freq : float = carrier.frequency * (1.0 + env_factor * oscillator.amp_factor * sample_osc);
			// print("osc_freq is %\n", osc_freq);
			osc_samples_per_period : float = audio_data.SampleRate / osc_freq;
			radians_per_sample = TAU / osc_samples_per_period;
			// vib_seconds_per_period : float = TAU / vib_radians_per_sample / audio_data.SampleRate;
			//TODO could move this out for efficiency if we want oscillator to act on entire carrier time
			if oscillator.seconds >= oscillator.envelope.release_end_seconds ResetOscWave(*oscillator, OscWaveState.FINISHED);
			else IncrementWave(*oscillator, oscillator.radians_per_sample, audio_data.seconds_per_sample);
		}
		IncrementWave(*carrier, radians_per_sample, audio_data.seconds_per_sample);
	}
	if carrier.seconds >= carrier.envelope.release_end_seconds ResetOscWave(*carrier, OscWaveState.FINISHED);
	return buffer;
}

GenerateSamples :: (wave : *OscWave, audio_data : AudioData) -> [] float {
	buffer := NewArray(audio_data.SamplesToFill, float, false,, temp);
	GenerateSamples(wave, audio_data, buffer);
	return buffer;
}

//TODO pass in allocator
//TODO profile difference with conditional in and out of the loop
GenerateSamples :: (wave : *OscWave, audio_data : AudioData, buffer : [] float) {
	sample_function : SampleFunction = GetWaveFunction(wave.type);
   /*Note : if SamplesToFill == 0 then this doesnt do anything
	Also, currently if wave.seconds >= envelope.release_end_seconds
	we keep filling the buffer on that frame to avoid making the conditional check
	for every sample on every frame. (could profile this difference to measure true efficiency)
   */
   // for 0..audio_data.SamplesToFill-1 {
   for 0..buffer.count-1 {
   	//TODO should we generate new wave every time for natural wave starting and ending every time
   	sample_f32 : float = sample_function(wave.radians);
		sample_f32 *= VolumeCoefficient(wave.seconds, wave.envelope);
   	buffer[it] = sample_f32;
   	//TODO Could try SIMDing the synth by incrementing and then running on multiple samples
   	IncrementWave(wave, wave.radians_per_sample, audio_data.seconds_per_sample);
   }
   //TODO Should have an option for no release until we say although this can just be setting
   //release_end_seconds to be MAX_FLOAT or also having an OscWaveState that does not trigger this here
   if wave.seconds >= wave.envelope.release_end_seconds ResetOscWave(wave, OscWaveState.FINISHED);
}

//TODO should we add/process signals before and then just copy them here?
//TODO should we store normalized wave first and then add to audio before and fourier analysis
MAX_VOLUME : s16 : 32700; //2^15 truncated to hundreds
AddSignalToAudioBuffer :: (signal : [] float, audio : *AudioData) {
   assert(audio.SamplesToFill <= audio.BufferSize / audio.BytesPerSample,
      "SamplesToFill : %, BufferSize : %, BytesPerSample : %\n", audio.SamplesToFill,
      audio.BufferSize, audio.BytesPerSample);
   assert(abs(audio.Volume) <= MAX_VOLUME);
   start_buffer : *s16 = audio.audio_buffer;
   //TODO SIMD volume and adding to audio_buffer
   for sample_f32 : signal {
	   sample_s16 := cast(s16) (sample_f32 * audio.Volume);
      <<start_buffer += sample_s16;
      start_buffer += 1;
      <<start_buffer += sample_s16;
      start_buffer += 1;
   }
}

//TODO remove this eventually if we only add to buffer with separate GenerateSamples
AddToAudioBuffer :: (wave : *OscWave, audio : *AudioData) {
   assert(audio.SamplesToFill <= audio.BufferSize / audio.BytesPerSample,
           "SamplesToFill : %, BufferSize : %, BytesPerSample : %\n", audio.SamplesToFill,
           audio.BufferSize, audio.BytesPerSample);
   assert(abs(audio.Volume) <= MAX_VOLUME);
   start_buffer : *s16 = audio.audio_buffer;
	sample_function : SampleFunction = GetWaveFunction(wave.type);
   //Note : if SamplesToFill == 0 then this doesnt do anything
   for 0..audio.SamplesToFill-1 {
    	//TODO should we generate new wave every time for natural wave starting and ending every time
    	sample_f32 : float = sample_function(wave.radians);

    	//TODO probably add separately with more specific array
    	//TODO test with multiple frequencies
		// if buffer != null && buffer.count < 32768 array_add(buffer, sample_f32);

		sample_f32 *= VolumeCoefficient(wave.seconds, wave.envelope);
		//TODO Does clamping this value do clipping to avoid audio wrapping distortion
	   sample_s16 := cast(s16) (sample_f32 * audio.Volume * 0.6);

      <<start_buffer += sample_s16;
      start_buffer += 1;
      <<start_buffer += sample_s16;
      start_buffer += 1;

   	IncrementWave(wave, wave.radians_per_sample, audio.seconds_per_sample);
   }

   // if wave.seconds >= wave.envelope.release_start_seconds + wave.envelope.release_seconds {
   if wave.seconds >= wave.envelope.release_end_seconds {
    	ResetOscWave(wave, OscWaveState.FINISHED);
	}
}

ClearAudioBuffer :: (audio_data : *AudioData) {
	start_buffer : *s16 = audio_data.audio_buffer;
	total_buffer_samples := audio_data.BufferSize / audio_data.BytesPerSample;
	//TODO could clear to samples_to_fill which would be much faster but this is more resilient
	//TODO Could do this with memcpy of an already blank array
	//TODO USE memset here
	for 1..total_buffer_samples {
		<<start_buffer = 0;
		start_buffer += 1;
		<<start_buffer = 0;
		start_buffer += 1;
	}

   memset(audio_data.float_buffer, 0, audio_data.float_buffer_size); 
}

//TODO could store these in a hash map depending on size and efficiency
SampleFunction :: #type (radians : float) -> float;
GetWaveFunction :: (wave_type : OscWaveType) -> SampleFunction {
	sample_function : SampleFunction;
	if wave_type == {
		case OscWaveType.NONE;     sample_function = SampleNone;
		case OscWaveType.SINE;     sample_function = SampleGeometricSine;
		case OscWaveType.SQUARE;   sample_function = SampleGeometricSquare;
		case OscWaveType.SAW;      sample_function = SampleGeometricSaw;
		case OscWaveType.TRIANGLE; sample_function = SampleGeometricTriangle;

		case OscWaveType.FOURIER_SINE;     sample_function = SampleFourierSine;
		case OscWaveType.FOURIER_SQUARE;   sample_function = SampleFourierSquare;
		case OscWaveType.FOURIER_SAW;      sample_function = SampleFourierSaw;
		case OscWaveType.FOURIER_TRIANGLE; sample_function = SampleFourierTriangle;
		case OscWaveType.FOURIER_SUMOFCOS; sample_function = SampleFourierSumOfCosines;

		case OscWaveType.PIANO;   sample_function = SamplePiano;
		case OscWaveType.PIANO_2; sample_function = SamplePiano2;
		case OscWaveType.PIANO_3; sample_function = SamplePiano3;
	}
	return sample_function;
}

SampleNone :: inline (radians : float) -> float {
	return 0;
}

/*
	Geometric Waveforms
*/
SampleGeometricSine :: inline (radians : float) -> float {
    sample_f32 : float = sin(radians);
    return sample_f32;
}

SampleGeometricSquare :: inline (radians : float) -> float {
   sample_f32 : float = -1.0; //-volume from PI to 2*PI
	if radians >= 0 && radians < PI {
		sample_f32 = 1.0;
	}
	return sample_f32;
}

ONE_OVER_PI :: 1.0/PI;
SampleGeometricSaw :: inline (radians : float) -> float {
	sample_f32 : float = radians;
	if radians >= PI && radians < TAU {
		sample_f32 -= TAU;
	}
	sample_f32 *= ONE_OVER_PI;
	return sample_f32;
}

//NOTE : With 2* we go between 0-2 and without between 0-1 (old way was between 0-1)
//So to match with -1 and 1 of other waveforms we multiply by 2 and subtract 1.
SampleGeometricTriangle :: inline (radians : float) -> float {
	sample_f32 : float = 2.0 * (1.0 - (abs(radians - PI) * ONE_OVER_PI)) - 1.0;
	// sample_f32 : float = 1.0 - (abs(radians - PI) * ONE_OVER_PI);
	// print("sample:%\n", sample_f32);
	return sample_f32;
}

/*
	End of Geometric Waveforms
*/


/*
	Fourier series expansion wave forms

	Note : can somewhat low-pass filter by having less loops
*/
SampleFourierSine :: inline (radians : float) -> float {
    sample_f32 : float = sin(radians);
    return sample_f32;
}

SampleFourierSquare :: inline (radians : float) -> float {
	sample_f32 : float;
	for k : 0..30 {
		sample_f32 += (1.0 / (2.0*k + 1.0)) * sin((2.0*k + 1.0)*radians);
	}
    return sample_f32;
}

SampleFourierTriangle :: inline (radians : float) -> float {
	sample_f32 : float;
	for k : 0..20 {
		twoKp1 : float = 2.0*k + 1.0;
		sample_f32 += (1.0 / (twoKp1*twoKp1)) * sin(twoKp1*radians);
	}
    return sample_f32;
}

SampleFourierSaw :: inline (radians : float) -> float {
	sample_f32 : float;
	for k : 1..45 {
		sample_f32 += (pow(-1.0, k+1.0) / k) * sin(k*radians);
	}
    return sample_f32;
}

SampleFourierSumOfCosines :: inline (radians : float) -> float {
	sample_f32 : float;
	N := 2;
	for k : 1..N {
		sample_f32 += cos(k*radians);
	}
	sample_f32 *= 1.0 / N;
	return sample_f32;
}

ROOT_3 :: 1.732050;
HALF_ROOT_3 :: 0.5 * ROOT_3;
SamplePiano :: (radians : float) -> float {
	sample_f32 : float = 
		-0.25 * sin(1.3333 * radians) + 0.25 * sin(0.5*radians) + HALF_ROOT_3 * cos(0.5*radians);
    return sample_f32;
}

SamplePiano2 :: (radians : float) -> float {
	sample_f32 : float = sin(radians) * exp(-0.0004 * radians);
	sample_f32 += sin(2 * radians) * exp(-0.0004 * radians) / 2;
	sample_f32 += sin(3 * radians) * exp(-0.0004 * radians) / 4;
	sample_f32 += sin(4 * radians) * exp(-0.0004 * radians) / 8;
	sample_f32 += sin(5 * radians) * exp(-0.0004 * radians) / 16;
	sample_f32 += sin(6 * radians) * exp(-0.0004 * radians) / 32;
	sample_f32 += sample_f32 * sample_f32 * sample_f32;
    return sample_f32;
}

SamplePiano3 :: (radians : float) -> float {
	sample_f32 : float = 0.6*sin(radians) * exp(-0.0015 * radians);
	sample_f32 += 0.4*sin(2*radians) * exp(-0.0015 * radians);
	sample_f32 += sample_f32 * sample_f32 * sample_f32;
    return sample_f32;
}

/* Filters
*/

FilterFamily :: enum {
	ONE_ZERO;
	ONE_POLE;
	TWO_POLE;
	BIQUAD; //Second-order filter (PRETTY GOOD)
	//TODO butterworth higher order : http://www.apicsllc.com/apics/Sr_3/Sr_3.htm
}

FilterType :: enum {
	LOW_PASS;
	HIGH_PASS;
	BAND_PASS;
}

FilterParams :: struct {
	audio_data : *AudioData;
	family : FilterFamily;
	type : FilterType;
	c_freq : float;
	Q : float = 1.0;
	//TODO add filter coefficient caching
	//TODO add bandwidth with sinh
}

/*  Biquad Filters
	//TODO add all filter types
	https://www.w3.org/TR/audio-eq-cookbook/

	w0 = TAU*frequency/SampleRate
	alpha = sin(w0) / 2Q
	
	y[n]=(b0/a0)x[n]+(b1/a0)x[n−1]+(b2/a0)x[n−2]−(a1/a0)y[n−1]−(a2/a0)y[n−2]
	y[0]=(b0/a0)x[0]
	y[1]=(b0/a0)x[1]+(b1/a0)x[0]-(a1/a0)y[0]=(b0/a0)x[1]+(b1/a0)x[0]-(a1/a0)*((b0/a0)x[0])
	y[2]=(b0/a0)x[2]+(b1/a0)x[1]+(b2/a0)x[n-2]-(a1/a0)y[1]-(a2/a0)y[0]

	//TODO pass in allocator
*/
BiquadFilter :: (input : [] float, using params : FilterParams) -> [] float {
	w0 : float = TAU*c_freq/audio_data.SampleRate;
	alpha : float = sin(w0)/(2*Q);

	//TODO hardcoded to band-pass, add other biquad filter types
	b0 : float = alpha;
	b1 : float = 0;
	b2 : float = -alpha;
	a0 : float = 1 + alpha;
	a1 : float = -2*cos(w0);
	a2 : float = 1 - alpha;

	//TODO pre-divide here
	//TODO could cache all variables until we change them

	output : [] float = NewArray(input.count, float, false,, temp);
	output[0] = (b0/a0)*input[0];
	output[1] = (b0/a0)*input[1] + (b1/a0)*input[0] - (a1/a0)*output[0];
	//TODO This loop seems simdable once we hardcode all the filter coefficients. What about the output[n-x]?
	for n : 2..input.count-1 {
		output[n] = (b0/a0)*input[n] + (b1/a0)*input[n-1] + (b2/a0)*input[n-2] - (a1/a0)*output[n-1] - (a2/a0)*output[n-2];
	}
	return output;
}

/* End of filters
*/

//TODO convert this to new format
/*for rads != m * 2pi -> SampleValue = sin((2N + 1) * rads / 2) / sin(rads / 2)
  for rads == m * 2pi -> SampleValue = 2N + 1
  where N = number of harmonics above frequency
  rads_per_sample_s16 = 2pi(rads/period) / sample_rate(samples/sec) / frequency(periods/sec)
  rads = rads_per_sample_s16 * sample

  TODO change UseSampleFloat to something more meaningful like radians or rads
*/
GenerateBuzz :: (audio : *AudioData) -> SampleValue : s16 {
    N : s16 = 1;
    EPSILON : float64 = 0.01;
    SampleValue : s16;

    check : float64 = abs(audio.UseSampleFloat - TAU64);
    if audio.UseSampleFloat < EPSILON || check < EPSILON {
        SampleValue = audio.Volume * (2 * N + 1);
    } else {
        value : float64 = sin((N + 0.5) * audio.UseSampleFloat) / sin(0.5 * audio.UseSampleFloat);
        SampleValue = cast(s16) value * audio.Volume; // TODO what about >= audio.Volume?
    }
    audio.UseSampleFloat += TAU64 / audio.SamplesPerPeriod; //add rads_per_sample_s16 every sample
    if audio.UseSampleFloat >= TAU64 {
        audio.UseSampleFloat -= TAU64;
    }
    return SampleValue;
}

//TODO this does not work, maybe consider removing once we do filters properly
GenerateBuzzWithFilter :: (audio : *AudioData) -> SampleValue : s16 {
    N : s16 = 3;
    R : float64 = 0.9;
    EPSILON : float64 = 0.01;
    SampleValue : float64;

    audio.LastSampleValue2 = audio.LastSampleValue1;
    audio.LastSampleValue1 = audio.LastSampleValueTemp;
    check : float64 = abs(audio.UseSampleFloat - TAU64);
    if audio.UseSampleFloat < EPSILON || check < EPSILON {
        SampleValue = cast(float64) (2 * N + 1);
    } else {
        SampleValue = sin((N + 0.5) * audio.UseSampleFloat) / sin(0.5 * audio.UseSampleFloat);
    }
    cos_theta : float64 = (2 * R / (1 + R * R)) * cos(audio.ResonTheta);
    gain_factor : float64 = (1 - R * R) * sin(acos(cos_theta));
    filtered_value : float64 = gain_factor * SampleValue + 2 * R * cos_theta * audio.LastSampleValue1 - 
                                R * R * audio.LastSampleValue2;
    audio.LastSampleValueTemp = filtered_value;
    ReturnSampleValue : s16 = audio.Volume * cast(s16) filtered_value;

    audio.UseSampleFloat += TAU64 / audio.SamplesPerPeriod; //add rads_per_sample_s16 every sample
    if audio.UseSampleFloat >= TAU64 {
        audio.UseSampleFloat -= TAU64;
    }

    return ReturnSampleValue;
}

//AUDIO TIMING
AudioTiming :: struct {
	current_time : float64;
	last_time : float64;
	time_delta : float64;

	//TODO Can likely remove this beat stuff
	//since we define it elsewhere now with memory_units
	current_beat : float64;
	current_beat_int : int;
	last_beat : float64;
	beat_delta : float64;
	hit_beat_this_frame : bool;

	//TODO Can we have bpm/bps in GameAudioPlay
	bpm : float64;
	bps : float64;
}

ONE_OVER_60 : float64 : 1.0 / cast(float64) 60.0;
SetAudioTimingBPM :: inline (at : *AudioTiming, bpm : float64) {
	at.bpm = bpm;
	at.bps = bpm * ONE_OVER_60;
}

//TODO Can likely pass in a lock here for the play_time and update that in the audio thread directly.
UpdateAudioTiming :: inline (timing : *AudioTiming, audio_data : AudioData) {
	timing.last_time = timing.current_time;
	timing.last_beat = timing.current_beat;

	//TODO This atomic_read does nothing other than say this should be atomic. Should we use a compare and swap?
	//Probably using atomic_read is fine since this is 8 byte float64 and will be done with 1 mov but just in case.
	//Maybe the atomics will get update later and then we can use whatever is used there.
	// audio_play_time : float64 = atomic_read(audio_data.play_time);
	//NOTE : play_time >= 0 so if it's 0 then it swaps to 0 and return old_value=0 and 
	//if it's > 0 then we return the old_value in memory which is what we want.
	//TODO We could also atomically load the play_cursor into timing here for convenience
	//TODO We can just grab the value I think if this does not work. It does not seem to work with the x64 backend but is ok with LLVM.
	success, audio_play_time := compare_and_swap(*audio_data.play_time, 0, 0);
	timing.current_time = audio_play_time;
	// timing.current_time = audio_data.play_time;
	timing.time_delta = timing.current_time - timing.last_time;
	timing.current_beat = timing.bps * timing.current_time;
	timing.beat_delta = timing.current_beat - timing.last_beat;
	//TODO Could have a current memory_index relative to how many memory_units per beat we have
	// or how much time per memory_unit.

	last_beat_int : int = cast(int) timing.last_beat;
	timing.current_beat_int = cast(int) timing.current_beat;

	timing.hit_beat_this_frame = false;
	if last_beat_int < timing.current_beat_int {
		timing.hit_beat_this_frame = true;
	}

    //Note : this is for when new play cursor > dt (eg at higher framerates)
    //it also helps with audio/video spikes/lags by easing between them with / 2.0
#if 0 {
    if(new_time > play_time) {
        previous_time = play_time;
        play_time = new_time;
        current_time = (current_time + new_time) / 2.0;
        // print_audio_stats(stream, data);
    }
    else if(current_time > 0) {
       current_time += dt;
    }
    current_beat = bpm * (current_time - 0.18) / 60.0; //audio travel time is fixed audio offset for now, should be setting input
}
}

BeatHitThisFrame :: inline (beat_index : int, beat_count : int, audio_timing : AudioTiming) -> bool {
	assert(beat_count != 0);
	beat_hit : bool = (audio_timing.current_beat_int % beat_count) == beat_index &&
					   audio_timing.hit_beat_this_frame;
	return beat_hit;
}

//END OF AUDIO TIMING

/*
	TODO leaving here for float64 example without the TAU subtraction
    This is the cleanest sine wave in the entire fucking universe!
*/
//Passing in frequency instead of period here makes more conceptual sense
//but is way less efficient since we would have to divide every single time
GenerateAndIncrementSineWave :: (audio : *AudioData) -> SampleValue : s16 {
    sin := sin_or_cos(audio.UseSampleFloat, true);
    SampleValue := cast(s16) (sin * audio.Volume);
    audio.UseSampleFloat += TAU64 / audio.SamplesPerPeriod; //radians per sample
    /*TODO this is one way we can add waves together
    new_sin := sin_or_cos(audio.UseSampleFloat, true);
    if sin <= 0 && new_sin > 0 {
        print("New period from % to %\n", sin, new_sin);
    }
    */
    return SampleValue;
}

//TODO Should we move this into shared library instead of here? So then we only have to import this module if we want to do audio stuff?
//TODO clean this up, lots of dead variables in here
AudioData :: struct {
	/*DOC : Keeping this 16-bit depth makes sense because all systems will likely support it
	and we know it runs on direct sound and now wasapi in miniaudio.
	Maybe if we only use miniaudio later, then we can just copy as float directly
	but for now this makes sense for compatibility.
	ALSO this allows us to control things like bit depth and clipping from a user
	perspective so that they can edit it to whatever they want while things are running.
	Need to set noClip in miniaudio if we want to do our own 16-bit clipping from float.
	*/
	//Per frame 16 bit audio sample buffer
	audio_buffer : *s16;
	//each sample is 16 bit
	//2 bytes per sample for left speaker and 2 bytes for right speaker
	BytesPerSample : int = size_of(s16) * 2;

	float_buffer : *float;
	float_buffer_size : int;
	bytes_per_float_sample : int;
	number_of_channels : int;

    //TODO should we move this out of the platform layer
    fourier_buffer_size : int = 16384;

	/*This gives the play_cursor in samples
		Note : we use int (s64) here because s32 gives us about 
		12 hours (2^31 / 48000) worth of samples at 48000 sample rate
		and s64 gives us over 6 million years 6,093,150 = (2^64 / 48000 / 60(sec/min) / 60(min/hour) / 24(hour/day) / 365(day/year))
		who knows if well want an infinite song or if someone wants to leave the game on forever  
		TODO Can make this a u64 to get that extra bit.
	*/
	play_cursor : int;
	play_time : float64;
	beats_per_minute : float64;

	//TODO cleanup everything we don't use
    SamplesToFill : int;
    SamplesPerPeriod : float64;
    SamplesPerPeriod32 : float;
    SampleRate : int = 48000;
    seconds_per_sample : float;
    seconds_per_sample_f64 : float64;
    BufferSize : int; //in bytes
    Playing : bool = false;
    Volume : s16 = 6000;
    //Should this be an int or just mod it with buffer size
    SampleCounter : int;
    SampleCounterFloat : float64;
    UseSampleFloat : float64;
    UseSampleFloat2 : float64;
    Frequency : s32;

    //For Fun vars <3
    UseSampleFloat32 : float;

    radian_total : [2] float;
    frequencies : [2] float;

    //TODO should this be in the note?
    // waves : [10] WaveOsc;

    UseSampleFloatZero : float64;
    UseSampleFloatZero32 : float;
    SampleCounterFloat32 : float;
    PeriodCount : int;

    //Filter Variables
    //TODO this should be an array for larger scale filters
    LastSampleValue1 : float64;
    LastSampleValue2 : float64;
    LastSampleValueTemp : float64;
    SampleNum : int;
    ResonTheta : float64;
}
//END OF AUDIO

//OLD STUFF LEAVING HERE FOR NOSTALGIA ATM
/*
    Sine wave with noise due to the abrupt push to 0 at the end of every period
*/
GenerateAndIncrementSineWaveZero :: (audio : *AudioData, SamplesPerPeriod : float64) -> SampleValue : s16 {
    if audio.SampleCounterFloat >= SamplesPerPeriod {
        audio.SampleCounterFloat -= SamplesPerPeriod;
        audio.UseSampleFloatZero = 0;
    }
    sinZero := sin_or_cos(audio.UseSampleFloatZero, true);
    SampleValueZero := cast(s16) (sinZero * audio.Volume);
    audio.UseSampleFloatZero += TAU64 / SamplesPerPeriod;
    audio.SampleCounterFloat += 1;
    return SampleValueZero;
}

/*
    Sine wave (32 bit) with noise due to the abrupt push to 0 at the end of every period
    This one has slightly more noise than 64 bit I guess since its more off / less precise
*/
GenerateAndIncrementSineWaveZero32 :: (audio : *AudioData, SamplesPerPeriod32 : float) -> SampleValue : s16 {
    if audio.SampleCounterFloat >= SamplesPerPeriod32 {
        audio.SampleCounterFloat -= SamplesPerPeriod32;
        audio.UseSampleFloatZero32 = 0;
    }
    sinZero32 := sin_or_cos(audio.UseSampleFloatZero32, true);
    SampleValueZero32 := cast(s16) (sinZero32 * audio.Volume);
    audio.UseSampleFloatZero32 += TAU / SamplesPerPeriod32;
    audio.SampleCounterFloat32 += 1;
    return SampleValueZero32;
}

PrintSineWaveInfo :: (audio : AudioData, SampleValue : float64, SampleValue32 : float, 
                        SampleValueZero : float64, SampleValueZero32 : float) {
    print("value64 = %, vol = %\n value32 = %, vol = %\n zero = %, vol = %\n zero64 = %, vol = %\n\n", 
        formatFloat(fmod_cycling(audio.UseSampleFloat, TAU64), 15, 15),
        SampleValue, 
        formatFloat(fmod_cycling(audio.UseSampleFloat32, TAU), 15, 15),
        SampleValue32, 
        formatFloat(audio.UseSampleFloatZero, 15, 15),
        SampleValueZero, 
        formatFloat(audio.UseSampleFloatZero32, 15, 15),
        SampleValueZero32
    );
}

GenerateAndIncrementSquareWave :: (audio : *AudioData) -> SampleValue : s16 {
    SampleValue : s16;
    if fmod_cycling(audio.UseSampleFloat, audio.SamplesPerPeriod) < (audio.SamplesPerPeriod / 2) {
        SampleValue = -audio.Volume;
    } 
    else {
        SampleValue = audio.Volume;
    }
    audio.UseSampleFloat += 1;
    return SampleValue;
}

GenerateAndIncrementSquareWave32 :: (audio : *AudioData) -> SampleValue : s16 {
    SampleValue : s16;
    if fmod_cycling(audio.UseSampleFloat32, audio.SamplesPerPeriod32) < (audio.SamplesPerPeriod32 / 2) {
        SampleValue = -audio.Volume;
    } 
    else {
        SampleValue = audio.Volume;
    }
    audio.UseSampleFloat32 += 1;
    return SampleValue;
}
