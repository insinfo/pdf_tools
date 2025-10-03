
#define NK_API __declspec(dllexport)   // exporta símbolos na DLL
#include "nuklear.h"

NK_API const char* nk_cmd_text_ptr(const struct nk_command_text* t) {
    return t ? t->string : NULL; // ponteiro pro primeiro byte do flex-array
}

NK_API unsigned long nk_cmd_text_off_string(void) {
    return (unsigned long)offsetof(struct nk_command_text, string);
}

