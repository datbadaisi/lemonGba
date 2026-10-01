/* Android platform: EGL/GLES present, ANativeWindow, AAudio, JNI.
 * Emulation session lives in gba_bridge.c.
 */
#include "gba_platform_android.h"

#ifdef __ANDROID__

#include "gba_session_internal.h"

#include <android/log.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <aaudio/AAudio.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <jni.h>
#include <pthread.h>
#include <string.h>

#define GBA_LOG(...) __android_log_print(ANDROID_LOG_INFO, "gba_platform", __VA_ARGS__)
#define GBA_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "gba_platform", __VA_ARGS__)

static ANativeWindow* g_window = NULL;
static pthread_mutex_t g_window_mu = PTHREAD_MUTEX_INITIALIZER;

static EGLDisplay g_egl_display = EGL_NO_DISPLAY;
static EGLContext g_egl_context = EGL_NO_CONTEXT;
static EGLSurface g_egl_surface = EGL_NO_SURFACE;
static GLuint g_egl_program = 0;
static GLuint g_egl_texture = 0;
static int g_egl_ready = 0;
static int g_egl_disabled = 0;
static int g_egl_tex_allocated = 0;
static unsigned g_present_w = GBA_BRIDGE_DEFAULT_WIDTH;
static unsigned g_present_h = GBA_BRIDGE_DEFAULT_HEIGHT;
static const void* g_present_pixels = NULL;

static AAudioStream* g_audio_stream = NULL;
static pthread_mutex_t g_audio_stream_mu = PTHREAD_MUTEX_INITIALIZER;

static void present_software_to_native_window(void) {
  ANativeWindow* win;
  pthread_mutex_lock(&g_window_mu);
  win = g_window;
  if (win) {
    ANativeWindow_acquire(win);
  }
  pthread_mutex_unlock(&g_window_mu);
  if (!win || !g_present_pixels) {
    if (win) {
      ANativeWindow_release(win);
    }
    return;
  }

  ANativeWindow_Buffer abuf;
  if (ANativeWindow_lock(win, &abuf, NULL) != 0) {
    ANativeWindow_release(win);
    return;
  }

  uint8_t* dstBase = (uint8_t*)abuf.bits;
  const uint8_t* src = (const uint8_t*)g_present_pixels;
  const int w = (int)g_present_w;
  const int h = (int)g_present_h;
  const int dstStridePx = abuf.stride;
  const size_t rowBytes = (size_t)w * 4u;

  if (dstStridePx == w) {
    memcpy(dstBase, src, rowBytes * (size_t)h);
  } else {
    for (int y = 0; y < h; ++y) {
      uint8_t* dst = dstBase + (size_t)y * (size_t)dstStridePx * 4u;
      const uint8_t* row = src + (size_t)y * rowBytes;
      memcpy(dst, row, rowBytes);
    }
  }

  ANativeWindow_unlockAndPost(win);
  ANativeWindow_release(win);
}

static void renderer_destroy_locked(void) {
  if (g_egl_display != EGL_NO_DISPLAY) {
    eglMakeCurrent(g_egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (g_egl_program) glDeleteProgram(g_egl_program);
    if (g_egl_texture) glDeleteTextures(1, &g_egl_texture);
    if (g_egl_surface != EGL_NO_SURFACE) eglDestroySurface(g_egl_display, g_egl_surface);
    if (g_egl_context != EGL_NO_CONTEXT) eglDestroyContext(g_egl_display, g_egl_context);
    eglTerminate(g_egl_display);
  }
  g_egl_display = EGL_NO_DISPLAY;
  g_egl_context = EGL_NO_CONTEXT;
  g_egl_surface = EGL_NO_SURFACE;
  g_egl_program = 0;
  g_egl_texture = 0;
  g_egl_ready = 0;
  g_egl_tex_allocated = 0;
}

static GLuint compile_shader(GLenum type, const char* source) {
  GLuint shader = glCreateShader(type);
  if (!shader) return 0;
  glShaderSource(shader, 1, &source, NULL);
  glCompileShader(shader);
  GLint ok = GL_FALSE;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    glDeleteShader(shader);
    return 0;
  }
  return shader;
}

