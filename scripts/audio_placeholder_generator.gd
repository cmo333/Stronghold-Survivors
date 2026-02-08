@tool
extends EditorScript

# ============================================
# AudioPlaceholderGenerator
# Generates placeholder WAV files for game audio
# Run from Godot Editor: File > Run > AudioPlaceholderGenerator
# ============================================

const SAMPLE_RATE = 44100
const BIT_DEPTH = 16

func _run():
	print("Generating placeholder audio files...")
	
	var base_path = "res://assets/audio"
	
	# Generate SFX
	_generate_gun_sounds(base_path + "/sfx")
	_generate_impact_sounds(base_path + "/sfx")
	_generate_weapon_sounds(base_path + "/sfx")
	
	# Generate UI sounds
	_generate_ui_sounds(base_path + "/ui")
	
	# Generate Ambient
	_generate_ambient_sounds(base_path + "/ambient")
	
	# Generate Special
	_generate_special_sounds(base_path + "/special")
	
	print("Placeholder audio generation complete!")

func _generate_gun_sounds(path: String):
	# Gun fire 01 - Short noise burst
	var noise1 = _generate_noise_burst(0.15, -6.0, 8000)
	_save_wav(path + "/gun_fire_01.wav", noise1)
	
	# Gun fire 02 - Slightly different
	var noise2 = _generate_noise_burst(0.12, -4.0, 10000)
	_save_wav(path + "/gun_fire_02.wav", noise2)
	
	# Gun fire 03 - Another variation
	var noise3 = _generate_noise_burst(0.18, -8.0, 6000)
	_save_wav(path + "/gun_fire_03.wav", noise3)

func _generate_impact_sounds(path: String):
	# Enemy hit sounds - short thuds
	for i in range(1, 4):
		var thud = _generate_thud(0.08 + i * 0.02, -3.0 - i)
		_save_wav(path + "/enemy_hit_0%d.wav" % i, thud)
	
	# Crit hit - sharper sound
	var crit = _generate_sharp_hit(0.1, 0.0)
	_save_wav(path + "/crit_hit.wav", crit)
	
	# Death sounds - longer, lower
	for i in range(1, 4):
		var death = _generate_thud(0.2 + i * 0.05, -6.0)
		_save_wav(path + "/enemy_death_0%d.wav" % i, death)
	
	# Building hit - metallic
	var building = _generate_metal_hit(0.15, -4.0)
	_save_wav(path + "/building_hit.wav", building)
	
	# Shield hit - resonant
	var shield = _generate_resonant_hit(0.2, -2.0)
	_save_wav(path + "/shield_hit.wav", shield)

func _generate_weapon_sounds(path: String):
	# Cannon boom - low explosion
	var cannon = _generate_explosion(0.4, 0.0)
	_save_wav(path + "/cannon_boom.wav", cannon)
	
	# Lightning crack - electric
	var lightning = _generate_electric(0.25, -3.0)
	_save_wav(path + "/lightning_crack.wav", lightning)
	
	# Arrow shoot - quick zip
	var arrow = _generate_zip(0.1, -6.0)
	_save_wav(path + "/arrow_shoot.wav", arrow)

func _generate_ui_sounds(path: String):
	# Click - short beep
	var click = _generate_beep(0.05, 800, -10.0)
	_save_wav(path + "/click.wav", click)
	
	# Hover - lighter beep
	var hover = _generate_beep(0.03, 1200, -16.0)
	_save_wav(path + "/hover.wav", hover)
	
	# Upgrade - ascending
	var upgrade = _generate_ascending(0.3, -6.0)
	_save_wav(path + "/upgrade.wav", upgrade)
	
	# Error - descending buzz
	var error = _generate_descending(0.2, -8.0)
	_save_wav(path + "/error.wav", error)
	
	# Wave start - dramatic
	var wave = _generate_dramatic(0.5, -4.0)
	_save_wav(path + "/wave_start.wav", wave)
	
	# Level up - chime
	var level = _generate_chime(0.6, -3.0)
	_save_wav(path + "/level_up.wav", level)

func _generate_ambient_sounds(path: String):
	# Generator hum - low drone
	var hum = _generate_drone(2.0, 80, -18.0)
	_save_wav(path + "/generator_hum.wav", hum)
	
	# Wind - noise with filtering
	var wind = _generate_filtered_noise(3.0, -20.0, 2000)
	_save_wav(path + "/wind.wav", wind)
	
	# Distant battle - rumbling
	var battle = _generate_rumble(4.0, -22.0)
	_save_wav(path + "/distant_battle.wav", battle)

