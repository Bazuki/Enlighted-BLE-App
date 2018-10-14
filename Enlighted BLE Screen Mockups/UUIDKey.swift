//
//  UUIDKey.swift
//  Basic Chat
//
//  Created by Trevor Beaton on 12/3/16.
//  Copyright © 2016 Vanguard Logic LLC. All rights reserved.
//

import CoreBluetooth
//Uart Service uuid


let kBLEService_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"

    // battery service UUID
let kBLEBatteryService_UUID = "0x180f"

let kBLE_Characteristic_uuid_Tx = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
let kBLE_Characteristic_uuid_Rx = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
let kBLE_Characteristic_uuid_batteryValue = "2a19";

let MaxCharacters = 20

let BLEService_UUID = CBUUID(string: kBLEService_UUID);
let BLEBatteryService_UUID = CBUUID(string: kBLEBatteryService_UUID);
let BLE_Characteristic_uuid_Tx = CBUUID(string: kBLE_Characteristic_uuid_Tx);    //(Property = Write without response)
let BLE_Characteristic_uuid_Rx = CBUUID(string: kBLE_Characteristic_uuid_Rx);    // (Property = Read/Notify)
    // battery level UUID
let BLE_Characteristic_uuid_batteryValue = CBUUID(string: kBLE_Characteristic_uuid_batteryValue);
