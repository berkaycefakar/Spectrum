import Foundation

/// Diagnostic logging that compiles away outside Debug builds.
///
/// The service layer prints a fair amount of context when a request fails — including
/// account-deletion and sign-out failures, which name the operation that went wrong. Shipping
/// those to the device console in Release tells anyone with a cable more about a user's
/// session than they need to know, and costs string interpolation on every failure path.
func debugLog(_ items: Any..., separator: String = " ") {
    #if DEBUG
    print(items.map { "\($0)" }.joined(separator: separator))
    #endif
}

#if DEBUG
import Darwin

/// When the process was started, read from the kernel so it includes pre-`main` time.
private let processStart: Date = {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    sysctl(&mib, 4, &info, &size, nil, 0)
    let t = info.kp_proc.p_starttime
    return Date(timeIntervalSince1970: Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000)
}()
#endif

/// Launch timeline: prints seconds since the process started. Debug builds only.
func launchTrace(_ label: @autoclosure () -> String) {
    #if DEBUG
    print(String(format: "[LT] %6.2fs ", Date().timeIntervalSince(processStart)) + label())
    #endif
}