static int renderer_init_locked(void) {
  if (g_egl_ready) return 1;
  if (g_egl_disabled || !g_window) return 0;
  const EGLint config_attrs[] = {
      EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
      EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
      EGL_NONE};
  const EGLint context_attrs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  EGLConfig config;
  EGLint count = 0;
  g_egl_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  if (g_egl_display == EGL_NO_DISPLAY || !eglInitialize(g_egl_display, NULL, NULL) ||
      !eglChooseConfig(g_egl_display, config_attrs, &config, 1, &count) || count != 1) {
    GBA_LOGE("EGL init/config failed err=0x%x", (unsigned)eglGetError());
    renderer_destroy_locked();
    g_egl_disabled = 1;
    return 0;
  }
  g_egl_context = eglCreateContext(g_egl_display, config, EGL_NO_CONTEXT, context_attrs);
  g_egl_surface = eglCreateWindowSurface(g_egl_display, config, g_window, NULL);
  if (g_egl_context == EGL_NO_CONTEXT || g_egl_surface == EGL_NO_SURFACE ||
      !eglMakeCurrent(g_egl_display, g_egl_surface, g_egl_surface, g_egl_context)) {
    GBA_LOGE("EGL context/surface failed err=0x%x", (unsigned)eglGetError());
    renderer_destroy_locked();
    g_egl_disabled = 1;
    return 0;
  }
  const char* vs =
      "attribute vec2 a; varying vec2 v;"
      "void main(){v=vec2((a.x+1.0)*0.5, 1.0-(a.y+1.0)*0.5); gl_Position=vec4(a,0.0,1.0);}";
  const char* fs =
      "precision mediump float; varying vec2 v; uniform sampler2D t;"
      "void main(){vec4 c=texture2D(t,v); gl_FragColor=vec4(c.rgb,1.0);}";
  GLuint vert = compile_shader(GL_VERTEX_SHADER, vs);
  GLuint frag = compile_shader(GL_FRAGMENT_SHADER, fs);
  if (!vert || !frag) {
    if (vert) glDeleteShader(vert);
    if (frag) glDeleteShader(frag);
    GBA_LOGE("EGL shader compile failed");
    renderer_destroy_locked();
    g_egl_disabled = 1;
    return 0;
  }
  g_egl_program = glCreateProgram();
  glAttachShader(g_egl_program, vert);
  glAttachShader(g_egl_program, frag);
  glBindAttribLocation(g_egl_program, 0, "a");
  glLinkProgram(g_egl_program);
  glDeleteShader(vert);
  glDeleteShader(frag);
  GLint linked = GL_FALSE;
  glGetProgramiv(g_egl_program, GL_LINK_STATUS, &linked);
  if (!linked) {
    GBA_LOGE("EGL program link failed");
    renderer_destroy_locked();
    g_egl_disabled = 1;
    return 0;
  }
  glGenTextures(1, &g_egl_texture);
  glBindTexture(GL_TEXTURE_2D, g_egl_texture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  eglSwapInterval(g_egl_display, 0);
  g_egl_ready = 1;
  g_egl_tex_allocated = 0;
  GBA_LOG("EGL video renderer ready");
  return 1;
}

static int present_egl_locked(void) {
  if (g_egl_disabled || !g_present_pixels) return 0;
  if (!renderer_init_locked()) return 0;
  if (!eglMakeCurrent(g_egl_display, g_egl_surface, g_egl_surface, g_egl_context)) {
    GBA_LOGE("eglMakeCurrent failed err=0x%x", (unsigned)eglGetError());
    renderer_destroy_locked();
    g_egl_disabled = 1;
    return 0;
  }
  EGLint width = 0, height = 0;
  eglQuerySurface(g_egl_display, g_egl_surface, EGL_WIDTH, &width);
  eglQuerySurface(g_egl_display, g_egl_surface, EGL_HEIGHT, &height);
  if (width <= 0 || height <= 0) {
    renderer_destroy_locked();
    return 0;
  }
  static const GLfloat quad[] = {-1.f, -1.f, 1.f, -1.f, -1.f, 1.f, 1.f, 1.f};
  while (glGetError() != GL_NO_ERROR) {
  }
  glViewport(0, 0, width, height);
  glDisable(GL_BLEND);
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_CULL_FACE);
  glUseProgram(g_egl_program);
  glUniform1i(glGetUniformLocation(g_egl_program, "t"), 0);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, g_egl_texture);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
  if (!g_egl_tex_allocated) {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)g_present_w, (GLsizei)g_present_h, 0,
        GL_RGBA, GL_UNSIGNED_BYTE, g_present_pixels);
    g_egl_tex_allocated = 1;
  } else {
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, (GLsizei)g_present_w, (GLsizei)g_present_h,
        GL_RGBA, GL_UNSIGNED_BYTE, g_present_pixels);
  }
  GLenum uploadErr = glGetError();
  if (uploadErr != GL_NO_ERROR) {
    GBA_LOGE("EGL texture upload failed gl=0x%x; using software presenter", (unsigned)uploadErr);
    renderer_destroy_locked();
    g_egl_disabled = 1;
    return 0;
  }
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, quad);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  glDisableVertexAttribArray(0);
  if (!eglSwapBuffers(g_egl_display, g_egl_surface)) {
    GBA_LOGE("eglSwapBuffers failed err=0x%x", (unsigned)eglGetError());
    renderer_destroy_locked();
    g_egl_disabled = 1;
    return 0;
  }
  return 1;
}

