#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>
#include <fcntl.h>

/*
 * anti-sigill.so: Universal automatic SIGILL self-healing preload for v4 builds.
 *
 * When compiling x86-64-v4 packages on runners lacking AVX-512 hardware,
 * host build-time generators or tests will trigger SIGILL upon hitting AVX-512 instructions.
 *
 * This preload installs a SIGILL handler that intercepts the crash, reads the process's
 * command line from /proc/self/cmdline, and transparently re-executes the binary
 * under an emulator (Intel SDE or QEMU user).
 *
 * In normal operation (99.99% of commands), this handler has ZERO overhead
 * and does not intercept execve or modify compiler flags.
 */

static void sigill_recovery_handler(int sig, siginfo_t *si, void *vcontext) {
    (void)sig; (void)si; (void)vcontext;

    // Prevent recursive loop if the process fails under emulation as well
    if (getenv("_ANTI_SIGILL_EMULATING")) {
        _exit(132);
    }
    setenv("_ANTI_SIGILL_EMULATING", "1", 1);

    char exe[512];
    ssize_t len = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
    if (len <= 0) {
        _exit(132);
    }
    exe[len] = '\0';

    int fd = open("/proc/self/cmdline", O_RDONLY);
    if (fd < 0) {
        _exit(132);
    }

    char cmdline[16384];
    ssize_t n = read(fd, cmdline, sizeof(cmdline) - 1);
    close(fd);
    if (n <= 0) {
        _exit(132);
    }

    char *argv_ptrs[1024];
    int argc = 0;
    ssize_t pos = 0;
    while (pos < n && argc < 1000) {
        argv_ptrs[argc++] = &cmdline[pos];
        pos += strlen(&cmdline[pos]) + 1;
    }
    argv_ptrs[argc] = NULL;

    const char *emu = NULL;
    if (access("/usr/bin/intel-sde", X_OK) == 0) {
        emu = "/usr/bin/intel-sde";
    } else if (access("/usr/bin/qemu-x86_64", X_OK) == 0) {
        emu = "/usr/bin/qemu-x86_64";
    }

    if (!emu) {
        char err[160];
        int elen = snprintf(err, sizeof(err),
            ":: [anti-sigill] SIGILL intercepted in '%s', but neither intel-sde nor qemu-x86_64 is available.\n",
            exe);
        write(2, err, elen);
        _exit(132);
    }

    char *new_argv[1028];
    new_argv[0] = (char *)emu;
    if (strstr(emu, "intel-sde")) {
        new_argv[1] = "-future";
        new_argv[2] = "--";
        for (int i = 0; i < argc; i++) {
            new_argv[3 + i] = argv_ptrs[i];
        }
        new_argv[3 + argc] = NULL;
    } else {
        new_argv[1] = "-cpu";
        new_argv[2] = "SapphireRapids";
        for (int i = 0; i < argc; i++) {
            new_argv[3 + i] = argv_ptrs[i];
        }
        new_argv[3 + argc] = NULL;
    }

    char log[600];
    int l_len = snprintf(log, sizeof(log),
        ":: [anti-sigill] Intercepted AVX-512 SIGILL in '%s'. Re-executing via %s...\n",
        exe, emu);
    write(2, log, l_len);

    // Disable LD_PRELOAD inside the emulator process itself
    unsetenv("LD_PRELOAD");

    execv(new_argv[0], new_argv);
    _exit(132);
}

__attribute__((constructor))
static void init_anti_sigill(void) {
    if (getenv("_ANTI_SIGILL_EMULATING")) {
        return;
    }

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = sigill_recovery_handler;
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGILL, &sa, NULL);
}
