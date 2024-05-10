#define NAPI_VERSION 6

#include <vector>
#include <string>
#include <functional>
#include "node_api.h"
#include <Foundation/Foundation.h>

#define likely(x)   __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)

namespace napi {
  typedef napi_env env;
  typedef napi_value value;
  std::function<void(napi::env, napi::value)> _init = nil;
  template<typename T> concept PTR = sizeof(T) == sizeof(void*);

  napi::value global(const napi::env env) { napi::value v; napi_get_global(env, &v); return v; }
  napi::value err(const napi::env env, const char *str) { napi_throw_error(env, nil, str); return nil; }
  napi::value err(const napi::env env, const std::string str) { napi_throw_error(env, nil, str.c_str()); return nil; }
  napi::value err(const napi::env env, const NSString *str) { napi_throw_error(env, nil, [str UTF8String]); return nil; }
  napi_valuetype type(const napi::env env, const napi::value value) { napi_valuetype t; napi_typeof(env, value, &t); return t; }
  bool instanceof(const napi::env env, const napi::value object, const napi::value constructor) { bool b; napi_instanceof(env, object, constructor, &b); return b; }
  napi::value klass(const napi::env env, const char *name, const napi_callback constructor, const std::vector<napi_property_descriptor> properties) { napi::value C; napi_define_class(env, name, NAPI_AUTO_LENGTH, constructor, nil, properties.size(), properties.data(), &C); return C; }

  namespace boolean {
    bool to(const napi::env env, const napi::value value) { bool b; napi_get_value_bool(env, value, &b); return b; }
    napi::value from(const napi::env env, const bool value) { napi::value v; napi_get_boolean(env, value, &v); return v; }
  }

  namespace array {
    uint32_t length(const napi::env env, const napi::value array) { uint32_t l; napi_get_array_length(env, array, &l); return l; }
    napi::value get(const napi::env env, const napi::value array, const uint32_t index) { napi::value v; napi_get_element(env, array, index, &v); return v; }
  }

  namespace object {
    napi::value empty(const napi::env env) { napi::value v; napi_create_object(env, &v); return v; }
    void set(const napi::env env, const napi::value object, const napi::value key, const napi::value value) { napi_set_property(env, object, key, value); }
    void set(const napi::env env, const napi::value object, const char* key, const napi::value value) { napi_set_named_property(env, object, key, value); }
    void set(const napi::env env, const napi::value object, const std::string key, const napi::value value) { napi_set_named_property(env, object, key.c_str(), value); }
    void set(const napi::env env, const napi::value object, const NSString *key, const napi::value value) { napi_set_named_property(env, object, key.UTF8String, value); }

    napi::value get(const napi::env env, const napi::value object, const napi::value key) { napi::value v; napi_get_property(env, object, key, &v); return v; }
    napi::value get(const napi::env env, const napi::value object, const char* key) { napi::value v; napi_get_named_property(env, object, key, &v); return v; }
    napi::value get(const napi::env env, const napi::value object, const std::string key) { napi::value v; napi_get_named_property(env, object, key.c_str(), &v); return v; }
    napi::value get(const napi::env env, const napi::value object, const NSString *key) { napi::value v; napi_get_named_property(env, object, key.UTF8String, &v); return v; }

    template<PTR T> using wrap_callback = std::function<void(napi::env, T)>;
    template<PTR T> T unwrap(const napi::env env, const napi::value object) { T p; napi_unwrap(env, object, reinterpret_cast<void**>(&p)); return p; }
    template<PTR T> void wrap(const napi::env env, const napi::value object, T ptr) { napi_wrap(env, object, reinterpret_cast<void*>(ptr), nil, nil, nil); }
    template <PTR T> void wrap_finalizer(const napi::env env, void* ptr, void* function) { auto p = (wrap_callback<T>*)function; (*p)(env, reinterpret_cast<T>(ptr)); delete p; }
    template<PTR T> void wrap(const napi::env env, const napi::value object, T ptr, const wrap_callback<T> finalizer) { napi_wrap(env, object, reinterpret_cast<void*>(ptr), wrap_finalizer<T>, new wrap_callback<T>(finalizer), nil); }
  }

  namespace string {
    napi::value from(const napi::env env, const napi::value value) { napi::value v; napi_coerce_to_string(env, value, &v); return v; }
    napi::value from(const napi::env env, const char *str) { napi::value v; napi_create_string_utf8(env, str, strlen(str), &v); return v; }
    napi::value from(const napi::env env, const NSString *str) { napi::value v; napi_create_string_utf8(env, str.UTF8String, str.length, &v); return v; }
    napi::value from(const napi::env env, const std::string str) { napi::value v; napi_create_string_utf8(env, str.c_str(), str.length(), &v); return v; }

    NSString *to(const napi::env env, napi::value value, const bool coerce = false) {
      if (coerce) napi_coerce_to_string(env, value, &value);

      size_t length;
      napi_get_value_string_utf8(env, value, nil, 0, &length);

      char* c_str = (char*)malloc(length);
      napi_get_value_string_utf8(env, value, c_str, 1 + length, nil);

      return [[NSString alloc]
        initWithBytesNoCopy: c_str length: length
        encoding: NSUTF8StringEncoding freeWhenDone: true
      ];
    }
  }

  namespace function {
    napi::value self(const napi::env env, const napi_callback_info info) { napi::value v; napi_get_cb_info(env, info, nil, nil, &v, nil); return v; }

    std::vector<napi::value> args(const napi::env env, const napi_callback_info info, size_t argc = 0) {
      std::vector<napi::value> args(argc);
      napi_get_cb_info(env, info, &argc, args.data(), nil, nil);

      return args;
    }

    std::vector<napi::value> args(const napi::env env, const napi_callback_info info) {
      size_t argc = 0;
      napi_get_cb_info(env, info, &argc, nil, nil, nil);

      std::vector<napi::value> args(argc);
      napi_get_cb_info(env, info, &argc, args.data(), nil, nil);

      return args;
    }
  }
}