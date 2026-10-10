// This WASI target has no C++ exception support. A C++ throw traps instead.
#include <stdlib.h>
void *__cxa_allocate_exception(unsigned long size) { abort(); }
void __cxa_throw(void *object, void *type, void (*destructor)(void *)) { abort(); }