void gba_platform_present(const void* pixels, unsigned width, unsigned height) {
  g_present_pixels = pixels;
  g_present_w = width ? width : GBA_BRIDGE_DEFAULT_WIDTH;
  g_present_h = height ? height : GBA_BRIDGE_DEFAULT_HEIGHT;
  pthread_mutex_lock(&g_window_mu);
  int rendered = present_egl_locked();
  pthread_mutex_unlock(&g_window_mu);
  if (!rendered) {
    present_software_to_native_window();
  }
}

static void release_native_window_locked(void) {
  renderer_destroy_locked();
  g_egl_disabled = 0;
  if (g_window) {
    ANativeWindow_release(g_window);
    g_window = NULL;
  }
}

void gba_platform_release_window(void) {
  pthread_mutex_lock(&g_window_mu);
  release_native_window_locked();
  pthread_mutex_unlock(&g_window_mu);
}

void gba_platform_set_native_window(int64_t window_ptr, int width, int height) {
  pthread_mutex_lock(&g_window_mu);
  release_native_window_locked();
  if (window_ptr != 0) {
    g_window = (ANativeWindow*)(uintptr_t)window_ptr;
    if (g_window) {
      ANativeWindow_acquire(g_window);
      const int32_t w = width > 0 ? width : GBA_BRIDGE_DEFAULT_WIDTH;
      const int32_t h = height > 0 ? height : GBA_BRIDGE_DEFAULT_HEIGHT;
      ANativeWindow_setBuffersGeometry(g_window, w, h, WINDOW_FORMAT_RGBA_8888);
      GBA_LOG("native window attached %p %dx%d", (void*)g_window, (int)w, (int)h);
    }
  } else {
    GBA_LOG("native window detached");
  }
  pthread_mutex_unlock(&g_window_mu);
}

int gba_platform_has_native_window(void) {
  pthread_mutex_lock(&g_window_mu);
  int has = g_window != NULL;
  pthread_mutex_unlock(&g_window_mu);
  return has;
}

