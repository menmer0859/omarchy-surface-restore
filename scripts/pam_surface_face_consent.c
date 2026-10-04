#define _GNU_SOURCE
#include <security/pam_appl.h>
#include <security/pam_ext.h>
#include <security/pam_modules.h>
#include <stdlib.h>
#include <string.h>

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc,
                                   const char **argv) {
    (void)flags;
    (void)argc;
    (void)argv;

    char *response = NULL;
    int status = pam_prompt(pamh, PAM_PROMPT_ECHO_ON, &response,
                            "%s", "Use face authentication? [y/N]");
    if (status != PAM_SUCCESS || response == NULL) {
        if (response != NULL) {
            explicit_bzero(response, strlen(response));
            free(response);
        }
        // A missing UI or failed PAM conversation must never start the camera.
        // PAM_IGNORE lets the service stack skip face auth and continue to password.
        return PAM_IGNORE;
    }

    int accepted = (response[0] == 'y' || response[0] == 'Y') && response[1] == '\0';
    explicit_bzero(response, strlen(response));
    free(response);
    return accepted ? PAM_SUCCESS : PAM_IGNORE;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc,
                              const char **argv) {
    (void)pamh;
    (void)flags;
    (void)argc;
    (void)argv;
    return PAM_SUCCESS;
}
