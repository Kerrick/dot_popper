// SPDX-FileCopyrightText: 2026 setdef <kerrick@setdef.com>
// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// The Microsoft Store build's store helper: buying Pro with
// Windows.Services.Store. A fused Lota game can't call WinRT, so the game
// starts this small program, shipped beside it in the MSIX as
// dot-popper-store.exe, once for each request (Shell::StoreHelper). A
// process started by a packaged app has the package's identity, which
// StoreContext needs. It takes the same dotpopper-store: URL the phones'
// hosts catch, with file=- to mean its standard output, does that one
// request, and writes each answer there, the whole state each time,
// followed by an empty line:
//
//   answer=7              the number of the request this answers
//   owned=1               whether this player has the add-on
//   state=ready           loading, working, ready, pending, cancelled,
//                         restored, none, failed or unavailable
//   price=$1.99           the Store's own, in the player's currency
//   receipt=microsoft:<token>:<SKU>
//                         while owned, the add-on's in-app offer token
//                         (its product ID in Partner Center) and SKU
//                         Store ID, from the license Windows holds
//
// The Microsoft Store gives an app no signed receipt for an add-on
// (ADR-0010), so "receipt" here is Windows' word, which the game
// can only take, and only down this pipe (Receipt::Microsoft). Licenses
// come from StoreContext.GetAppLicenseAsync, which Windows answers from
// its own license store, so a launch with no internet should still find
// Pro (unverified). The add-on is found by its in-app offer token, which
// must be com.setdef.DotPopper.pro, the product ID every store uses.
//
// Plain C against the WinRT ABI, since the build machines and CI have
// MinGW and no C++/WinRT: interfaces are called by their vtable slots,
// in the order of Windows' metadata (as windows-rs lists them), and
// asynchronous calls are waited on by polling IAsyncInfo.
//
//   dot-popper-store.exe "dotpopper-store://open?n=1&product=com.setdef.DotPopper.pro&file=-"
//   dot-popper-store.exe --check     says it runs, and asks the Store nothing
//
// Build: gcc -O2 -municode -o dot-popper-store.exe dot_popper_store.c -lruntimeobject -lole32
#define WIN32_LEAN_AND_MEAN
#include <fcntl.h>
#include <io.h>
#include <roapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tlhelp32.h>
#include <wchar.h>
#include <windows.h>
#include <winstring.h>

// The longest any request may take, a purchase included, before the
// helper gives up and exits, so none outlives the game for long.
#define LONGEST_MS (15 * 60 * 1000)

typedef struct {
  void **vtbl;
} Obj;

#define SLOT(o, i) (((Obj *)(o))->vtbl[i])
typedef HRESULT(WINAPI *QueryFn)(void *, const GUID *, void **);
typedef ULONG(WINAPI *RefFn)(void *);
typedef HRESULT(WINAPI *GetFn)(void *, void **);
typedef HRESULT(WINAPI *GetBoolFn)(void *, boolean *);
typedef HRESULT(WINAPI *GetIntFn)(void *, int *);
typedef HRESULT(WINAPI *Get1Fn)(void *, void *, void **);
typedef HRESULT(WINAPI *InitWindowFn)(void *, HWND);

static void release(void *o) {
  if (o) ((RefFn)SLOT(o, 2))(o);
}

static HRESULT query(void *o, const GUID *iid, void **out) { return ((QueryFn)SLOT(o, 0))(o, iid, out); }

// IUnknown 0-2, IInspectable 3-5; each interface's own from 6.
enum {
  CONTEXT_STATICS_GET_DEFAULT = 6,
  CONTEXT_GET_APP_LICENSE = 11,
  CONTEXT_GET_ASSOCIATED_PRODUCTS = 14,
  CONTEXT_REQUEST_PURCHASE = 21,
  APP_LICENSE_ADD_ONS = 11,
  LICENSE_SKU_STORE_ID = 6,
  LICENSE_IS_ACTIVE = 7,
  LICENSE_IN_APP_OFFER_TOKEN = 10,
  QUERY_RESULT_PRODUCTS = 6,
  PRODUCT_STORE_ID = 6,
  PRODUCT_PRICE = 17,
  PRODUCT_IN_APP_OFFER_TOKEN = 23,
  PRICE_FORMATTED = 7,
  PURCHASE_RESULT_STATUS = 6,
  ASYNC_INFO_STATUS = 7,
  ASYNC_GET_RESULTS = 8,
  ITERABLE_FIRST = 6,
  ITERATOR_CURRENT = 6,
  ITERATOR_HAS_CURRENT = 7,
  ITERATOR_MOVE_NEXT = 8,
  PAIR_VALUE = 7,
};

