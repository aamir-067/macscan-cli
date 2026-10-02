/* macscan-helper: starts the mac-triage engine as a child process so macOS
   attributes file access to this binary, which you add to Full Disk Access. */
#include <errno.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static pid_t child = -1;
static void forward(int sig) { if (child > 0) kill(-child, sig); }

int main(int argc, char *argv[]) {
    /* Only root (launchd) may use this binary's Full Disk Access. */
    if (getuid() != 0 || geteuid() != 0) {
        fprintf(stderr, "macscan-helper: must be started by launchd as root\n");
        return 1;
    }
    char **args = calloc((size_t)argc + 2, sizeof(char *));
    if (!args) return 1;
    args[0] = "/bin/bash";
    args[1] = "/usr/local/mac-triage/core/run.sh";
    for (int i = 1; i < argc; i++) args[i + 1] = argv[i];
    args[argc + 1] = NULL;
    char *env[] = { "PATH=/usr/bin:/bin:/usr/sbin:/sbin", "LANG=en_US.UTF-8", NULL };
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP);
    posix_spawnattr_setpgroup(&attr, 0);
    signal(SIGTERM, forward); signal(SIGINT, forward); signal(SIGHUP, forward);
    int rc = posix_spawn(&child, "/bin/bash", NULL, &attr, args, env);
    posix_spawnattr_destroy(&attr);
    if (rc != 0) { fprintf(stderr, "macscan-helper: spawn failed (%d)\n", rc); return 127; }
    int status = 0;
    while (waitpid(child, &status, 0) < 0) { if (errno != EINTR) return 1; }
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
