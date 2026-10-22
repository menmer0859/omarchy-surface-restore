#define _GNU_SOURCE
#include <security/pam_appl.h>
#include <security/pam_ext.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

static const char *test_answer;
static int test_conversation_fails;
static int test_prompt_style;
static char test_prompt_text[256];

int test_pam_prompt(pam_handle_t *pamh, int style, char **response,
                    const char *format, ...) {
    (void)pamh;
    test_prompt_style = style;
    va_list args;
    va_start(args, format);
    const char *message = va_arg(args, const char *);
    va_end(args);
    if (strcmp(format, "%s") != 0 || message == NULL) return PAM_SYSTEM_ERR;
    snprintf(test_prompt_text, sizeof(test_prompt_text), "%s", message);
    if (test_conversation_fails) return PAM_CONV_ERR;
    *response = strdup(test_answer);
    return *response == NULL ? PAM_BUF_ERR : PAM_SUCCESS;
}

#define pam_prompt test_pam_prompt
#include "../scripts/pam_surface_face_consent.c"
#undef pam_prompt

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    test_answer = argv[1];
    test_conversation_fails = atoi(argv[2]);
    int status = pam_sm_authenticate(NULL, 0, 0, NULL);
    printf("AUTH_RESULT=%d\nPROMPT_STYLE=%d\nPROMPT_TEXT=%s\n",
           status, test_prompt_style, test_prompt_text);
    return 0;
}
