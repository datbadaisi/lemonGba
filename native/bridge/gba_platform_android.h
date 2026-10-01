/* Android platform presenter + AAudio. Session core stays in gba_bridge.c. */
#ifndef GBA_PLATFORM_ANDROID_H
#define GBA_PLATFORM_ANDROID_H

#include <stdint.h>

#ifdef __ANDROID__

void gba_platform_present(const void* pixels, unsigned width, unsigned height);
void gba_platform_set_native_window(int64_t window_ptr, int width, int height);
int gba_platform_has_native_window(void);
void gba_platform_release_window(void);
int gba_platform_start_audio(void);
void gba_platform_stop_audio(void);

#endif /* __ANDROID__ */

#endif /* GBA_PLATFORM_ANDROID_H */
