/* Flutter FFI bridge for mGBA (core is MPL-2.0). */
#ifndef GBA_BRIDGE_H
#define GBA_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

#ifdef _WIN32
#ifdef GBA_BRIDGE_EXPORTS
#define GBA_API __declspec(dllexport)
#else
#define GBA_API __declspec(dllimport)
#endif
#else
#define GBA_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* GBA button bits — match mGBA GBA_KEY_* order. */
enum GbaKeyBit {
  GBA_KEYBIT_A = 1 << 0,
  GBA_KEYBIT_B = 1 << 1,
  GBA_KEYBIT_SELECT = 1 << 2,
  GBA_KEYBIT_START = 1 << 3,
  GBA_KEYBIT_RIGHT = 1 << 4,
  GBA_KEYBIT_LEFT = 1 << 5,
  GBA_KEYBIT_UP = 1 << 6,
  GBA_KEYBIT_DOWN = 1 << 7,
  GBA_KEYBIT_R = 1 << 8,
  GBA_KEYBIT_L = 1 << 9,
};

/* Opaque emulation session. Platform (EGL/JNI/AAudio) is not part of this. */
typedef struct GbaSession GbaSession;

/* ---- lifecycle ---- */
/* Preferred: explicit session handles. Legacy create/destroy use one process-wide session. */
GBA_API GbaSession* gba_session_create(void);
GBA_API void gba_session_destroy(GbaSession* session);
GBA_API int gba_create(void);   /* legacy: create default session */
GBA_API void gba_destroy(void); /* legacy: destroy default session */
GBA_API int gba_bridge_version(void); /* increments when FFI ABI changes */

/* ---- ROM / save ---- */
/* sav_path may be NULL (no cartridge save). On success opens/creates .sav for writeback. */
GBA_API int gba_load_rom(const char* rom_path);
GBA_API int gba_load_rom_ex(const char* rom_path, const char* sav_path);
GBA_API int gba_flush_save(void);
/* Erase cartridge battery save in memory (0xFF) and write it back. Soft-reset separately. */
GBA_API int gba_wipe_cartridge_save(void);

/* ---- run ---- */
GBA_API void gba_run_frame(void);
GBA_API void gba_run_frames(int n);
GBA_API void gba_reset(void);
GBA_API void gba_set_keys(uint32_t keys);

/* ---- video (240x160, color_t little-endian RGBA when COLOR_16_BIT is off) ---- */
GBA_API int gba_frame_width(void);
GBA_API int gba_frame_height(void);
GBA_API int gba_frame_bytes(void);
GBA_API const uint8_t* gba_frame_buffer(void);
GBA_API int gba_copy_frame(uint8_t* out, int out_len);

/* Android: attach ANativeWindow (pass pointer as int64). Prefer JNI Surface attach.
 * When set, gba_run_frame() presents each frame to the window.
 * Pass 0 to detach. Non-Android builds no-op. */
GBA_API void gba_set_native_window(int64_t window_ptr);
GBA_API int gba_has_native_window(void);
/* Re-blit current framebuffer without advancing emulation (e.g. after load state). */
GBA_API void gba_present_frame(void);

/* ---- audio (stereo s16le interleaved, output rate from gba_audio_sample_rate) ---- */
GBA_API int gba_audio_sample_rate(void);
GBA_API int gba_audio_available(void); /* stereo frames buffered */
GBA_API int gba_audio_read(int16_t* out_interleaved, int max_stereo_frames);
GBA_API void gba_set_volume(float vol01); /* 0..1 */
GBA_API void gba_set_muted(int muted);

/* ---- save states ---- */
GBA_API int gba_state_size(void);
GBA_API int gba_save_state(void* buf, int len);
GBA_API int gba_load_state(const void* buf, int len);

/* ---- info ---- */
GBA_API int gba_is_loaded(void);
GBA_API void gba_game_title(char* out, int out_len);
GBA_API const char* gba_core_version(void);

#ifdef __cplusplus
}
#endif

#endif /* GBA_BRIDGE_H */
