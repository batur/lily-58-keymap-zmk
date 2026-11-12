// Reads every Battery Level characteristic of the connected Lily58 and reports
// them as JSON, e.g. {"levels":[82,67],"time":1794480000}. The first value is the
// left (central) half, the second the right half.
//
//   lily58-battery [device-name] [output-file]
//
// Without an output file the JSON goes to stdout. macOS only grants Bluetooth
// access to a process that is its own "responsible process", so this runs from a
// LaunchAgent (see install.sh), not from Hammerspoon or a terminal.
import CoreBluetooth
import Foundation

let batteryService = CBUUID(string: "180F")
let batteryLevel = CBUUID(string: "2A19")
let deviceName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Lily58"
let outputPath: String? = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil

final class Reader: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var manager: CBCentralManager!
    var peripheral: CBPeripheral?
    var pending = 0
    var levels: [(Int, Int)] = []  // (characteristic order, level)
    var order: [CBCharacteristic] = []

    func start() { manager = CBCentralManager(delegate: self, queue: nil) }

    func fail(_ message: String) -> Never {
        FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
        exit(1)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            if central.state == .unauthorized { fail("bluetooth permission denied") }
            if central.state == .poweredOff { fail("bluetooth is off") }
            return
        }
        let connected = central.retrieveConnectedPeripherals(withServices: [batteryService])
        guard let p = connected.first(where: { $0.name == deviceName }) else {
            fail("\(deviceName) is not connected")
        }
        peripheral = p
        p.delegate = self
        central.connect(p)
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        p.discoverServices([batteryService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        fail("connect failed: \(error?.localizedDescription ?? "unknown")")
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        let services = (p.services ?? []).filter { $0.uuid == batteryService }
        if services.isEmpty { fail("no battery service") }
        pending = services.count
        for s in services { p.discoverCharacteristics([batteryLevel], for: s) }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] where c.uuid == batteryLevel {
            order.append(c)
            p.readValue(for: c)
        }
        pending -= 1
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        guard let index = order.firstIndex(of: c), let byte = c.value?.first else { return }
        if !levels.contains(where: { $0.0 == index }) { levels.append((index, Int(byte))) }
        if pending == 0 && levels.count == order.count {
            let sorted = levels.sorted { $0.0 < $1.0 }.map { String($0.1) }
            let json = "{\"levels\":[\(sorted.joined(separator: ","))],\"time\":\(Int(Date().timeIntervalSince1970))}\n"
            if let path = outputPath {
                do { try json.write(toFile: path, atomically: true, encoding: .utf8) } catch {
                    fail("cannot write \(path): \(error.localizedDescription)")
                }
            } else {
                print(json, terminator: "")
            }
            exit(0)
        }
    }
}

let reader = Reader()
reader.start()
DispatchQueue.main.asyncAfter(deadline: .now() + 10) { reader.fail("timed out") }
RunLoop.main.run()