static const GUID IID_IUnknown_ = {0x00000000, 0x0000, 0x0000, {0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46}};
static const GUID IID_IInspectable_ = {0xaf86e2e0, 0xb12d, 0x4c6a, {0x9c, 0x5a, 0xd7, 0xaa, 0x65, 0x10, 0x1e, 0x90}};
static const GUID IID_IAgileObject_ = {0x94ea2b94, 0xe9cc, 0x49e0, {0xc0, 0xff, 0xee, 0x64, 0xca, 0x8f, 0x5b, 0x90}};
static const GUID IID_IAsyncInfo_ = {0x00000036, 0x0000, 0x0000, {0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46}};
static const GUID IID_IInitializeWithWindow_ = {0x3e68d4bd, 0x7135, 0x4d10, {0x80, 0x18, 0x9f, 0xb6, 0xd9, 0xf3, 0x3f, 0xa1}};
static const GUID IID_IStoreContextStatics_ = {0x9c06ee5f, 0x15c0, 0x4e72, {0x93, 0x30, 0xd6, 0x19, 0x1c, 0xeb, 0xd1, 0x9c}};
// Parameterized interfaces' IIDs, worked out by WinRT's rule (SHA-1 of the
// type's signature in its namespace); the rule gives IIterable<String> and
// IIterator<String> their published IIDs.
static const GUID IID_IIterable_String = {0xe2fcc7c1, 0x3bfc, 0x5a0b, {0xb2, 0xb0, 0x72, 0xe7, 0x69, 0xd1, 0xcb, 0x7e}};
static const GUID IID_IIterator_String = {0x8c304ebb, 0x6615, 0x50a4, {0x88, 0x29, 0x87, 0x9e, 0xcd, 0x44, 0x32, 0x36}};
static const GUID IID_IIterable_Pair_String_StoreLicense = {
    0xca8ba445, 0x6f4d, 0x5da9, {0x95, 0xee, 0x42, 0xcf, 0x11, 0x8d, 0xef, 0x63}};
static const GUID IID_IIterable_Pair_String_StoreProduct = {
    0x78a33722, 0xabfb, 0x57c0, {0x85, 0x3f, 0x56, 0x16, 0xa3, 0xab, 0x8d, 0x57}};

// What one request has learned, as the game is told it.
typedef struct {
  int number;
  int owned;
  const char *state;
  char price[64];
  char receipt[256];
} Answer;

static void write_answer(const Answer *a) {
  printf("answer=%d\nowned=%d\nstate=%s\nprice=%s\n", a->number, a->owned, a->state, a->price);
  if (a->owned) printf("receipt=microsoft:%s\n", a->receipt);
  printf("\n");
  fflush(stdout);
}

static void utf8(HSTRING text, char *out, int size) {
  UINT32 length = 0;
  const wchar_t *raw = WindowsGetStringRawBuffer(text, &length);
  int n = WideCharToMultiByte(CP_UTF8, 0, raw, (int)length, out, size - 1, NULL, NULL);
  out[n > 0 ? n : 0] = 0;
  for (char *c = out; *c; c++)
    if (*c == '\n' || *c == '\r') *c = ' ';
}

// Gets a string property (slot +slot+ of +o+) as UTF-8.
static int string_of(void *o, int slot, char *out, int size) {
  HSTRING text = NULL;
  out[0] = 0;
  if (FAILED(((GetFn)SLOT(o, slot))(o, (void **)&text))) return 0;
  utf8(text, out, size);
  WindowsDeleteString(text);
  return 1;
}

