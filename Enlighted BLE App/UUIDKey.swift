//
//  UUIDKey.swift
//  Basic Chat
//
//  Created by Trevor Beaton on 12/3/16.
//  Copyright © 2016 Vanguard Logic LLC. All rights reserved.
//

import CoreBluetooth

// UUIDs as strings
    // nRF8001 ("old") Uart Service UUID
let nRF8001_Service_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"

let nRF8001_Tx_Characteristic_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
let nRF8001_Rx_Characteristic_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

    // nRF51822 ("new") Uart Service UUID (from spec)
let nRF51822_Service_UUID = "ae49e03e-26a9-11ea-978f-2e728ce88125"

let nRF51822_Tx_Characteristic_UUID = "30b2335a-26aa-11ea-978f-2e728ce88125"
let nRF51822_Rx_Characteristic_UUID = "3564de8e-26aa-11ea-978f-2e728ce88125"

    // battery service UUID
let kBLEBatteryService_UUID = "0x180f"

let kBLE_Characteristic_uuid_batteryValue = "2a19";

let MaxCharacters = 20

// UUIDs converted to usable CBUUIDS

    // nRF8001
let nRF8001_BLEService_UUID = CBUUID(string: nRF8001_Service_UUID);

let nRF8001_Tx_BLECharacteristic_UUID = CBUUID(string: nRF8001_Tx_Characteristic_UUID);
let nRF8001_Rx_BLECharacteristic_UUID = CBUUID(string: nRF8001_Rx_Characteristic_UUID);

    // nRF51822
let nRF51822_BLEService_UUID = CBUUID(string: nRF51822_Service_UUID);

let nRF51822_Tx_BLECharacteristic_UUID = CBUUID(string: nRF51822_Tx_Characteristic_UUID);
let nRF51822_Rx_BLECharacteristic_UUID = CBUUID(string: nRF51822_Rx_Characteristic_UUID);


let BLE_Characteristic_uuid_batteryValue = CBUUID(string: kBLE_Characteristic_uuid_batteryValue);

let BLEBatteryService_UUID = CBUUID(string: kBLEBatteryService_UUID);
