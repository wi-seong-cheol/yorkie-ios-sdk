/*
 * Copyright 2022 The Yorkie Authors. All rights reserved.
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
 * `TimeTicket` is a timestamp of the logical clock. Ticket is immutable.
 * It is created by `ChangeID`.
 */
public struct TimeTicket: Comparable {
    enum Values {
        static let initialDelimiter: UInt32 = 0
        static let maxDelemiter: UInt32 = .max
        static let maxLamport: Int64 = .max
    }

    public static let initial = TimeTicket(lamport: 0, delimiter: Values.initialDelimiter, actorID: ActorIDs.initial)
    static let max = TimeTicket(lamport: Values.maxLamport, delimiter: Values.maxDelemiter, actorID: ActorIDs.max)

    /**
     * `lamport` returns the lamport int64.
     */
    public let lamport: Int64

    /**
     * `delimiter` returns delimiter.
     */
    public let delimiter: UInt32

    /**
     * `actorID` returns actorID.
     */
    private(set) var actorID: ActorID?

    init(lamport: Int64, delimiter: UInt32, actorID: ActorID?) {
        self.lamport = lamport
        self.delimiter = delimiter
        self.actorID = actorID
    }

    /**
     * `toIDString` returns the lamport string for this Ticket.
     */
    private func toIDString() -> String {
        guard let actorID = self.actorID else {
            return "\(self.lamport):nil:\(self.delimiter)"
        }
        return "\(self.lamport):\(actorID):\(self.delimiter)"
    }

    /**
     * `structureAsString` returns a string containing the meta data of the ticket
     * for debugging purpose.
     */
    var structureAsString: String {
        guard let actorID = self.actorID else {
            return "\(self.lamport):nil:\(self.delimiter)"
        }

        // If aactorID is digit display last two charactors.
        let formatedActorID: String

        if actorID.count >= 2, CharacterSet(charactersIn: actorID).isSubset(of: .decimalDigits) {
            formatedActorID = actorID.substring(from: actorID.count - 2, to: actorID.count - 1)
        } else {
            formatedActorID = actorID
        }

        return "\(self.lamport):\(formatedActorID):\(self.delimiter)"
    }

    /**
     * `setActor` changes actorID
     */
    mutating func setActor(_ actorID: ActorID) {
        self.actorID = actorID
    }

    /**
     * `lamportAsString` returns the lamport string.
     */
    var lamportAsString: String {
        "\(self.lamport)"
    }

    /**
     * `after` returns whether the given ticket was created later.
     */
    func after(_ other: TimeTicket) -> Bool {
        self > other
    }

    public static func < (lhs: TimeTicket, rhs: TimeTicket) -> Bool {
        if lhs.lamport != rhs.lamport {
            return lhs.lamport < rhs.lamport
        }

        if let lhsActorID = lhs.actorID, let rhsActorID = rhs.actorID, lhsActorID.localizedCompare(rhsActorID) != .orderedSame {
            return lhsActorID.localizedCompare(rhsActorID) == .orderedAscending
        }

        return lhs.delimiter < rhs.delimiter
    }
}

extension TimeTicket: Hashable {
    public static func == (lhs: TimeTicket, rhs: TimeTicket) -> Bool {
        return lhs.toIDString() == rhs.toIDString()
    }
}

extension TimeTicket: CustomStringConvertible {
    public var description: String {
        self.toIDString()
    }
}