// Waits for an IAsyncOperation and takes its result: NULL if it failed,
// was cancelled, or ran out of time.
static void *await(void *operation) {
  void *info = NULL;
  void *result = NULL;
  int status = 0;
  if (!operation || FAILED(query(operation, &IID_IAsyncInfo_, &info))) return NULL;
  for (DWORD waited = 0; waited < LONGEST_MS; waited += 10) {
    if (FAILED(((GetIntFn)SLOT(info, ASYNC_INFO_STATUS))(info, &status)) || status != 0) break;
    Sleep(10);
  }
  if (status == 1) ((GetFn)SLOT(operation, ASYNC_GET_RESULTS))(operation, &result);
  release(info);
  return result;
}

// A one-item IIterable<String>, which GetAssociatedStoreProductsAsync
// takes for the kinds of product to list. WinRT has no plain list of
// strings to make, so this is one.
typedef struct {
  void **vtbl;
  LONG refs;
  HSTRING item;
  int done;
} Strings;

static HRESULT WINAPI strings_query(Strings *self, const GUID *iid, void **out);
static ULONG WINAPI strings_add(Strings *self) { return InterlockedIncrement(&self->refs); }
static ULONG WINAPI strings_release(Strings *self) {
  LONG left = InterlockedDecrement(&self->refs);
  if (!left) {
    WindowsDeleteString(self->item);
    free(self);
  }
  return left;
}
static HRESULT WINAPI strings_iids(Strings *self, ULONG *count, GUID **iids) {
  (void)self;
  *count = 0;
  *iids = NULL;
  return S_OK;
}
static HRESULT WINAPI strings_name(Strings *self, HSTRING *name) {
  (void)self;
  *name = NULL;
  return S_OK;
}
static HRESULT WINAPI strings_trust(Strings *self, int *level) {
  (void)self;
  *level = 0;
  return S_OK;
}
static Strings *strings_new(void **vtbl, HSTRING item);
static void *iterator_vtbl[10];
static HRESULT WINAPI iterable_first(Strings *self, void **out) {
  *out = strings_new(iterator_vtbl, self->item);
  return *out ? S_OK : E_OUTOFMEMORY;
}
static HRESULT WINAPI iterator_current(Strings *self, HSTRING *out) {
  if (self->done) return E_BOUNDS;
  return WindowsDuplicateString(self->item, out);
}
static HRESULT WINAPI iterator_has_current(Strings *self, boolean *out) {
  *out = !self->done;
  return S_OK;
}
static HRESULT WINAPI iterator_move_next(Strings *self, boolean *out) {
  self->done = 1;
  *out = 0;
  return S_OK;
}
static HRESULT WINAPI iterator_get_many(Strings *self, UINT32 capacity, HSTRING *items, UINT32 *count) {
  *count = 0;
  if (!self->done && capacity > 0 && SUCCEEDED(WindowsDuplicateString(self->item, &items[0]))) {
    *count = 1;
    self->done = 1;
  }
  return S_OK;
}

static void *iterable_vtbl[] = {strings_query, strings_add, strings_release, strings_iids, strings_name, strings_trust, iterable_first};
static void *iterator_vtbl[] = {strings_query,    strings_add,          strings_release,    strings_iids,      strings_name,
                                strings_trust,    iterator_current,     iterator_has_current, iterator_move_next, iterator_get_many};

static HRESULT WINAPI strings_query(Strings *self, const GUID *iid, void **out) {
  const GUID *own = self->vtbl == iterable_vtbl ? &IID_IIterable_String : &IID_IIterator_String;
  if (IsEqualGUID(iid, own) || IsEqualGUID(iid, &IID_IUnknown_) || IsEqualGUID(iid, &IID_IInspectable_) ||
      IsEqualGUID(iid, &IID_IAgileObject_)) {
    *out = self;
    strings_add(self);
    return S_OK;
  }
  *out = NULL;
  return E_NOINTERFACE;
}

static Strings *strings_new(void **vtbl, HSTRING item) {
  Strings *s = calloc(1, sizeof(Strings));
  if (!s) return NULL;
  s->vtbl = vtbl;
  s->refs = 1;
  // Each list and iterator keeps its own copy, since WinRT may hold one
  // after the caller lets go.
  if (FAILED(WindowsDuplicateString(item, &s->item))) {
    free(s);
    return NULL;
  }
  return s;
}