func _generate_special_sounds(path: String):
	# Chest open - creak + chime
	var chest = _generate_creak(0.4, -4.0)
	_save_wav(path + "/chest_open.wav", chest)
	
	# Powerup spawn - magical sound
	var spawn = _generate_magical(0.5, -5.0)
	_save_wav(path + "/powerup_spawn.wav", spawn)
	
	# Powerup pickup - satisfying
	var pickup = _generate_satisfying(0.3, -4.0)
	_save_wav(path + "/powerup_pickup.wav", pickup)
	
	# Generator destroyed - explosion
	var destroyed = _generate_explosion(0.6, 0.0)
	_save_wav(path + "/generator_destroyed.wav", destroyed)
	
	# Heartbeat - rhythmic thump
	var heartbeat = _generate_heartbeat(1.0, -6.0)
	_save_wav(path + "/heartbeat.wav", heartbeat)
	
	# Game over - dramatic low
	var gameover = _generate_dramatic_low(1.5, -3.0)
	_save_wav(path + "/game_over.wav", gameover)
	
	# Victory - triumphant
	var victory = _generate_triumphant(1.2, -4.0)
	_save_wav(path + "/victory.wav", victory)
	
	# Berserk activate - intense
	var berserk = _generate_intense(0.5, -2.0)
	_save_wav(path + "/berserk_activate.wav", berserk)

# ============================================
# SOUND GENERATORS
# ============================================

