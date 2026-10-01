/* Flutter FFI bridge wrapping mGBA.
 *
 * mGBA is subject to the Mozilla Public License, v. 2.0.
 * https://github.com/mgba-emu/mgba
 */
#include "gba_bridge.h"
#include "gba_session_internal.h"
#include "gba_platform_android.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <mgba/core/core.h>
#include <mgba/core/config.h>
#include <mgba/core/blip_buf.h>
#include <mgba/gba/core.h>
#include <mgba/gba/interface.h>
#include <mgba/internal/gba/gba.h>
#include <mgba/internal/gba/savedata.h>
#include <mgba-util/vfs.h>
#include <mgba/core/version.h>

#ifdef __ANDROID__
#include <android/log.h>
#include <pthread.h>
#define GBA_LOG(...) __android_log_print(ANDROID_LOG_INFO, "gba_bridge", __VA_ARGS__)
#define GBA_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "gba_bridge", __VA_ARGS__)
#else
#include <stdio.h>
#define GBA_LOG(...) fprintf(stderr, "gba_bridge: " __VA_ARGS__), fputc('\n', stderr)
#define GBA_LOGE(...) fprintf(stderr, "gba_bridge ERR: " __VA_ARGS__), fputc('\n', stderr)
#endif

#define BRIDGE_VERSION 5

/* Single active session for the current product. Opaque handles point here. */
static GbaSession g_session_storage;
static GbaSession* g_session = NULL;

/* Field accessors used by the rest of this translation unit after create. */
#define g_core (g_session->core)
#define g_video (g_session->video)
#define g_width (g_session->width)
#define g_height (g_session->height)
#define g_loaded (g_session->loaded)
#define g_sav_path (g_session->sav_path)
#define g_volume (g_session->volume)
#define g_muted (g_session->muted)
#define g_ring (g_session->ring)
#define g_ring_r (g_session->ring_r)
#define g_ring_w (g_session->ring_w)
#define g_ring_count (g_session->ring_count)
#define g_blip_tmp (g_session->blip_tmp)

#ifdef __ANDROID__
static pthread_mutex_t g_audio_mu = PTHREAD_MUTEX_INITIALIZER;
#define AUDIO_LOCK() pthread_mutex_lock(&g_audio_mu)
#define AUDIO_UNLOCK() pthread_mutex_unlock(&g_audio_mu)
#else
#define AUDIO_LOCK() ((void)0)
#define AUDIO_UNLOCK() ((void)0)
#endif

GbaSession* gba_session_active(void) {
  return g_session;
}

void gba_session_audio_lock(void) {
  AUDIO_LOCK();
}

void gba_session_audio_unlock(void) {
  AUDIO_UNLOCK();
}


static void clear_video_alpha(void) {
  if (!g_session || !g_video) {
    return;
  }
  size_t n = (size_t)g_width * (size_t)g_height;
  for (size_t i = 0; i < n; ++i) {
    g_video[i] |= 0xFF000000u;
  }
}

static void ring_clear(void) {
  if (!g_session) {
    return;
  }
  AUDIO_LOCK();
  g_ring_r = g_ring_w = g_ring_count = 0;
  AUDIO_UNLOCK();
}

static void ring_push_frame_unlocked(int16_t l, int16_t r) {
  if (g_ring_count >= AUDIO_RING_FRAMES) {
    /* drop oldest */
    g_ring_r = (g_ring_r + 1) % AUDIO_RING_FRAMES;
    g_ring_count--;
  }
  g_ring[g_ring_w * 2 + 0] = l;
  g_ring[g_ring_w * 2 + 1] = r;
  g_ring_w = (g_ring_w + 1) % AUDIO_RING_FRAMES;
  g_ring_count++;
}