// Calls +each+ with every value of an IMapView<String, T>, through the
// IIterable of its pairs (+iid+), until it answers nonzero.
static void *each_value(void *map, const GUID *iid, int (*each)(void *value, void *context), void *context) {
  void *iterable = NULL, *iterator = NULL, *found = NULL;
  boolean more = 0;
  if (!map || FAILED(query(map, iid, &iterable))) return NULL;
  if (SUCCEEDED(((GetFn)SLOT(iterable, ITERABLE_FIRST))(iterable, &iterator))) {
    ((GetBoolFn)SLOT(iterator, ITERATOR_HAS_CURRENT))(iterator, &more);
    while (more && !found) {
      void *pair = NULL, *value = NULL;
      if (SUCCEEDED(((GetFn)SLOT(iterator, ITERATOR_CURRENT))(iterator, &pair)) &&
          SUCCEEDED(((GetFn)SLOT(pair, PAIR_VALUE))(pair, &value))) {
        if (each(value, context))
          found = value;
        else
          release(value);
      }
      release(pair);
      if (FAILED(((GetBoolFn)SLOT(iterator, ITERATOR_MOVE_NEXT))(iterator, &more))) break;
    }
  }
  release(iterator);
  release(iterable);
  return found;
}

static const char *product_id;

// Whether a StoreLicense or StoreProduct (its token at +slot+) is Pro.
static int is_pro(void *o, int slot) {
  char token[128];
  return string_of(o, slot, token, sizeof token) && strcmp(token, product_id) == 0;
}

static int is_pro_license(void *license, void *context) {
  boolean active = 0;
  (void)context;
  return is_pro(license, LICENSE_IN_APP_OFFER_TOKEN) &&
         SUCCEEDED(((GetBoolFn)SLOT(license, LICENSE_IS_ACTIVE))(license, &active)) && active;
}

static int is_pro_product(void *product, void *context) {
  (void)context;
  return is_pro(product, PRODUCT_IN_APP_OFFER_TOKEN);
}

// Reads the license Windows holds for Pro into +a+.
static void refresh_owned(void *context, Answer *a) {
  void *operation = NULL, *app = NULL, *licenses = NULL, *license = NULL;
  a->owned = 0;
  a->receipt[0] = 0;
  if (SUCCEEDED(((GetFn)SLOT(context, CONTEXT_GET_APP_LICENSE))(context, &operation))) app = await(operation);
  if (app && SUCCEEDED(((GetFn)SLOT(app, APP_LICENSE_ADD_ONS))(app, &licenses)))
    license = each_value(licenses, &IID_IIterable_Pair_String_StoreLicense, is_pro_license, NULL);
  if (license) {
    char sku[64];
    string_of(license, LICENSE_SKU_STORE_ID, sku, sizeof sku);
    snprintf(a->receipt, sizeof a->receipt, "%s:%s", product_id, sku);
    a->owned = 1;
  }
  release(license);
  release(licenses);
  release(app);
  release(operation);
}

// Finds Pro among the app's durable add-ons, and its price.
static void *find_product(void *context, Answer *a) {
  void *operation = NULL, *result = NULL, *products = NULL, *product = NULL, *price = NULL;
  HSTRING durable = NULL;
  Strings *kinds = NULL;
  if (FAILED(WindowsCreateString(L"Durable", 7, &durable)) || !(kinds = strings_new(iterable_vtbl, durable))) goto done;
  if (SUCCEEDED(((Get1Fn)SLOT(context, CONTEXT_GET_ASSOCIATED_PRODUCTS))(context, kinds, &operation))) result = await(operation);
  if (result && SUCCEEDED(((GetFn)SLOT(result, QUERY_RESULT_PRODUCTS))(result, &products)))
    product = each_value(products, &IID_IIterable_Pair_String_StoreProduct, is_pro_product, NULL);
  if (product && SUCCEEDED(((GetFn)SLOT(product, PRODUCT_PRICE))(product, &price)))
    string_of(price, PRICE_FORMATTED, a->price, sizeof a->price);
done:
  release(price);
  release(products);
  release(result);
  release(operation);
  if (kinds) strings_release(kinds);
  WindowsDeleteString(durable);
  return product;
}

// The game's window, which the Store's purchase dialog must belong to:
// the parent process's visible top-level window, or else whatever is in
// front, which is the game the moment Buy is pressed.
static DWORD parent_pid;
static HWND parent_window;

