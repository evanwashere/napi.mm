#include <stdexcept>
#define NAPI_VERSION 6

#include <vector>
#include <string>
#include <functional>
#include "node_api.h"
#include <unordered_map>

#ifdef __OBJC__
  #include <Foundation/Foundation.h>
#endif

#define likely(x)   __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)

namespace napi {
  typedef napi_env env;
  typedef napi_value value;
  template<typename T> concept PTR = sizeof(T) == sizeof(void*);

  #ifdef __OBJC__
    napi::value err(const napi::env env, const NSString *str) { napi_throw_error(env, nil, [str UTF8String]); return nil; }
  #endif

  napi::value null(const napi::env env) { napi::value v; napi_get_null(env, &v); return v; }
  napi::value global(const napi::env env) { napi::value v; napi_get_global(env, &v); return v; }
  napi::value undefined(const napi::env env) { napi::value v; napi_get_undefined(env, &v); return v; }
  napi::value err(const napi::env env, const char *str) { napi_throw_error(env, nil, str); return nil; }
  napi::value err(const napi::env env, const std::string str) { napi_throw_error(env, nil, str.c_str()); return nil; }
  napi_valuetype type(const napi::env env, const napi::value value) { napi_valuetype t; napi_typeof(env, value, &t); return t; }
  bool instanceof(const napi::env env, const napi::value object, const napi::value constructor) { bool b; napi_instanceof(env, object, constructor, &b); return b; }
  napi::value klass(const napi::env env, const char *name, const napi_callback constructor, const std::vector<napi_property_descriptor> properties) { napi::value C; napi_define_class(env, name, NAPI_AUTO_LENGTH, constructor, nil, properties.size(), properties.data(), &C); return C; }

  namespace boolean {
    bool to(const napi::env env, const napi::value value) { bool b; napi_get_value_bool(env, value, &b); return b; }
    napi::value from(const napi::env env, const bool value) { napi::value v; napi_get_boolean(env, value, &v); return v; }
  }

  namespace bigint {
    napi::value from(const napi::env env, const int64_t value) { napi::value v; napi_create_bigint_int64(env, value, &v); return v; }
    napi::value from(const napi::env env, const uint64_t value) { napi::value v; napi_create_bigint_uint64(env, value, &v); return v; }
    int64_t to_i64(const napi::env env, const napi::value value) { bool l; int64_t i; napi_get_value_bigint_int64(env, value, &i, &l); return i; }
    uint64_t to_u64(const napi::env env, const napi::value value) { bool l; uint64_t i; napi_get_value_bigint_uint64(env, value, &i, &l); return i; }
  }

  namespace number {
    double to(const napi::env env, const napi::value value) { double d; napi_get_value_double(env, value, &d); return d; }
    napi::value from(const napi::env env, const int64_t value) { napi::value v; napi_create_int64(env, value, &v); return v;}
    napi::value from(const napi::env env, const double value) { napi::value v; napi_create_double(env, value, &v); return v; }
    napi::value from(const napi::env env, const int32_t value) { napi::value v; napi_create_int32(env, value, &v); return v; }
    int32_t to_i32(const napi::env env, const napi::value value) { int32_t i; napi_get_value_int32(env, value, &i); return i; }
    int64_t to_i64(const napi::env env, const napi::value value) { int64_t i; napi_get_value_int64(env, value, &i); return i; }
    napi::value from(const napi::env env, const uint32_t value) { napi::value v; napi_create_uint32(env, value, &v); return v; }
    uint32_t to_u32(const napi::env env, const napi::value value) { uint32_t i; napi_get_value_uint32(env, value, &i); return i; }

    #if __OBJC__
      napi::value from(const napi::env env, const NSInteger value) { return napi::number::from(env, (int64_t)value); }
      napi::value from(const napi::env env, const NSUInteger value) { return napi::number::from(env, (int64_t)value); }
    #endif
  }

  namespace alloc {
    using finalizer_callback = std::function<void(const napi::env, void*)>;

