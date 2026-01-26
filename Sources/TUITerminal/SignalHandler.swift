// TUITerminal - Signal Handling

import Darwin
import Foundation
import TUICore

/// Signal handling for terminal events
public enum SignalHandler {
    /// Registered resize handler
    nonisolated(unsafe) private static var resizeHandler: ((Size) -> Void)?

    /// Registered interrupt handler
    nonisolated(unsafe) private static var interruptHandler: (() -> Void)?

    /// Lock for thread safety
    private static let lock = NSLock()

    /// Register a handler for terminal resize events (SIGWINCH)
    /// - Parameter handler: Closure called with new terminal size
    public static func onResize(_ handler: @escaping (Size) -> Void) {
        lock.lock()
        resizeHandler = handler
        lock.unlock()

        // Set up the signal handler
        signal(SIGWINCH) { _ in
            SignalHandler.lock.lock()
            let handler = SignalHandler.resizeHandler
            SignalHandler.lock.unlock()

            if let handler = handler {
                let size = TerminalSize.current()
                handler(size)
            }
        }
    }

    /// Register a handler for interrupt signal (SIGINT, Ctrl+C)
    /// - Parameter handler: Closure called on interrupt
    public static func onInterrupt(_ handler: @escaping () -> Void) {
        lock.lock()
        interruptHandler = handler
        lock.unlock()

        // Set up the signal handler
        signal(SIGINT) { _ in
            SignalHandler.lock.lock()
            let handler = SignalHandler.interruptHandler
            SignalHandler.lock.unlock()

            handler?()
        }
    }

    /// Remove the resize handler
    public static func removeResizeHandler() {
        lock.lock()
        resizeHandler = nil
        lock.unlock()

        signal(SIGWINCH, SIG_DFL)
    }

    /// Remove the interrupt handler
    public static func removeInterruptHandler() {
        lock.lock()
        interruptHandler = nil
        lock.unlock()

        signal(SIGINT, SIG_DFL)
    }

    /// Remove all handlers and restore default signal behavior
    public static func removeAllHandlers() {
        removeResizeHandler()
        removeInterruptHandler()
    }
}
