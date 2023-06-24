#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
typedef struct _Dart_Handle* Dart_Handle;

typedef struct DartCObject DartCObject;

typedef int64_t DartPort;

typedef bool (*DartPostCObjectFnType)(DartPort port_id, void *message);

typedef struct wire_uint_8_list {
  uint8_t *ptr;
  int32_t len;
} wire_uint_8_list;

typedef struct wire_StringList {
  struct wire_uint_8_list **ptr;
  int32_t len;
} wire_StringList;

typedef struct wire_Options {
  bool no_audio;
  struct wire_uint_8_list *base_url;
  bool blacklist_domains;
  bool no_css;
  struct wire_uint_8_list *charset;
  struct wire_StringList *domains;
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

typedef struct DartCObject *WireSyncReturn;

void store_dart_post_cobject(DartPostCObjectFnType ptr);

Dart_Handle get_dart_object(uintptr_t ptr);

void drop_dart_object(uintptr_t ptr);

uintptr_t new_dart_opaque(Dart_Handle handle);

intptr_t init_frb_dart_api_dl(void *obj);

void wire_download_page(int64_t port_, struct wire_Options *options);

void wire_platform(int64_t port_);

void wire_rust_release_mode(int64_t port_);

struct wire_StringList *new_StringList_0(int32_t len);

struct wire_Options *new_box_autoadd_options_0(void);

struct wire_uint_8_list *new_uint_8_list_0(int32_t len);

void free_WireSyncReturn(WireSyncReturn ptr);

static int64_t dummy_method_to_enforce_bundling(void) {
    int64_t dummy_var = 0;
    dummy_var ^= ((int64_t) (void*) wire_download_page);
    dummy_var ^= ((int64_t) (void*) wire_platform);
    dummy_var ^= ((int64_t) (void*) wire_rust_release_mode);
    dummy_var ^= ((int64_t) (void*) new_StringList_0);
    dummy_var ^= ((int64_t) (void*) new_box_autoadd_options_0);
    dummy_var ^= ((int64_t) (void*) new_uint_8_list_0);
    dummy_var ^= ((int64_t) (void*) free_WireSyncReturn);
    dummy_var ^= ((int64_t) (void*) store_dart_post_cobject);
    dummy_var ^= ((int64_t) (void*) get_dart_object);
    dummy_var ^= ((int64_t) (void*) drop_dart_object);
    dummy_var ^= ((int64_t) (void*) new_dart_opaque);
    return dummy_var;
}