    bool is(const napi::env env, const napi::value value) { bool b; napi_is_arraybuffer(env, value, &b); return b; }
    void* ptr(const napi::env env, const napi::value value) { void *p; size_t l; napi_get_arraybuffer_info(env, value, &p, &l); return p; }
    napi::value zeroed(const napi::env env, const size_t length) { napi::value v; napi_create_arraybuffer(env, length, nil, &v); return v; }
    size_t length(const napi::env env, const napi::value value) { void *p; size_t l; napi_get_arraybuffer_info(env, value, &p, &l); return l; }
    void finalizer_finalizer(napi::env env, void *ptr, void *f) { auto finalizer = (finalizer_callback*)f; (*finalizer)(env, ptr); delete finalizer; }
    napi::value from(const napi::env env, const size_t length, void *ptr) { napi::value v; napi_create_external_arraybuffer(env, ptr, length, nil, nil, &v); return v; }
    napi::value copy(const napi::env env, const size_t length, void *ptr) { napi::value v; void *p; napi_create_arraybuffer(env, length, &p, &v); memcpy(p, ptr, length); return v; }
    napi::value from(const napi::env env, const size_t length, void *ptr, const finalizer_callback finalizer) { napi::value v; auto f = new finalizer_callback(finalizer); napi_create_external_arraybuffer(env, ptr, length, finalizer_finalizer, f, &v); return v; }
  }

  namespace object {
    #ifdef __OBJC__
      void set(const napi::env env, const napi::value object, const NSString *key, const napi::value value) { napi_set_named_property(env, object, key.UTF8String, value); }
      napi::value get(const napi::env env, const napi::value object, const NSString *key) { napi::value v; napi_get_named_property(env, object, key.UTF8String, &v); return v; }
    #endif

    napi::value empty(const napi::env env) { napi::value v; napi_create_object(env, &v); return v; }
    void set(const napi::env env, const napi::value object, const napi::value key, const napi::value value) { napi_set_property(env, object, key, value); }
    void set(const napi::env env, const napi::value object, const char* key, const napi::value value) { napi_set_named_property(env, object, key, value); }
    void set(const napi::env env, const napi::value object, const std::string key, const napi::value value) { napi_set_named_property(env, object, key.c_str(), value); }

    napi::value get(const napi::env env, const napi::value object, const napi::value key) { napi::value v; napi_get_property(env, object, key, &v); return v; }
    napi::value get(const napi::env env, const napi::value object, const char* key) { napi::value v; napi_get_named_property(env, object, key, &v); return v; }
    napi::value get(const napi::env env, const napi::value object, const std::string key) { napi::value v; napi_get_named_property(env, object, key.c_str(), &v); return v; }

    template<PTR T> using wrap_callback = std::function<void(const napi::env, T)>;
    template<PTR T> T unwrap(const napi::env env, const napi::value object) { T p; napi_unwrap(env, object, reinterpret_cast<void**>(&p)); return p; }
    template<PTR T> void wrap(const napi::env env, const napi::value object, T ptr) { napi_wrap(env, object, reinterpret_cast<void*>(ptr), nil, nil, nil); }
    template <PTR T> void wrap_finalizer(const napi::env env, void* ptr, void* function) { auto p = (wrap_callback<T>*)function; (*p)(env, reinterpret_cast<T>(ptr)); delete p; }
    template<PTR T> void wrap(const napi::env env, const napi::value object, T ptr, const wrap_callback<T> finalizer) { napi_wrap(env, object, reinterpret_cast<void*>(ptr), wrap_finalizer<T>, new wrap_callback<T>(finalizer), nil); }

    napi::value from(const napi::env env, const std::unordered_map<std::string, napi::value> properties) {
      napi::value object = napi::object::empty(env);
      for (auto [key, value] : properties) napi::object::set(env, object, key, value);

      return object;
    }
  }

