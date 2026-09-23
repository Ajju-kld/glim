import Darwin

#if DEBUG
    extension AppModel {
        /// Suspends the whole Glim process, like a hard freeze: no thread can answer the watchdog.
        /// Press ⌃⌥⌘K and the watchdog must force-quit Glim within half a second (success
        /// criterion 5). Blocking only the main thread would not prove this, because the stop
        /// handshake runs on a background queue. Debug builds only; if ⌃⌥⌘K isn't pressed,
        /// `pkill -x Glim` ends the suspended process.
        func simulateFreezeForWatchdogTest() {
            kill(getpid(), SIGSTOP)
        }
    }
#endif
