/*
 * Copyright 2023 The Yorkie Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

/**
 * PresenceData key, value dictionary
 * Similar to an Indexable in JS SDK
 */
public typealias PresenceData = [String: Any]

/**
 * `PresenceChangeType` represents the type of presence change.
 */
enum PresenceChangeType {
    case put
    case clear
}

enum PresenceChange {
    case put(presence: PresenceData)
    case clear
}

/**
 * `Presence` represents a proxy for the Presence to be manipulated from the outside.
 */
public class Presence {
    private var changeContext: ChangeContext
    private(set) var presence: PresenceData

    init(changeContext: ChangeContext, presence: PresenceData) {
        self.changeContext = changeContext
        self.presence = presence
    }

    func set(_ presence: PresenceData?) {
        guard let presence else {
            fatalError("presence is not initialized")
        }

        for (key, value) in presence {
            self.presence[key] = value
        }

        let presenceChange = PresenceChange.put(presence: self.presence)
        self.changeContext.presenceChange = presenceChange
    }

    func clear() {
        self.presence = [:]

        let presenceChange = PresenceChange.clear
        self.changeContext.presenceChange = presenceChange
    }
}