  namespace slice {
    bool is(const napi::env env, const napi::value value) { bool b; napi_is_typedarray(env, value, &b); return b; }
    void* ptr(const napi::env env, const napi::value value) { void *p; napi_get_typedarray_info(env, value, nil, nil, &p, nil, nil); return p; }
    size_t length(const napi::env env, const napi::value value) { size_t l; napi_get_typedarray_info(env, value, nil, &l, nil, nil, nil); return l; }
    napi::value ab(const napi::env env, const napi::value value) { napi::value v; napi_get_typedarray_info(env, value, nil, nil, nil, &v, nil); return v; }
    napi::value i8(const napi::env env, const napi::value ab, const size_t offset, const size_t length) { napi::value v; napi_create_typedarray(env, napi_int8_array, length, ab, offset, &v); return v; }
    napi::value u8(const napi::env env, const napi::value ab, const size_t offset, const size_t length) { napi::value v; napi_create_typedarray(env, napi_uint8_array, length, ab, offset, &v); return v; }
    napi::value i16(const napi::env env, const napi::value ab, const size_t offset, const size_t length) { napi::value v; napi_create_typedarray(env, napi_int16_array, length, ab, offset, &v); return v; }
    napi::value i32(const napi::env env, const napi::value ab, const size_t offset, const size_t length) { napi::value v; napi_create_typedarray(env, napi_int32_array, length, ab, offset, &v); return v; }
    napi::value u16(const napi::env env, const napi::value ab, const size_t offset, const size_t length) { napi::value v; napi_create_typedarray(env, napi_uint16_array, length, ab, offset, &v); return v; }
    napi::value u32(const napi::env env, const napi::value ab, const size_t offset, const size_t length) { napi::value v; napi_create_typedarray(env, napi_uint32_array, length, ab, offset, &v); return v; }
    napi::value f32(const napi::env env, const napi::value ab, const size_t offset, const size_t length) { napi::value v; napi_create_typedarray(env, napi_float32_array, length, ab, offset, &v); return v; }
    napi::value f64(const napi::env env, const napi::value ab, const size_t offset, const size_t length) { napi::value v; napi_create_typedarray(env, napi_float64_array, length, ab, offset, &v); return v; }
    napi::value i64(const napi::env env, const napi::value ab, const size_t offset, const size_t length) { napi::value v; napi_create_typedarray(env, napi_bigint64_array, length, ab, offset, &v); return v; }
    napi::value u64(const napi::env env, const napi::value ab, const size_t offset, const size_t length) { napi::value v; napi_create_typedarray(env, napi_biguint64_array, length, ab, offset, &v); return v; }

    size_t blength(const napi::env env, const napi::value value) {
      size_t l; napi_typedarray_type t;
      napi_get_typedarray_info(env, value, &t, &l, nil, nil, nil);

      if (t == napi_int8_array || t == napi_uint8_array) return l;
      if (t == napi_int16_array || t == napi_uint16_array) return 2 * l;
      if (t == napi_int32_array || t == napi_uint32_array || t == napi_float32_array) return 4 * l;
      if (t == napi_bigint64_array || t == napi_biguint64_array || t == napi_float64_array) return 8 * l;

      __builtin_unreachable();
    }
  }

  namespace string {
    napi::value from(const napi::env env, const napi::value value) { napi::value v; napi_coerce_to_string(env, value, &v); return v; }
    napi::value from(const napi::env env, const char *str) { napi::value v; napi_create_string_utf8(env, str, strlen(str), &v); return v; }
    napi::value from(const napi::env env, const std::string str) { napi::value v; napi_create_string_utf8(env, str.c_str(), str.length(), &v); return v; }

    #ifdef __OBJC__
      napi::value from(const napi::env env, const NSString *str) { napi::value v; napi_create_string_utf8(env, str.UTF8String, str.length, &v); return v; }

      NSString *to(const napi::env env, napi::value value, const bool coerce = false) {
        if (coerce) napi_coerce_to_string(env, value, &value);

        size_t length;
        napi_get_value_string_utf8(env, value, nil, 0, &length);

        char* c_str = (char*)malloc(length);
        napi_get_value_string_utf8(env, value, c_str, 1 + length, nil);

        return [[[NSString alloc]
          initWithBytesNoCopy: c_str length: length
          encoding: NSUTF8StringEncoding freeWhenDone: true
        ] autorelease];
      }
    #endif
  }

  namespace function {
    size_t argc(const napi::env env, const napi_callback_info info) { size_t argc; napi_get_cb_info(env, info, &argc, nil, nil, nil); return argc; }
    napi::value self(const napi::env env, const napi_callback_info info) { napi::value v; napi_get_cb_info(env, info, nil, nil, &v, nil); return v; }
    napi::value from(const napi::env env, const char* name, const napi_callback callback) { napi::value v; napi_create_function(env, name, NAPI_AUTO_LENGTH, callback, nil, &v); return v; }

    std::vector<napi::value> args(const napi::env env, const napi_callback_info info, size_t argc = 0) {
      std::vector<napi::value> args(argc);
      napi_get_cb_info(env, info, &argc, args.data(), nil, nil); return args;
    }

    std::vector<napi::value> args(const napi::env env, const napi_callback_info info) {
      size_t argc = 0;
      napi_get_cb_info(env, info, &argc, nil, nil, nil);

      std::vector<napi::value> args(argc);
      napi_get_cb_info(env, info, &argc, args.data(), nil, nil); return args;
    }
  }

  namespace array {
    using iterator_callback = std::function<void(const napi::env, const uint32_t, const napi::value)>;

