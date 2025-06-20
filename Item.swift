/*
 Author: Jadon Downs
 Created on: 6-10-25
 Description: Defines the Item model for storing timestamped records using SwiftData in the Spot app.
*/

//
//  Item.swift
//  Spot
//
//  Created by Jadon Downs on 6/11/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