static BOOL CALLBACK window_of_parent(HWND window, LPARAM unused) {
  DWORD pid = 0;
  (void)unused;
  GetWindowThreadProcessId(window, &pid);
  if (pid == parent_pid && IsWindowVisible(window) && !GetWindow(window, GW_OWNER)) {
    parent_window = window;
    return FALSE;
  }
  return TRUE;
}

static HWND game_window(void) {
  PROCESSENTRY32W entry = {.dwSize = sizeof entry};
  DWORD self = GetCurrentProcessId();
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot != INVALID_HANDLE_VALUE) {
    for (BOOL more = Process32FirstW(snapshot, &entry); more; more = Process32NextW(snapshot, &entry))
      if (entry.th32ProcessID == self) parent_pid = entry.th32ParentProcessID;
    CloseHandle(snapshot);
  }
  if (parent_pid) EnumWindows(window_of_parent, 0);
  return parent_window ? parent_window : GetForegroundWindow();
}

static void buy(void *context, Answer *a) {
  void *product = find_product(context, a), *operation = NULL, *result = NULL;
  HSTRING store_id = NULL;
  int status = -1;
  if (!product || FAILED(((GetFn)SLOT(product, PRODUCT_STORE_ID))(product, (void **)&store_id))) {
    a->state = "failed";
    goto done;
  }
  if (SUCCEEDED(((Get1Fn)SLOT(context, CONTEXT_REQUEST_PURCHASE))(context, store_id, &operation))) result = await(operation);
  if (result) ((GetIntFn)SLOT(result, PURCHASE_RESULT_STATUS))(result, &status);
  // StorePurchaseStatus: Succeeded, AlreadyPurchased, NotPurchased,
  // NetworkError, ServerError.
  refresh_owned(context, a);
  if (status == 0 || status == 1)
    a->state = a->owned ? "ready" : "failed";
  else if (status == 2)
    a->state = "cancelled";
  else
    a->state = "failed";
done:
  WindowsDeleteString(store_id);
  release(result);
  release(operation);
  release(product);
}

// Takes the value of +name+ from the URL's query, percent-decoded.
static int query_value(const char *url, const char *name, char *out, size_t size) {
  size_t length = strlen(name);
  const char *at = strchr(url, '?');
  while (at) {
    at++;
    if (!strncmp(at, name, length) && at[length] == '=') {
      size_t n = 0;
      for (const char *c = at + length + 1; *c && *c != '&' && n + 1 < size; c++) {
        unsigned value;
        if (*c == '%' && c[1] && c[2] && sscanf(c + 1, "%2x", &value) == 1) {
          out[n++] = (char)value;
          c += 2;
        } else {
          out[n++] = *c;
        }
      }
      out[n] = 0;
      return 1;
    }
    at = strchr(at, '&');
  }
  return 0;
}

// Parses a dotpopper-store: URL into its action, product and number.
static int parse(const char *url, char *action, size_t action_size, char *product, size_t product_size, int *number) {
  const char *scheme = "dotpopper-store://";
  char file[8], n[16];
  size_t length = 0;
  if (_strnicmp(url, scheme, strlen(scheme))) return 0;
  url += strlen(scheme);
  while (url[length] && url[length] != '?' && url[length] != '/' && length + 1 < action_size) length++;
  memcpy(action, url, length);
  action[length] = 0;
  if (!query_value(url, "product", product, product_size) || !query_value(url, "n", n, sizeof n) ||
      !query_value(url, "file", file, sizeof file) || strcmp(file, "-"))
    return 0;
  *number = atoi(n);
  return length > 0;
}

