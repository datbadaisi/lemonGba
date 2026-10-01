/* Internal session + shared audio lock. Not a public Flutter ABI. */
#ifndef GBA_SESSION_INTERNAL_H
#define GBA_SESSION_INTERNAL_H

#include <stdint.h>
#include <stddef.h>

#include <mgba/core/core.h>

#ifdef __ANDROID__
#include <pthread.h>
#endif

/* Do not #define GBA_VIDEO_* — those names are enum values in mGBA headers. */
enum {
  GBA_BRIDGE_DEFAULT_WIDTH = 240,
  GBA_BRIDGE_DEFAULT_HEIGHT = 160,
};

#define MGBA_AUDIO_HZ 32768
#define OUT_AUDIO_HZ 48000
#define BLIP_SAMPLES_PER_FRAME 1024
#define AUDIO_RING_FRAMES 7200

struct GbaSession {
  struct mCore* core;
  color_t* video;
  unsigned width;
  unsigned height;
  int loaded;
  char sav_path[1024];
  float volume;
  int muted;
  int16_t ring[AUDIO_RING_FRAMES * 2];
  int ring_r;
  int ring_w;
  int ring_count;
  int16_t blip_tmp[BLIP_SAMPLES_PER_FRAME * 2];
};

/* Active process session (single-session product). */
struct GbaSession* gba_session_active(void);

void gba_session_audio_lock(void);
void gba_session_audio_unlock(void);

/* Pull interleaved s16 stereo frames for platform audio callbacks. */
int gba_session_pull_audio(int16_t* out_interleaved, int max_stereo_frames);

#endif /* GBA_SESSION_INTERNAL_H */
