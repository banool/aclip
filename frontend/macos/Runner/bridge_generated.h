#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef int64_t DartPort;

typedef bool (*DartPostCObjectFnType)(DartPort port_id, void *message);

typedef struct wire_uint_8_list {
  uint8_t *ptr;
  int32_t len;
} wire_uint_8_list;

typedef struct wire_Options {
  bool no_audio;
  struct wire_uint_8_list *base_url;
  bool no_css;
  struct wire_uint_8_list *charset;
  bool ignore_errors;
  bool no_frames;
  bool no_fonts;
  bool no_images;
  bool isolate;
  bool no_js;
  bool insecure;
  bool no_metadata;
  struct wire_uint_8_list *output;
  bool silent;
  uint64_t timeout;
  struct wire_uint_8_list *user_agent;
  bool no_video;
  struct wire_uint_8_list *target;
  bool no_color;
  bool unwrap_noscript;
} wire_Options;

typedef struct WireSyncReturnStruct {
  uint8_t *ptr;
  int32_t len;
  bool success;
} WireSyncReturnStruct;

void store_dart_post_cobject(DartPostCObjectFnType ptr);

void wire_download_page(int64_t port_, struct wire_Options *options);

void wire_platform(int64_t port_);

void wire_rust_release_mode(int64_t port_);

struct wire_Options *new_box_autoadd_options_0(void);

struct wire_uint_8_list *new_uint_8_list_0(int32_t len);

void free_WireSyncReturnStruct(struct WireSyncReturnStruct val);

static int64_t dummy_method_to_enforce_bundling(void) {
    int64_t dummy_var = 0;
    dummy_var ^= ((int64_t) (void*) wire_download_page);
    dummy_var ^= ((int64_t) (void*) wire_platform);
    dummy_var ^= ((int64_t) (void*) wire_rust_release_mode);
    dummy_var ^= ((int64_t) (void*) new_box_autoadd_options_0);
    dummy_var ^= ((int64_t) (void*) new_uint_8_list_0);
    dummy_var ^= ((int64_t) (void*) free_WireSyncReturnStruct);
    dummy_var ^= ((int64_t) (void*) store_dart_post_cobject);
    return dummy_var;
}