// Checks what can be checked with no Store: the URL parser and the
// one-item list WinRT is handed. Prints what it found.
static int self_test(void) {
  char action[16], product[128];
  int number = 0, ok = 1;
  HSTRING item = NULL, got = NULL;
  ok &= parse("dotpopper-store://buy?n=12&product=com.setdef.DotPopper.pro&file=-", action, sizeof action, product,
              sizeof product, &number) &&
        !strcmp(action, "buy") && !strcmp(product, "com.setdef.DotPopper.pro") && number == 12;
  ok &= !parse("dotpopper-store://buy?n=1&product=x&file=%2Fsave%2Fanswer.txt", action, sizeof action, product,
               sizeof product, &number);
  ok &= !parse("https://buy?n=1&product=x&file=-", action, sizeof action, product, sizeof product, &number);
  WindowsCreateString(L"Durable", 7, &item);
  Strings *kinds = strings_new(iterable_vtbl, item);
  void *iterable = NULL, *iterator = NULL;
  boolean has = 0;
  ok &= SUCCEEDED(query(kinds, &IID_IIterable_String, &iterable)) &&
        SUCCEEDED(((GetFn)SLOT(iterable, ITERABLE_FIRST))(iterable, &iterator)) &&
        SUCCEEDED(((GetBoolFn)SLOT(iterator, ITERATOR_HAS_CURRENT))(iterator, &has)) && has &&
        SUCCEEDED(((GetFn)SLOT(iterator, ITERATOR_CURRENT))(iterator, (void **)&got));
  char text[16] = "";
  if (got) utf8(got, text, sizeof text);
  ok &= !strcmp(text, "Durable");
  ok &= SUCCEEDED(((GetBoolFn)SLOT(iterator, ITERATOR_MOVE_NEXT))(iterator, &has)) && !has;
  ok &= query(kinds, &IID_IAsyncInfo_, &(void *){NULL}) == E_NOINTERFACE;
  WindowsDeleteString(got);
  release(iterator);
  release(iterable);
  strings_release(kinds);
  WindowsDeleteString(item);
  puts(ok ? "dot-popper-store self-test passed" : "dot-popper-store self-test FAILED");
  return ok ? 0 : 1;
}

static DWORD WINAPI give_up(LPVOID unused) {
  (void)unused;
  Sleep(LONGEST_MS);
  ExitProcess(0);
}

int wmain(int argc, wchar_t **argv) {
  char url[2048], action[16], product[128];
  Answer a = {.state = "loading"};
  void *statics = NULL, *context = NULL, *window_init = NULL;
  HSTRING name = NULL;
  const wchar_t *class_name = L"Windows.Services.Store.StoreContext";

  _setmode(_fileno(stdout), _O_BINARY);
  if (argc == 2 && !wcscmp(argv[1], L"--check")) {
    puts("dot-popper-store runs");
    return 0;
  }
  if (argc == 2 && !wcscmp(argv[1], L"--self-test")) return self_test();
  if (argc != 2 || !WideCharToMultiByte(CP_UTF8, 0, argv[1], -1, url, sizeof url, NULL, NULL) ||
      !parse(url, action, sizeof action, product, sizeof product, &a.number)) {
    fputs("usage: dot-popper-store \"dotpopper-store://ACTION?n=N&product=ID&file=-\"\n", stderr);
    return 64;
  }
  product_id = product;
  CreateThread(NULL, 0, give_up, NULL, 0, NULL);

  a.state = strcmp(action, "open") ? "working" : "loading";
  write_answer(&a);
  if (FAILED(RoInitialize(RO_INIT_MULTITHREADED)) ||
      FAILED(WindowsCreateString(class_name, (UINT32)wcslen(class_name), &name)) ||
      FAILED(RoGetActivationFactory(name, &IID_IStoreContextStatics_, &statics)) ||
      FAILED(((GetFn)SLOT(statics, CONTEXT_STATICS_GET_DEFAULT))(statics, &context))) {
    a.state = "unavailable";
    write_answer(&a);
    return 0;
  }
  // A desktop app must name the window the Store's dialogs belong to.
  if (SUCCEEDED(query(context, &IID_IInitializeWithWindow_, &window_init))) {
    ((InitWindowFn)SLOT(window_init, 3))(window_init, game_window());
    release(window_init);
  }

  if (!strcmp(action, "open")) {
    refresh_owned(context, &a);
    write_answer(&a);
    void *found = find_product(context, &a);
    a.state = found ? "ready" : "unavailable";
    release(found);
  } else if (!strcmp(action, "buy")) {
    refresh_owned(context, &a);
    buy(context, &a);
  } else if (!strcmp(action, "restore")) {
    // Windows keeps the user's licenses itself; there is nothing to
    // restore but to read them again.
    refresh_owned(context, &a);
    a.state = a.owned ? "restored" : "none";
  } else {
    a.state = "failed";
  }
  write_answer(&a);
  release(context);
  release(statics);
  WindowsDeleteString(name);
  return 0;
}