int gba_session_pull_audio(int16_t* out_interleaved, int max_stereo_frames) {
  if (!g_session || !out_interleaved || max_stereo_frames <= 0) {
    return 0;
  }
  AUDIO_LOCK();
  int n = max_stereo_frames;
  if (n > g_ring_count) {
    n = g_ring_count;
  }
  for (int i = 0; i < n; ++i) {
    out_interleaved[i * 2 + 0] = g_ring[g_ring_r * 2 + 0];
    out_interleaved[i * 2 + 1] = g_ring[g_ring_r * 2 + 1];
    g_ring_r = (g_ring_r + 1) % AUDIO_RING_FRAMES;
  }
  g_ring_count -= n;
  AUDIO_UNLOCK();
  return n;
}

static int16_t apply_volume(int32_t s) {
  if (!g_session || g_muted) {
    return 0;
  }
  float v = g_volume;
  if (v <= 0.f) {
    return 0;
  }
  if (v > 1.f) {
    v = 1.f;
  }
  int32_t o = (int32_t)lroundf((float)s * v);
  if (o > 32767) {
    o = 32767;
  }
  if (o < -32768) {
    o = -32768;
  }
  return (int16_t)o;
}

static void setup_audio_rates(void) {
  if (!g_session || !g_core) {
    return;
  }
  /* Match libretro-mgba: GBA clock → 32768 Hz blip output. */
  double clock = (double)g_core->frequency(g_core);
  blip_t* left = g_core->getAudioChannel(g_core, 0);
  blip_t* right = g_core->getAudioChannel(g_core, 1);
  if (left) {
    blip_set_rates(left, clock, MGBA_AUDIO_HZ);
  }
  if (right) {
    blip_set_rates(right, clock, MGBA_AUDIO_HZ);
  }
  g_core->setAudioBufferSize(g_core, BLIP_SAMPLES_PER_FRAME);
}

/* Linear resample MGBA_AUDIO_HZ → OUT_AUDIO_HZ, push to ring. */
static void drain_blip_to_ring(void) {
  if (!g_session || !g_core) {
    return;
  }
  blip_t* left = g_core->getAudioChannel(g_core, 0);
  blip_t* right = g_core->getAudioChannel(g_core, 1);
  if (!left || !right) {
    return;
  }

  AUDIO_LOCK();
  int avail = blip_samples_avail(left);
  while (avail > 0) {
    int n = avail;
    if (n > BLIP_SAMPLES_PER_FRAME) {
      n = BLIP_SAMPLES_PER_FRAME;
    }
    memset(g_blip_tmp, 0, sizeof(g_blip_tmp));
    blip_read_samples(left, g_blip_tmp, n, true);
    blip_read_samples(right, g_blip_tmp + 1, n, true);

    /* resample n frames @ 32768 → out @ 48000 */
    double ratio = (double)OUT_AUDIO_HZ / (double)MGBA_AUDIO_HZ;
    int out_n = (int)lround((double)n * ratio);
    if (out_n < 1) {
      out_n = 1;
    }
    for (int i = 0; i < out_n; ++i) {
      double src = (double)i / ratio;
      int i0 = (int)src;
      int i1 = i0 + 1;
      if (i0 >= n) {
        i0 = n - 1;
      }
      if (i1 >= n) {
        i1 = n - 1;
      }
      double t = src - (double)i0;
      int16_t l0 = g_blip_tmp[i0 * 2 + 0];
      int16_t l1 = g_blip_tmp[i1 * 2 + 0];
      int16_t r0 = g_blip_tmp[i0 * 2 + 1];
      int16_t r1 = g_blip_tmp[i1 * 2 + 1];
      int32_t l = (int32_t)lround((1.0 - t) * (double)l0 + t * (double)l1);
      int32_t r = (int32_t)lround((1.0 - t) * (double)r0 + t * (double)r1);
      ring_push_frame_unlocked(apply_volume(l), apply_volume(r));
    }

    avail = blip_samples_avail(left);
  }
  AUDIO_UNLOCK();
}

int gba_bridge_version(void) {
  return BRIDGE_VERSION;
}