func _generate_noise_burst(duration: float, volume_db: float, cutoff: int) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)  # 16-bit mono
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - t  # Linear decay
		var noise = (randf() * 2.0 - 1.0) * volume * envelope
		var sample = int16(clamp(noise * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_thud(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	var freq = 120.0
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = exp(-t * 10.0)
		var sample_val = sin(t * TAU * freq) * volume * envelope
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_sharp_hit(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = exp(-t * 20.0)
		var noise = (randf() * 2.0 - 1.0)
		var tone = sin(t * TAU * 800) * 0.5
		var sample_val = (noise * 0.7 + tone * 0.3) * volume * envelope
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_metal_hit(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = exp(-t * 15.0)
		var ring = sin(t * TAU * 600) * envelope
		var ring2 = sin(t * TAU * 900) * envelope * 0.5
		var sample_val = (ring + ring2) * volume
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_resonant_hit(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = exp(-t * 8.0)
		var wave = sin(t * TAU * 400) * envelope
		var wave2 = sin(t * TAU * 600) * envelope * 0.5
		var sample_val = (wave + wave2) * volume
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_explosion(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = exp(-t * 5.0)
		var noise = (randf() * 2.0 - 1.0)
		var rumble = sin(t * TAU * 60) * 0.5
		var sample_val = (noise * 0.8 + rumble * 0.2) * volume * envelope
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_electric(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - pow(t, 0.3)
		var crackle = randf() > 0.7 if (sin(t * TAU * 2000) * envelope) > 0.5 else 0.0
		var zap = sin(t * TAU * 1500 + sin(t * TAU * 100) * 200) * envelope
		var sample_val = (crackle * 0.5 + zap * 0.5) * volume
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_zip(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	var start_freq = 2000.0
	var end_freq = 100.0
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - t
		var freq = lerp(start_freq, end_freq, t)
		var sample_val = sin(t * TAU * freq) * volume * envelope
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_beep(duration: float, freq: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = sin(t * PI)  # Smooth start/end
		var sample_val = sin(t * TAU * freq) * volume * envelope
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_ascending(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	var start_freq = 400.0
	var end_freq = 1200.0
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - pow(t - 0.5, 2) * 4.0  # Parabolic envelope
		envelope = max(0, envelope)
		var freq = lerp(start_freq, end_freq, t)
		var sample_val = sin(t * TAU * freq) * volume * envelope
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_descending(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	var start_freq = 300.0
	var end_freq = 80.0
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - t
		var freq = lerp(start_freq, end_freq, t)
		var sample_val = sin(t * TAU * freq) * volume * envelope
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_dramatic(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - pow(t - 0.3, 2) * 3.0
		envelope = max(0, envelope)
		var freq = 200.0 + sin(t * TAU * 2) * 50.0
		var sample_val = sin(t * TAU * freq) * volume * envelope
		sample_val += sin(t * TAU * freq * 1.5) * volume * 0.3 * envelope
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_chime(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	var freqs = [523.25, 659.25, 783.99, 1046.50]  # C major chord
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = exp(-t * 4.0)
		var sample_val = 0.0
		for f in freqs:
			sample_val += sin(t * TAU * f) * volume * envelope * 0.25
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_drone(duration: float, freq: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var sample_val = sin(t * TAU * freq) * volume
		sample_val += sin(t * TAU * freq * 1.01) * volume * 0.5  # Beating effect
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_filtered_noise(duration: float, volume_db: float, cutoff: int) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var noise = (randf() * 2.0 - 1.0) * volume * 0.3
		var sample = int16(clamp(noise * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_rumble(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var noise = (randf() * 2.0 - 1.0) * 0.5
		var rumble = sin(t * TAU * 40) * 0.5
		var sample_val = (noise + rumble) * volume * 0.5
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_creak(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - t
		var freq = 150.0 + sin(t * TAU * 3) * 50.0
		var creak = sin(t * TAU * freq) * volume * envelope
		var sample = int16(clamp(creak * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_magical(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - pow(t - 0.5, 2) * 4.0
		envelope = max(0, envelope)
		var freq = 600.0 + sin(t * TAU * 5) * 200.0
		var sparkle = sin(t * TAU * freq) * volume * envelope
		var sample = int16(clamp(sparkle * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_satisfying(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	var freqs = [440.0, 554.37, 659.25]  # A major
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = exp(-t * 6.0)
		var sample_val = 0.0
		for f in freqs:
			sample_val += sin(t * TAU * f) * volume * envelope * 0.33
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_heartbeat(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	var bpm = 60.0
	var beat_interval = 60.0 / bpm
	
	for i in range(samples):
		var t = float(i) / SAMPLE_RATE
		var beat_pos = fmod(t, beat_interval)
		var envelope = 0.0
		if beat_pos < 0.1:
			envelope = 1.0 - beat_pos * 10.0
		elif beat_pos > 0.15 and beat_pos < 0.2:
			envelope = (0.2 - beat_pos) * 20.0 * 0.6
		var thump = sin(beat_pos * TAU * 80) * volume * envelope
		var sample = int16(clamp(thump * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_dramatic_low(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - t * 0.5
		var freq = 80.0 - t * 20.0
		var drone = sin(t * TAU * freq) * volume * envelope
		var sample = int16(clamp(drone * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_triumphant(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	var freqs = [523.25, 659.25, 783.99, 1046.50, 1318.51]  # Extended C major
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - pow(t - 0.5, 2) * 2.0
		envelope = max(0, envelope)
		var sample_val = 0.0
		for j in range(freqs.size()):
			var f = freqs[j]
			var note_start = float(j) / freqs.size() * 0.3
			var note_env = 0.0
			if t > note_start:
				var note_t = (t - note_start) / 0.7
				note_env = exp(-note_t * 3.0)
			sample_val += sin(t * TAU * f) * volume * note_env * 0.2
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

func _generate_intense(duration: float, volume_db: float) -> PackedByteArray:
	var samples = int(duration * SAMPLE_RATE)
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var volume = db_to_linear(volume_db)
	
	for i in range(samples):
		var t = float(i) / samples
		var envelope = 1.0 - pow(t - 0.3, 2) * 3.0
		envelope = max(0, envelope)
		var noise = (randf() * 2.0 - 1.0) * 0.3
		var sweep = sin(t * TAU * (100.0 + t * 400.0)) * 0.7
		var sample_val = (noise + sweep) * volume * envelope
		var sample = int16(clamp(sample_val * 32767, -32768, 32767))
		data.encode_s16(i * 2, sample)
	
	return data

# ============================================
# WAV FILE WRITER
# ============================================

func _save_wav(path: String, data: PackedByteArray):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create: " + path)
		return
	
	var channels = 1  # Mono
	var byte_rate = SAMPLE_RATE * channels * 2  # 16-bit
	var data_size = data.size()
	var file_size = 36 + data_size
	
	# RIFF header
	file.store_string("RIFF")
	file.store_32(file_size)
	file.store_string("WAVE")
	
	# fmt chunk
	file.store_string("fmt ")
	file.store_32(16)  # Subchunk size
	file.store_16(1)   # Audio format (PCM)
	file.store_16(channels)
	file.store_32(SAMPLE_RATE)
	file.store_32(byte_rate)
	file.store_16(channels * 2)  # Block align
	file.store_16(16)  # Bits per sample
	
	# data chunk
	file.store_string("data")
	file.store_32(data_size)
	file.store_buffer(data)
	
	file.close()
	print("Generated: " + path)
