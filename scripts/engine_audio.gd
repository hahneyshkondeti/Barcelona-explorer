class_name EngineAudio
extends AudioStreamPlayer

var car: TouringCar
var phase := 0.0
var playback: AudioStreamGeneratorPlayback
var muted := false

func _ready() -> void:
	# Headless tests have no speaker; avoid allocating a generator on the dummy driver.
	if DisplayServer.get_name() == "headless":
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.12
	stream = generator
	volume_db = -25
	play()
	playback = get_stream_playback()

func _process(_delta: float) -> void:
	if playback == null or car == null:
		return
	var frequency := 42 + absf(car.speed) * 3.2
	var amplitude := 0.0 if muted or car.paused else 0.2 + absf(car.speed) * 0.012
	for i in playback.get_frames_available():
		phase = fmod(phase + frequency / 22050.0, 1.0)
		var sample := (sin(phase * TAU) + 0.25 * sin(phase * TAU * 2)) * amplitude
		playback.push_frame(Vector2(sample, sample))

func _exit_tree() -> void:
	stop()
	playback = null