static int session_init_core(void) {
  if (!g_session) {
    return 0;
  }
  if (g_core) {
    return 1;
  }

  g_core = GBACoreCreate();
  if (!g_core) {
    GBA_LOGE("GBACoreCreate failed");
    return 0;
  }

  if (!g_core->init(g_core)) {
    GBA_LOGE("core->init failed");
    g_core->deinit(g_core);
    g_core = NULL;
    return 0;
  }

  mCoreInitConfig(g_core, "flutter");

  g_core->desiredVideoDimensions(g_core, &g_width, &g_height);
  if (g_width == 0 || g_height == 0) {
    g_width = GBA_BRIDGE_DEFAULT_WIDTH;
    g_height = GBA_BRIDGE_DEFAULT_HEIGHT;
  }

  free(g_video);
  g_video = (color_t*)calloc((size_t)g_width * (size_t)g_height, sizeof(color_t));
  if (!g_video) {
    mCoreConfigDeinit(&g_core->config);
    g_core->deinit(g_core);
    g_core = NULL;
    return 0;
  }

  g_core->setVideoBuffer(g_core, g_video, g_width);
  setup_audio_rates();
  ring_clear();
  g_loaded = 0;
  g_sav_path[0] = '\0';
  GBA_LOG("session init ok, video %ux%u", g_width, g_height);
  return 1;
}

static void session_teardown_core(void) {
  if (!g_session) {
    return;
  }
  if (g_loaded) {
    gba_flush_save();
  }
#ifdef __ANDROID__
  gba_platform_stop_audio();
  gba_platform_release_window();
#endif
  if (g_core) {
    mCoreConfigDeinit(&g_core->config);
    g_core->deinit(g_core);
    g_core = NULL;
  }
  free(g_video);
  g_video = NULL;
  g_loaded = 0;
  g_sav_path[0] = '\0';
  ring_clear();
}

GbaSession* gba_session_create(void) {
  if (g_session) {
    return g_session;
  }
  memset(&g_session_storage, 0, sizeof(g_session_storage));
  g_session_storage.width = GBA_BRIDGE_DEFAULT_WIDTH;
  g_session_storage.height = GBA_BRIDGE_DEFAULT_HEIGHT;
  g_session_storage.volume = 1.0f;
  g_session = &g_session_storage;
  if (!session_init_core()) {
    g_session = NULL;
    return NULL;
  }
  return g_session;
}

void gba_session_destroy(GbaSession* session) {
  if (!session || session != g_session) {
    return;
  }
  session_teardown_core();
  g_session = NULL;
}

int gba_create(void) {
  return gba_session_create() != NULL ? 1 : 0;
}

void gba_destroy(void) {
  gba_session_destroy(g_session);
}

static int load_rom_internal(const char* rom_path, const char* sav_path) {
  if (!g_session || !g_core || !rom_path || !rom_path[0]) {
    return 0;
  }

  gba_flush_save();
  g_sav_path[0] = '\0';

  struct VFile* vf = VFileOpen(rom_path, O_RDONLY);
  if (!vf) {
    GBA_LOGE("VFileOpen ROM failed: %s", rom_path);
    return 0;
  }

  if (!g_core->isROM(vf)) {
    GBA_LOGE("not a GBA ROM: %s", rom_path);
    vf->close(vf);
    return 0;
  }

  if (!g_core->loadROM(g_core, vf)) {
    GBA_LOGE("loadROM failed: %s", rom_path);
    vf->close(vf);
    return 0;
  }

  if (sav_path && sav_path[0]) {
    struct VFile* sav = VFileOpen(sav_path, O_CREAT | O_RDWR);
    if (sav) {
      if (!g_core->loadSave(g_core, sav)) {
        GBA_LOGE("loadSave failed (continuing without): %s", sav_path);
        sav->close(sav);
      } else {
        strncpy(g_sav_path, sav_path, sizeof(g_sav_path) - 1);
        g_sav_path[sizeof(g_sav_path) - 1] = '\0';
        GBA_LOG("save attached: %s", g_sav_path);
      }
    } else {
      GBA_LOGE("could not open sav: %s", sav_path);
    }
  }

  setup_audio_rates();
  ring_clear();
  g_core->reset(g_core);
  g_loaded = 1;
  clear_video_alpha();
  GBA_LOG("ROM loaded: %s", rom_path);
  return 1;
}

