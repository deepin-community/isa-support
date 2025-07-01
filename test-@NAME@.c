#include <stdbool.h>
#include <sys/resource.h>
#include <signal.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

#include <argp.h>

#include <sys/auxv.h>

/* workarround bug on arm see #1086502*/
#ifdef __arm__
#ifndef HWCAP_CRC32
#include <asm/hwcap.h>
#endif
#endif

#if defined(__x86_64__) || defined(__i386__)
#include <sys/platform/x86.h>
#endif

const char *argp_program_version = "test-@NAME@ version @VERSION@";
static char doc[] = "return success if @NAME@\n"
 "\n"
 "@CDESCRIPTION@";
static struct argp argp = { 0, 0, 0, doc };

#ifdef AT_PLATFORM
/* detect ARM ABI version will be optimized away if not used */
static inline bool need_armv_version(int atleastversion)
{
    int version;
    const char * platform = (const char *)getauxval(AT_PLATFORM);
    if (platform == NULL)
        return false;
    /* at least v5 */
    if (strlen(platform) < strlen("v5"))
        return false;
    if (*(platform++) != 'v')
        return false;

    char *endstr;
    errno = 0;
    version = strtol(platform,&endstr,10);
    if (errno != 0)
        return false;
    if (endstr == platform)
        return false;

    return (version >= atleastversion);

}
#endif

const struct rlimit nocore = { 0, 0 };

/* emulate kill by signal */
void
termination_handler (int signum)
{
    _exit(128+signum);
}

int main(int argc,char **argv)
{
    /* no core */
    (void) setrlimit(RLIMIT_CORE, &nocore);
    /* return instead */
    struct sigaction new_action;
    new_action.sa_handler = termination_handler;
    (void) sigemptyset (&new_action.sa_mask);
    new_action.sa_flags = 0;
    (void) sigaction (SIGILL, &new_action, NULL);
    (void) sigaction (SIGBUS, &new_action, NULL);
    (void) sigaction (SIGSEGV, &new_action, NULL);
    argp_parse (&argp, argc, argv, 0, 0, 0);
    /* now test */
    @TEST@;
    return 0;
}
