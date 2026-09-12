#include <dlfcn.h>
#include <stdio.h>

int main(void)
{
    const char *symbols[] = {
        "importbuffer_fd", "releasebuffer_handle", "wrapbuffer_handle_t",
        "imcopy_t", "improcess"
    };
    void *library = dlopen("librga.so", RTLD_NOW | RTLD_LOCAL);
    if (!library) {
        fprintf(stderr, "Cannot load librga.so: %s\n", dlerror());
        return 1;
    }
    for (unsigned int i = 0; i < sizeof(symbols) / sizeof(symbols[0]); ++i) {
        dlerror();
        dlsym(library, symbols[i]);
        const char *error = dlerror();
        if (error) {
            fprintf(stderr, "Missing librga symbol %s: %s\n", symbols[i], error);
            dlclose(library);
            return 1;
        }
    }
    dlclose(library);
    puts("librga: loaded with all five required compositor symbols");
    return 0;
}