int gba_load_rom(const char* path) {
  return load_rom_internal(path, NULL);
}

int gba_load_rom_ex(const char* rom_path, const char* sav_path) {
  return load_rom_internal(rom_path, sav_path);
}

int gba_flush_save(void) {
  if (!g_session || !g_core || !g_loaded) {
    return 0;
  }
  if (!g_sav_path[0]) {
    return 1;
  }
  /* Sync mmap/writeback through mGBA's open save VFile. */
  struct GBA* gba = (struct GBA*)g_core->board;
  if (!gba) {
    return 0;
  }
  struct GBASavedata* sd = &gba->memory.savedata;
  if (!sd->vf) {
    return 1;
  }
  size_t size = GBASavedataSize(sd);
  if (!size) {
    return 1;
  }
  if (sd->data) {
    if (!sd->vf->sync(sd->vf, sd->data, size)) {
      GBA_LOGE("flush: vf->sync failed");
      return 0;
    }
  } else if (!sd->vf->sync(sd->vf, NULL, 0)) {
    GBA_LOGE("flush: vf->sync(null) failed");
    return 0;
  }
  GBA_LOG("flush save %zu bytes", size);
  return 1;
}

int gba_wipe_cartridge_save(void) {
  if (!g_session || !g_core || !g_loaded) {
    return 0;
  }
  struct GBA* gba = (struct GBA*)g_core->board;
  if (!gba) {
    return 0;
  }
  struct GBASavedata* sd = &gba->memory.savedata;
  size_t size = GBASavedataSize(sd);
  /* mGBA treats erased cartridge save as 0xFF (flash/SRAM blank). */
  if (sd->data && size > 0) {
    memset(sd->data, 0xFF, size);
    sd->dirty = 1;
    if (g_sav_path[0] && !gba_flush_save()) {
      GBA_LOGE("wipe: flush after erase failed");
      return 0;
    }
    GBA_LOG("wiped cartridge save %zu bytes", size);
    return 1;
  }
  /* No mapped buffer yet — remove on-disk save if we know the path. */
  if (g_sav_path[0]) {
    if (remove(g_sav_path) != 0) {
      GBA_LOG("wipe: no mapped save; remove(%s) skipped/failed", g_sav_path);
    } else {
      GBA_LOG("wipe: removed unmapped save %s", g_sav_path);
    }
  }
  return 1;
}

void gba_run_frame(void) {
  if (!g_session || !g_core || !g_loaded) {
    return;
  }
  g_core->runFrame(g_core);
  clear_video_alpha();
  drain_blip_to_ring();
#ifdef __ANDROID__
  /* Present immediately after the emulated frame — single correct video path. */
  if (g_video) {
    gba_platform_present(g_video, g_width, g_height);
  }
#endif
}

void gba_present_frame(void) {
#ifdef __ANDROID__
  if (!g_session || !g_video) {
    return;
  }
  gba_platform_present(g_video, g_width, g_height);
#else
  /* Desktop/software path presents from Dart. */
#endif
}

void gba_run_frames(int n) {
  if (n < 1) {
    return;
  }
  for (int i = 0; i < n; ++i) {
    gba_run_frame();
  }
}

void gba_reset(void) {
  if (!g_session || !g_core || !g_loaded) {
    return;
  }
  g_core->reset(g_core);
  ring_clear();
}

void gba_set_keys(uint32_t keys) {
  if (!g_session || !g_core) {
    return;
  }
  g_core->setKeys(g_core, keys);
}

int gba_frame_width(void) {
  return g_session ? (int)g_width : GBA_BRIDGE_DEFAULT_WIDTH;
}

int gba_frame_height(void) {
  return g_session ? (int)g_height : GBA_BRIDGE_DEFAULT_HEIGHT;
}

int gba_frame_bytes(void) {
  if (!g_session) {
    return GBA_BRIDGE_DEFAULT_WIDTH * GBA_BRIDGE_DEFAULT_HEIGHT * (int)sizeof(color_t);
  }
  return (int)(g_width * g_height * (unsigned)sizeof(color_t));
}

