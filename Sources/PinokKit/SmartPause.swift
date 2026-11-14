import AppKit
import CoreAudio
import CoreMediaIO
import IOKit.pwr_mgt

/// Почему напоминания сейчас придержаны.
enum BusyReason {
    case call, video

    var title: String {
        switch self {
        case .call: t("you are in a call")
        case .video: t("fullscreen video")
        }
    }
}

/// Определение звонков и полноэкранного видео — без запроса разрешений.
enum SmartPause {

    // MARK: Звонок: кто-то пишет с микрофона или камеры

    /// Какой-либо процесс сейчас записывает звук с микрофона.
    static func isMicInUse() -> Bool {
        let me = getpid()
        for process in audioProcesses() {
            var pid: pid_t = 0
            guard getProperty(process, kAudioProcessPropertyPID, &pid), pid != me else { continue }
            var running: UInt32 = 0
            if getProperty(process, kAudioProcessPropertyIsRunningInput, &running), running != 0 {
                return true
            }
        }
        return false
    }

    /// Какое-либо приложение сейчас использует камеру.
    static func isCameraInUse() -> Bool {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        let system = CMIOObjectID(kCMIOObjectSystemObject)

        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return false }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &addr, 0, nil, size, &used, &devices) == noErr else { return false }

        for device in devices {
            var runAddr = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard))
            var running: UInt32 = 0
            var got: UInt32 = 0
            if CMIOObjectGetPropertyData(device, &runAddr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &got, &running) == noErr,
               running != 0 {
                return true
            }
        }
        return false
    }

    // MARK: Видео: приложение на весь экран + кто-то не даёт экрану погаснуть

    static func isFullscreenVideo() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != getpid(),
              frontmostCoversScreen(pid: front.processIdentifier)
        else { return false }
        return someoneKeepsDisplayAwake()
    }

    private static func frontmostCoversScreen(pid: pid_t) -> Bool {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let screens = NSScreen.screens.map(\.frame.size)
        return info.contains { w in
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (w[kCGWindowLayer as String] as? Int) == 0,
                  let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict)
            else { return false }
            return screens.contains { bounds.width >= $0.width && bounds.height >= $0.height }
        }
    }

    /// Видеоплееры и браузеры во время воспроизведения запрещают экрану гаснуть.
    private static func someoneKeepsDisplayAwake() -> Bool {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
              let byProcess = unmanaged?.takeRetainedValue() as NSDictionary?
        else { return false }

        let me = getpid()
        for (key, value) in byProcess {
            if let pid = key as? NSNumber, pid.int32Value == me { continue }
            guard let assertions = value as? [NSDictionary] else { continue }
            for a in assertions {
                let type = a["AssertType"] as? String
                if type == "PreventUserIdleDisplaySleep" || type == "NoDisplaySleepAssertion" {
                    return true
                }
            }
        }
        return false
    }

    // MARK: CoreAudio helpers

    private static func audioProcesses() -> [AudioObjectID] {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func getProperty<T: BitwiseCopyable>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                                       _ value: inout T) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: selector,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr
    }
}
