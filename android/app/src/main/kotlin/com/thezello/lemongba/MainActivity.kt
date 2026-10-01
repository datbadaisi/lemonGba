package com.thezello.lemongba

import android.content.pm.ActivityInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.Process
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min

/**
 * Hosts a Flutter [Texture] whose [Surface] is handed to libgba_core as an
 * ANativeWindow. Frame presentation is done entirely in native code after
 * each `gba_run_frame()` — no per-frame MethodChannel pixel traffic.
 */
class MainActivity : FlutterActivity() {
    /**
     * Flutter maps landscapeLeft+landscapeRight to USER_LANDSCAPE, which
     * only follows the other landscape side when system auto-rotate is on.
     * SENSOR_LANDSCAPE uses the accelerometer for both 90°/270° even if the
     * user has rotation locked (typical for a landscape-only emulator).
     */
    override fun setRequestedOrientation(requestedOrientation: Int) {
        super.setRequestedOrientation(
            when (requestedOrientation) {
                ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE,
                ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE,
                ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE,
                ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE,
                -> ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                else -> requestedOrientation
            },
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Ensure JNI natives in libgba_core are registered (Dart may dlopen later).
        GbaNative.load()
        GbaVideoHost.attach(flutterEngine)
        GbaAudioHost.attach(flutterEngine)
        GbaSfxHost.attach(flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GbaSfxHost.detach()
        GbaVideoHost.detach()
        GbaAudioHost.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        // Keep the shell SFX stream running while the activity is visible.
        GbaSfxHost.onHostResume()
    }

    override fun onPause() {
        // Stop continuous stream in background (battery). Restarts on resume.
        GbaSfxHost.onHostPause()
        super.onPause()
    }
}

/** JNI entry points implemented in native/bridge/gba_bridge.c */
object GbaNative {
    private var loaded = false

    fun load() {
        if (loaded) return
        System.loadLibrary("gba_core")
        loaded = true
    }

    @JvmStatic
    external fun nativeAttachSurface(surface: Surface?)

    @JvmStatic
    external fun nativeStartAudio(): Boolean

    @JvmStatic
    external fun nativeStopAudio()
}

/** Native low-latency audio uses AAudio on Android 8.0 and newer. */
object GbaAudioHost {
    private const val CHANNEL = "gba_emulator/audio"
    private var channel: MethodChannel? = null

    fun attach(engine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    "start" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                            result.success(false)
                        } else {
                            // Don't fight mGBA AAudio with the shell SFX stream.
                            GbaSfxHost.setSuspended(true)
                            val ok = GbaNative.nativeStartAudio()
                            if (!ok) GbaSfxHost.setSuspended(false)
                            result.success(ok)
                        }
                    }
                    "stop" -> {
                        GbaNative.nativeStopAudio()
                        GbaSfxHost.setSuspended(false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun detach() {
        try { GbaNative.nativeStopAudio() } catch (_: Exception) {}
        GbaSfxHost.setSuspended(false)
        channel?.setMethodCallHandler(null)
        channel = null
    }
}

/**
 * App-shell UI chiptune / SFX — **continuous** mono [AudioTrack] mixer.
 *
 * Why not SoundPool / one-shot AudioTrack?
 * OEM HALs ramp volume and park the output after idle. Logs show the quiet
 * first tap after `VRI … boost timeout` (touch boost ends → path cold). Each
 * SoundPool.play also re-opens tracks → volume churn + stack risk.
 *
 * This engine keeps one MODE_STREAM track writing forever (silence or a single
 * monophonic voice). Play = arm sample cursor (lock-free enough, <1µs). Volume
 * and latency stay flat for rapid home focus changes. Paused in background and
 * while mGBA AAudio is active.
 */
object GbaSfxHost {
    private const val CHANNEL = "gba_emulator/sfx"
    private const val SAMPLE_RATE = 44100
    /** ~5.8ms @ 44.1k — low latency, still friendly to minBuffer sizes. */
    private const val WRITE_FRAMES = 256

    private val ready = AtomicBoolean(false)
    private val running = AtomicBoolean(false)
    private val suspended = AtomicBoolean(false)
    private val wantRunning = AtomicBoolean(false)

    private var channel: MethodChannel? = null
    private var track: AudioTrack? = null
    private var worker: Thread? = null

    private var tapPcm: ShortArray = ShortArray(0)
    private var dockPcm: ShortArray = ShortArray(0)

    /** Monophonic voice: one sample, restarted on each play (no poly stack). */
    private val voice = AtomicReference<Voice?>(null)

    private data class Voice(val pcm: ShortArray, @Volatile var pos: Int = 0)

    fun attach(engine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "preload" -> {
                        ensureSamples()
                        startIfWanted()
                        result.success(ready.get())
                    }
                    "ready" -> result.success(ready.get() && running.get())
                    "warm" -> {
                        // Stream itself is the warm path; ensure it is up.
                        wantRunning.set(true)
                        startIfWanted()
                        result.success(null)
                    }
                    "playDock" -> {
                        trigger(dockPcm)
                        result.success(null)
                    }
                    "playTap" -> {
                        trigger(tapPcm)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        ensureSamples()
        wantRunning.set(true)
        startIfWanted()
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        wantRunning.set(false)
        stopEngine()
    }

    fun onHostResume() {
        wantRunning.set(true)
        startIfWanted()
    }

    fun onHostPause() {
        wantRunning.set(false)
        stopEngine()
    }

    /** Called when mGBA AAudio owns the device (gameplay). */
    fun setSuspended(value: Boolean) {
        suspended.set(value)
        if (value) stopEngine()
        else if (wantRunning.get()) startIfWanted()
    }

    private fun ensureSamples() {
        if (tapPcm.isNotEmpty() && dockPcm.isNotEmpty()) {
            ready.set(true)
            return
        }
        try {
            tapPcm = renderTapChiptune()
            dockPcm = renderDockChiptune()
            ready.set(tapPcm.isNotEmpty() && dockPcm.isNotEmpty())
        } catch (_: Exception) {
            ready.set(false)
        }
    }

    private fun trigger(pcm: ShortArray) {
        if (pcm.isEmpty()) return
        // Arm voice even if stream is mid-start; mixer picks it up next buffer.
        voice.set(Voice(pcm, 0))
        if (!running.get() && wantRunning.get() && !suspended.get()) {
            startIfWanted()
        }
    }

    @Synchronized
    private fun startIfWanted() {
        if (!wantRunning.get() || suspended.get()) return
        if (running.get()) return
        ensureSamples()
        if (!ready.get()) return

        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val format = AudioFormat.Builder()
                .setSampleRate(SAMPLE_RATE)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build()
            val minBuf = AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            if (minBuf <= 0) return
            // At least 2 write chunks so write() rarely blocks long.
            val bufBytes = max(minBuf, WRITE_FRAMES * 2 * 2)

            val builder = AudioTrack.Builder()
                .setAudioAttributes(attrs)
                .setAudioFormat(format)
                .setBufferSizeInBytes(bufBytes)
                .setTransferMode(AudioTrack.MODE_STREAM)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            }
            val t = builder.build()
            if (t.state != AudioTrack.STATE_INITIALIZED) {
                t.release()
                return
            }
            t.play()
            track = t
            running.set(true)

            worker = Thread({
                Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
                audioLoop()
            }, "lemon-sfx-mix").also {
                it.isDaemon = true
                it.start()
            }
        } catch (_: Exception) {
            stopEngine()
        }
    }

    private fun audioLoop() {
        val chunk = ShortArray(WRITE_FRAMES)
        while (running.get()) {
            val t = track
            if (t == null) break

            // Silence by default; overlay at most one monophonic voice.
            java.util.Arrays.fill(chunk, 0.toShort())
            val v = voice.get()
            if (v != null) {
                val pcm = v.pcm
                var pos = v.pos
                var i = 0
                while (i < chunk.size && pos < pcm.size) {
                    chunk[i] = pcm[pos]
                    i++
                    pos++
                }
                if (pos >= pcm.size) {
                    // Finished — clear only if still this voice (no race restart).
                    voice.compareAndSet(v, null)
                } else {
                    v.pos = pos
                }
            }

            try {
                val written = t.write(chunk, 0, chunk.size)
                if (written < 0) {
                    // Underrun / invalid — brief backoff then continue or exit.
                    try {
                        Thread.sleep(2)
                    } catch (_: InterruptedException) {
                        break
                    }
                    if (!running.get()) break
                }
            } catch (_: Exception) {
                break
            }
        }
    }

    @Synchronized
    private fun stopEngine() {
        running.set(false)
        val t = track
        // Unblock a stuck write() before joining the mixer thread.
        if (t != null) {
            try {
                t.pause()
            } catch (_: Exception) {
            }
            try {
                t.flush()
            } catch (_: Exception) {
            }
        }
        val w = worker
        worker = null
        if (w != null) {
            try {
                w.interrupt()
            } catch (_: Exception) {
            }
            try {
                w.join(300)
            } catch (_: Exception) {
            }
        }
        track = null
        if (t != null) {
            try {
                t.stop()
            } catch (_: Exception) {
            }
            try {
                t.release()
            } catch (_: Exception) {
            }
        }
        voice.set(null)
    }

    // ---- synthesizers (44.1 kHz mono s16) ----

    private fun renderTapChiptune(): ShortArray {
        val out = ArrayList<Short>(SAMPLE_RATE / 20)
        softPulseInto(out, 1046.50, 24, 0.34)
        return out.toShortArray()
    }

    private fun renderDockChiptune(): ShortArray {
        val out = ArrayList<Short>(SAMPLE_RATE / 2)
        softPulseInto(out, 392.00, 28, 0.30)
        restInto(out, 4)
        softPulseInto(out, 523.25, 36, 0.36)
        restInto(out, 3)
        softPulseInto(out, 659.25, 42, 0.34)
        restInto(out, 2)
        softPulseInto(out, 783.99, 70, 0.32)
        restInto(out, 16)
        return out.toShortArray()
    }

    private fun restInto(out: ArrayList<Short>, ms: Int) {
        repeat(SAMPLE_RATE * ms / 1000) { out.add(0) }
    }

    private fun softPulseInto(out: ArrayList<Short>, freqHz: Double, ms: Int, peak: Double) {
        val n = SAMPLE_RATE * ms / 1000
        if (n <= 0) return
        val attack = max(1, (n * 0.08).toInt())
        val release = max(1, (n * 0.30).toInt())
        val edge = max(2, (SAMPLE_RATE / freqHz * 0.045).toInt())
        var prev = 0.0
        for (i in 0 until n) {
            val t = i.toDouble() / SAMPLE_RATE
            val phase = (t * freqHz) % 1.0
            val target = if (phase < 0.5) 1.0 else -1.0
            prev += (target - prev) * (1.0 / edge)
            var env = 1.0
            when {
                i < attack -> env = i.toDouble() / attack
                i > n - release -> env = (n - i).toDouble() / release
            }
            env *= exp(-2.5 * i / n)
            val v = (prev * peak * env * 32767.0).toInt()
            out.add(min(32767, max(-32768, v)).toShort())
        }
    }
}

object GbaVideoHost {
    private const val CHANNEL = "gba_emulator/video"

    private var channel: MethodChannel? = null
    private var entry: TextureRegistry.SurfaceTextureEntry? = null
    private var surface: Surface? = null

    fun attach(engine: FlutterEngine) {
        detach()
        GbaNative.load()
        val textures = engine.renderer
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "create" -> {
                        try {
                            val w = call.argument<Int>("width") ?: 240
                            val h = call.argument<Int>("height") ?: 160
                            result.success(createTexture(textures, w, h))
                        } catch (e: Exception) {
                            result.error("create_failed", e.message, null)
                        }
                    }
                    "dispose" -> {
                        release()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun detach() {
        release()
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun createTexture(textures: TextureRegistry, w: Int, h: Int): Map<String, Any> {
        release()
        val width = w.coerceAtLeast(1)
        val height = h.coerceAtLeast(1)

        val e = textures.createSurfaceTexture()
        e.surfaceTexture().setDefaultBufferSize(width, height)
        entry = e

        val s = Surface(e.surfaceTexture())
        surface = s

        // Hand Surface to native → ANativeWindow. Present is then done in C.
        GbaNative.nativeAttachSurface(s)

        return mapOf(
            "textureId" to e.id(),
            "width" to width,
            "height" to height,
        )
    }

    private fun release() {
        try {
            GbaNative.nativeAttachSurface(null)
        } catch (_: Exception) {
        }
        try {
            surface?.release()
        } catch (_: Exception) {
        }
        surface = null
        try {
            entry?.release()
        } catch (_: Exception) {
        }
        entry = null
    }
}