const uint8_t* gba_frame_buffer(void) {
  return g_session ? (const uint8_t*)g_video : NULL;
}

int gba_copy_frame(uint8_t* out, int out_len) {
  if (!g_session || !out || !g_video) {
    return 0;
  }
  int need = gba_frame_bytes();
  if (out_len < need) {
    return 0;
  }
  memcpy(out, g_video, (size_t)need);
  return need;
}

void gba_set_native_window(int64_t window_ptr) {
#ifdef __ANDROID__
  const int w = g_session ? (int)g_width : GBA_BRIDGE_DEFAULT_WIDTH;
  const int h = g_session ? (int)g_height : GBA_BRIDGE_DEFAULT_HEIGHT;
  gba_platform_set_native_window(window_ptr, w, h);
#else
  (void)window_ptr;
#endif
}

int gba_has_native_window(void) {
#ifdef __ANDROID__
  return gba_platform_has_native_window();
#else
  return 0;
#endif
}

int gba_audio_sample_rate(void) {
  return OUT_AUDIO_HZ;
}

int gba_audio_available(void) {
  if (!g_session) {
    return 0;
  }
  AUDIO_LOCK();
  int available = g_ring_count;
  AUDIO_UNLOCK();
  return available;
}

int gba_audio_read(int16_t* out_interleaved, int max_stereo_frames) {
  if (!g_session || !out_interleaved || max_stereo_frames <= 0) {
    return 0;
  }
  AUDIO_LOCK();
  int n = max_stereo_frames;
  if (n > g_ring_count) {
    n = g_ring_count;
  }
  for (int i = 0; i < n; ++i) {
    out_interleaved[i * 2 + 0] = g_ring[g_ring_r * 2 + 0];
    out_interleaved[i * 2 + 1] = g_ring[g_ring_r * 2 + 1];
    g_ring_r = (g_ring_r + 1) % AUDIO_RING_FRAMES;
  }
  g_ring_count -= n;
  AUDIO_UNLOCK();
  return n;
}

void gba_set_volume(float vol01) {
  if (!g_session) {
    return;
  }
  if (vol01 < 0.f) {
    vol01 = 0.f;
  }
  if (vol01 > 1.f) {
    vol01 = 1.f;
  }
  g_volume = vol01;
}

void gba_set_muted(int muted) {
  if (!g_session) {
    return;
  }
  g_muted = muted ? 1 : 0;
}

int gba_state_size(void) {
  if (!g_session || !g_core || !g_loaded) {
    return 0;
  }
  return (int)g_core->stateSize(g_core);
}

int gba_save_state(void* buf, int len) {
  if (!g_session || !g_core || !g_loaded || !buf) {
    return 0;
  }
  int need = (int)g_core->stateSize(g_core);
  if (len < need) {
    return 0;
  }
  return g_core->saveState(g_core, buf) ? need : 0;
}

int gba_load_state(const void* buf, int len) {
  if (!g_session || !g_core || !g_loaded || !buf) {
    return 0;
  }
  int need = (int)g_core->stateSize(g_core);
  if (len < need) {
    return 0;
  }
  if (!g_core->loadState(g_core, buf)) {
    return 0;
  }
  ring_clear();
  return 1;
}

int gba_is_loaded(void) {
  return g_session != NULL && g_loaded && g_core != NULL;
}

void gba_game_title(char* out, int out_len) {
  if (!out || out_len <= 0) {
    return;
  }
  out[0] = '\0';
  if (!g_session || !g_core || !g_loaded) {
    return;
  }
  char title[16];
  memset(title, 0, sizeof(title));
  g_core->getGameTitle(g_core, title);
  title[12] = '\0';
  for (int i = 11; i >= 0; --i) {
    if (title[i] == ' ' || title[i] == '\0') {
      title[i] = '\0';
    } else {
      break;
    }
  }
  strncpy(out, title, (size_t)out_len - 1);
  out[out_len - 1] = '\0';
}

const char* gba_core_version(void) {
  return projectVersion ? projectVersion : "mGBA";
}
