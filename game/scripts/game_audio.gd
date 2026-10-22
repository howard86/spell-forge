extends Node
## Original synthesized score and cues. Generation happens once, never per cast.

const RATE := 22050
const VOICES := 8
var _clips: Dictionary = {}
var _score: AudioStreamWAV
var _music_player: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _pending_cues: Dictionary = {}
var _master := 0.7
var _music := 0.45
var _sfx := 0.75
var _shutting_down := false
var is_shutdown := false
var _shutdown_clean := true
signal shutdown_finished

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_cache()
    _music_player = AudioStreamPlayer.new()
    _music_player.stream = _score
    add_child(_music_player)
    for i in range(VOICES):
        var voice := AudioStreamPlayer.new()
        add_child(voice)
        _voices.append(voice)
    set_levels(_master, _music, _sfx)
    # A scene may be created and discarded in one update. Delay starting the
    # mixer until deferred scene work has completed, and honor queued teardown.
    call_deferred("_start_music")

func _tearing_down() -> bool:
    var ancestor: Node = self
    while ancestor != null:
        if ancestor.is_queued_for_deletion():
            return true
        ancestor = ancestor.get_parent()
    return not is_inside_tree()

func _start_music() -> void:
    if not _shutting_down and not _tearing_down() and is_instance_valid(_music_player):
        _music_player.play()

func set_levels(master: float, music: float, sfx: float) -> void:
    _master = clampf(master, 0, 1)
    _music = clampf(music, 0, 1)
    _sfx = clampf(sfx, 0, 1)
    if is_instance_valid(_music_player):
        _music_player.volume_linear = _master * _music
    for voice in _voices:
        voice.volume_linear = _master * _sfx

func play_sfx(kind: String) -> void:
    if _shutting_down or not _clips.has(kind) or _voices.is_empty():
        return
    # Combat can emit many hits in one update. Coalesce each cue per frame and
    # never replace an active stream before the audio mixer has consumed it.
    _pending_cues[kind] = true

func _process(_delta: float) -> void:
    if _shutting_down or _pending_cues.is_empty() or _tearing_down():
        return
    for kind in ["victory", "death", "reward", "dodge", "cast", "hit"]:
        if not _pending_cues.has(kind):
            continue
        for voice in _voices:
            if not voice.playing:
                voice.stream = _clips[kind]
                voice.play()
                break
    _pending_cues.clear()

func shutdown() -> bool:
    if is_shutdown:
        return _shutdown_clean
    if _shutting_down:
        await shutdown_finished
        return _shutdown_clean
    _shutting_down = true
    var playbacks: Array[WeakRef] = []
    if is_instance_valid(_music_player) and _music_player.has_stream_playback():
        playbacks.append(weakref(_music_player.get_stream_playback()))
    for voice in _voices:
        if voice.has_stream_playback():
            playbacks.append(weakref(voice.get_stream_playback()))
    _release_audio()
    # Godot 4.4 removes stopped playbacks on the mixer thread, then releases
    # their resources during AudioServer's next main-loop update. Observe the
    # actual weak references instead of assuming a fixed shutdown sleep.
    var deadline := Time.get_ticks_msec() + 500
    while _playbacks_alive(playbacks) and Time.get_ticks_msec() < deadline:
        await get_tree().create_timer(0.005, true).timeout
        await get_tree().process_frame
    _shutdown_clean = not _playbacks_alive(playbacks)
    is_shutdown = true
    shutdown_finished.emit()
    return _shutdown_clean

static func _playbacks_alive(playbacks: Array[WeakRef]) -> bool:
    for playback in playbacks:
        if playback.get_ref() != null:
            return true
    return false

func _exit_tree() -> void:
    _shutting_down = true
    _release_audio()

func _release_audio() -> void:
    _pending_cues.clear()
    if is_instance_valid(_music_player):
        _music_player.stop()
        _music_player.stream = null
    for voice in _voices:
        voice.stop()
        voice.stream = null
    _voices.clear()
    _clips.clear()
    _score = null

static func _wav(data: PackedByteArray, looped: bool = false) -> AudioStreamWAV:
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = RATE
    stream.stereo = false
    stream.data = data
    if looped:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = data.size() / 2
    return stream

func _build_cache() -> void:
    if _score != null:
        return
    for kind in ["cast", "hit", "dodge", "reward", "death", "victory"]:
        _clips[kind] = _make_cue(kind)
    # Eight bars of a quiet original D-minor arpeggio, seamless on a 16-second cycle.
    var notes := PackedFloat32Array([146.832, 220.0, 293.665, 349.228, 130.813, 195.998, 261.626, 329.628, 116.541, 174.614, 233.082, 293.665, 130.813, 195.998, 220.0, 164.814])
    var count := RATE * 16
    var data := PackedByteArray()
    data.resize(count * 2)
    for i in range(count):
        var t := float(i) / RATE
        var step := int(t * 2.0)
        var local := fmod(t, 0.5)
        var note := notes[step % notes.size()]
        var env := minf(local * 70.0, 1.0) * exp(-local * 7.0)
        var tone := (sin(TAU * note * local) + sin(TAU * note * 2 * local) * 0.18) * env * 0.075
        # Integer cycle frequencies ensure the low drone joins without a click.
        var drone := (sin(TAU * 73.4375 * t) + sin(TAU * 110.0 * t) * 0.4) * 0.019
        data.encode_s16(i * 2, int(clampf(tone + drone, -1, 1) * 32767))
    _score = _wav(data, true)

static func _make_cue(kind: String) -> AudioStreamWAV:
    var duration := 0.18
    if kind == "reward":
        duration = 0.65
    elif kind == "victory":
        duration = 1.4
    elif kind == "death":
        duration = 0.8
    var count := int(duration * RATE)
    var data := PackedByteArray()
    data.resize(count * 2)
    var phase := 0.0
    var random := RandomNumberGenerator.new()
    random.seed = 1979
    for i in range(count):
        var t := float(i) / RATE
        var progress := t / duration
        var frequency := 440.0
        var amplitude := 0.19
        var noise := 0.0
        match kind:
            "cast":
                frequency = lerpf(850, 300, progress)
            "hit":
                frequency = lerpf(170, 65, progress)
                noise = random.randf_range(-1, 1) * 0.4
            "dodge":
                frequency = lerpf(180, 650, progress)
                noise = random.randf_range(-1, 1) * 0.15
                amplitude = 0.12
            "reward":
                frequency = 440.0 * pow(2, float(int(progress * 3) * 4) / 12)
            "death":
                frequency = lerpf(260, 45, progress)
            "victory":
                var semitones := 0
                if progress > 0.6:
                    semitones = 12
                elif progress > 0.4:
                    semitones = 7
                elif progress > 0.2:
                    semitones = 4
                frequency = 293.665 * pow(2, float(semitones) / 12)
        phase += TAU * frequency / RATE
        var envelope := minf(t * 150, 1) * pow(1 - progress, 1.5)
        var sample := (sin(phase) + 0.2 * sin(phase * 2) + noise) * envelope * amplitude
        data.encode_s16(i * 2, int(clampf(sample, -1, 1) * 32767))
    return _wav(data)
