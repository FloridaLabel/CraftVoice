import Foundation
import AppKit
import ApplicationServices
import AVFoundation
import Carbon

// No requests, event posting, clipboard reads/writes, audio recording or model loading.
print("scope=CLI process; these grants do not prove grants for the future signed app")
print("os=\(ProcessInfo.processInfo.operatingSystemVersionString)")
print("ramBytes=\(ProcessInfo.processInfo.physicalMemory)")
print("accessibility=\(AXIsProcessTrusted())")
print("postEvents=\(CGPreflightPostEventAccess())")
print("listenEvents=\(CGPreflightListenEventAccess())")
print("microphoneStatus=\(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)")
print("secureInput=\(IsSecureEventInputEnabled())")
// Compile toggle press/release specifications for repeat suppression, without capturing user keystrokes.
let specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
             EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
print("toggleEventSpecifications=\(specs.count)")
if CommandLine.arguments.contains("--register-hotkey") {
    var ref: EventHotKeyRef?
    let identifier = EventHotKeyID(signature: 0x43525643, id: 1)
    let status = RegisterEventHotKey(UInt32(kVK_F18), UInt32(controlKey | optionKey | cmdKey),
                                    identifier, GetApplicationEventTarget(), 0, &ref)
    print("registerHotKeyStatus=\(status)")
    if let ref { print("unregisterHotKeyStatus=\(UnregisterEventHotKey(ref))") }
    print("physical key delivery was NOT tested")
}