JNIEXPORT void JNICALL
Java_com_thezello_lemongba_GbaNative_nativeAttachSurface(JNIEnv* env, jclass clazz, jobject surface) {
  (void)clazz;
  pthread_mutex_lock(&g_window_mu);
  release_native_window_locked();
  if (surface) {
    g_window = ANativeWindow_fromSurface(env, surface);
    if (g_window) {
      ANativeWindow_setBuffersGeometry(
          g_window, GBA_BRIDGE_DEFAULT_WIDTH, GBA_BRIDGE_DEFAULT_HEIGHT, WINDOW_FORMAT_RGBA_8888);
      GBA_LOG("Surface attached via JNI %p", (void*)g_window);
    } else {
      GBA_LOGE("ANativeWindow_fromSurface failed");
    }
  } else {
    GBA_LOG("Surface cleared via JNI");
  }
  pthread_mutex_unlock(&g_window_mu);
}

static aaudio_data_callback_result_t audio_callback(
    AAudioStream* stream, void* user_data, void* audio_data, int32_t num_frames) {
  (void)stream;
  (void)user_data;
  int16_t* output = (int16_t*)audio_data;
  int filled = gba_session_pull_audio(output, num_frames);
  if (filled < num_frames) {
    memset(output + filled * 2, 0, (size_t)(num_frames - filled) * 2 * sizeof(int16_t));
  }
  return AAUDIO_CALLBACK_RESULT_CONTINUE;
}

int gba_platform_start_audio(void) {
  pthread_mutex_lock(&g_audio_stream_mu);
  if (g_audio_stream) {
    pthread_mutex_unlock(&g_audio_stream_mu);
    return 1;
  }
  AAudioStreamBuilder* builder = NULL;
  aaudio_result_t result = AAudio_createStreamBuilder(&builder);
  if (result != AAUDIO_OK) goto fail;
  AAudioStreamBuilder_setDirection(builder, AAUDIO_DIRECTION_OUTPUT);
  AAudioStreamBuilder_setPerformanceMode(builder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
  AAudioStreamBuilder_setSharingMode(builder, AAUDIO_SHARING_MODE_EXCLUSIVE);
  AAudioStreamBuilder_setFormat(builder, AAUDIO_FORMAT_PCM_I16);
  AAudioStreamBuilder_setSampleRate(builder, OUT_AUDIO_HZ);
  AAudioStreamBuilder_setChannelCount(builder, 2);
  AAudioStreamBuilder_setDataCallback(builder, audio_callback, NULL);
  result = AAudioStreamBuilder_openStream(builder, &g_audio_stream);
  AAudioStreamBuilder_delete(builder);
  if (result != AAUDIO_OK || !g_audio_stream ||
      AAudioStream_requestStart(g_audio_stream) != AAUDIO_OK) {
    if (g_audio_stream) AAudioStream_close(g_audio_stream);
    g_audio_stream = NULL;
    pthread_mutex_unlock(&g_audio_stream_mu);
    return 0;
  }
  pthread_mutex_unlock(&g_audio_stream_mu);
  GBA_LOG("AAudio output started");
  return 1;
fail:
  if (builder) AAudioStreamBuilder_delete(builder);
  pthread_mutex_unlock(&g_audio_stream_mu);
  return 0;
}

void gba_platform_stop_audio(void) {
  pthread_mutex_lock(&g_audio_stream_mu);
  if (g_audio_stream) {
    AAudioStream_requestStop(g_audio_stream);
    AAudioStream_close(g_audio_stream);
    g_audio_stream = NULL;
  }
  pthread_mutex_unlock(&g_audio_stream_mu);
}

JNIEXPORT jboolean JNICALL
Java_com_thezello_lemongba_GbaNative_nativeStartAudio(JNIEnv* env, jclass clazz) {
  (void)env;
  (void)clazz;
  return gba_platform_start_audio() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_thezello_lemongba_GbaNative_nativeStopAudio(JNIEnv* env, jclass clazz) {
  (void)env;
  (void)clazz;
  gba_platform_stop_audio();
}

#else /* !__ANDROID__ */

/* Host builds link this TU but have no Android platform surface. */
typedef int gba_platform_android_host_stub;

#endif /* __ANDROID__ */
