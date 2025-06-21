//
//  BLEManager.swift
//  BLETransfer
//
//  Created by Ángel González on 20/06/25.
//

import CoreBluetooth
import SwiftUI

class BLEManager: NSObject, ObservableObject {
    // UUIDs
    private let serviceUUID = CBUUID(string: "1234")
    private let characteristicUUID = CBUUID(string: "ABCD")

    // Peripheral
    private var peripheralManager: CBPeripheralManager?
    private var characteristic: CBMutableCharacteristic?
    private var dataToSend: Data?
    private var sendIndex = 0

    // Central
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var receivedData = Data()

    @Published var receivedImage: UIImage?

    // MARK: - Peripheral Mode
    func startPeripheral() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    private func setupPeripheral() {
        characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )

        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic!]

        peripheralManager?.add(service)
        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
        ])
    }

    private func loadImage() -> Data? {
        guard let image = UIImage(systemName: "photo") else { return nil }
        return image.pngData()
    }

    private func sendNextChunk() {
        guard let peripheral = peripheralManager,
              let characteristic = characteristic,
              let data = dataToSend else { return }

        if sendIndex >= data.count {
            return // Done
        }

        let chunk = data.subdata(in: sendIndex..<min(sendIndex + 20, data.count))
        let success = peripheral.updateValue(chunk, for: characteristic, onSubscribedCentrals: nil)

        if success {
            sendIndex += chunk.count
            sendNextChunk()
        } else {
            // Wait until system calls `peripheralManagerIsReady`
        }
    }
}

// MARK: - Peripheral Delegate
extension BLEManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            setupPeripheral()
            if let data = loadImage() {
                self.dataToSend = data
                self.sendIndex = 0
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        sendNextChunk()
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendNextChunk()
    }
}

// MARK: - Central
extension BLEManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func startCentral() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager?.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager?.stopScan()
        centralManager?.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first else { return }
        peripheral.discoverCharacteristics([characteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first else { return }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let chunk = characteristic.value {
            receivedData.append(chunk)
            
            // TODO: - Aquí podrías usar un "marcador de fin" o simplemente un tamaño máximo estimado
            if receivedData.count > 5000 {
                receivedImage = UIImage(data: receivedData)
                receivedData = Data()
            }
        }
    }
}