    napi::value empty(const napi::env env) { napi::value v; napi_create_array(env, &v); return v; }
    bool is(const napi::env env, const napi::value value) { bool b; napi_is_array(env, value, &b); return b; }
    uint32_t length(const napi::env env, const napi::value array) { uint32_t l; napi_get_array_length(env, array, &l); return l; }
    napi::value zeroed(const napi::env env, const uint32_t length) { napi::value v; napi_create_array_with_length(env, length, &v); return v; }
    void push(const napi::env env, const napi::value array, const napi::value value) { napi_set_element(env, array, length(env, array), value); }
    void set(const napi::env env, const napi::value array, const uint32_t offset, const napi::value value) { napi_set_element(env, array, offset, value); }
    napi::value get(const napi::env env, const napi::value array, const uint32_t offset) { napi::value v; napi_get_element(env, array, offset, &v); return v; }
    void each(const napi::env env, const napi::value array, const iterator_callback callback) { uint32_t length = napi::array::length(env, array); for (uint32_t o = 0; o < length; o++) callback(env, o, napi::array::get(env, array, o)); }

    struct iterator {
      napi::env env;
      uint32_t offset;
      uint32_t length;
      napi::value array;

      iterator begin() { return iterator(env, array); }
      iterator end() { return iterator(env, array, length); }

      iterator(const napi::env env, const napi::value array) : env(env), array(array), offset(0), length(napi::array::length(env, array)) {}
      iterator(const napi::env env, const napi::value array, const uint32_t offset) : env(env), array(array), offset(offset), length(napi::array::length(env, array)) {}

      void operator++() { offset++; }
      napi::value operator*() { return napi::array::get(env, array, offset); }
      bool operator!=(const iterator &other) const { return offset != other.offset; }
    };

    struct enumerate {
      napi::env env;
      uint32_t offset;
      uint32_t length;
      napi::value array;

      enumerate begin() { return enumerate(env, array); }
      enumerate end() { return enumerate(env, array, length); }

      enumerate(const napi::env env, const napi::value array) : env(env), array(array), offset(0), length(napi::array::length(env, array)) {}
      enumerate(const napi::env env, const napi::value array, const uint32_t offset) : env(env), array(array), offset(offset), length(napi::array::length(env, array)) {}

      void operator++() { offset++; }
      bool operator!=(const enumerate &other) const { return offset != other.offset; }
      std::tuple<uint32_t, napi::value> operator*() { return {offset, napi::array::get(env, array, offset)}; }
    };
  }

  namespace async {
    template <PTR T> using finalizer_callback = std::function<napi::value(const napi::env, T)>;
    template <PTR T> using work_callback = std::function<std::variant<T, std::runtime_error>()>;

    template <PTR T> napi::value create(const napi::env env, const char* name, const work_callback<T> work, const finalizer_callback<T> finalizer) {
      auto wp = new work_callback<T>(work);
      auto fp = new finalizer_callback<T>(finalizer);

      struct Refs {
        napi_deferred d;
        napi_async_work h;
        work_callback<T> *w;
        finalizer_callback<T> *f;
        std::variant<T, std::runtime_error> r;
      };

      auto refs = new Refs{.w = wp, .f = fp};

      napi::value p;
      napi_create_promise(env, &refs->d, &p);

      napi_create_async_work(env, nil, napi::string::from(env, name),
        [](auto env, auto ptr) {
          auto p = (Refs*)ptr;
          auto wp = (work_callback<T>*)p->w;

          p->r = (*wp)();
        },

        [](auto env, napi_status _, auto ptr) {
          napi::value err;
          auto p = (Refs*)ptr;
          auto wp = (work_callback<T>*)p->w;
          auto fp = (finalizer_callback<T>*)p->f;

          if (p->r.index() == 1) {
            auto e = std::get<std::runtime_error>(p->r);
            napi_create_error(env, nil, napi::string::from(env, e.what()), &err);

            napi_reject_deferred(env, p->d, err);
          } else {
            auto r = (*fp)(env, std::get<T>(p->r));
            bool e; napi_is_exception_pending(env, &e);
            if (likely(!e)) napi_resolve_deferred(env, p->d, r);
            else { napi_get_and_clear_last_exception(env, &err); napi_reject_deferred(env, p->d, err); }
          }

          napi_delete_async_work(env, p->h); delete p; delete wp; delete fp;
        },
      refs, &refs->h);

      napi_queue_async_work(env, refs->h); return p;
    }
  }
}