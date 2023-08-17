/*
 * Copyright 2022 The Yorkie Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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
 * `RHTNode` is a node of RHT(Replicated Hashtable).
 */
struct RHTNode {
    var key: String
    var value: String
    var updatedAt: TimeTicket
}

/**
 * RHT is replicated hash table by creation time.
 * For more details about RHT: @see http://csl.skku.edu/papers/jpdc11.pdf
 */
class RHT {
    private var nodeMapByKey = [String: RHTNode]()

    /**
     * `set` sets the value of the given key.
     */
    func set(key: String, value: String, executedAt: TimeTicket) {
        let previous = self.nodeMapByKey[key]

        if let previous, executedAt.after(previous.updatedAt) == false {
            return
        }

        let node = RHTNode(key: key, value: value, updatedAt: executedAt)
        self.nodeMapByKey[key] = node
    }

    /**
     * `has` returns whether the element exists of the given key or not.
     */
    func has(key: String) -> Bool {
        return self.nodeMapByKey[key] != nil
    }

    /**
     * `get` returns the value of the given key.
     */
    func get(key: String) throws -> String {
        guard let node = self.nodeMapByKey[key] else {
            let log = "can't find the given node with: \(key)"
            Logger.critical(log)
            throw YorkieError.unexpected(message: log)
        }

        return node.value
    }

    /**
     * `deepcopy` copies itself deeply.
     */
    func deepcopy() -> RHT {
        let rht = RHT()
        self.nodeMapByKey.forEach {
            rht.set(key: $1.key, value: $1.value, executedAt: $1.updatedAt)
        }
        return rht
    }

    /**
     * `toJSON` returns the JSON encoding of this hashtable.
     */
    func toJSON() -> String {
        var result = [String]()
        self.nodeMapByKey.forEach { (key: String, node: RHTNode) in
            result.append("\"\(key)\":\"\(node.value.escaped())\"")
        }

        return result.isEmpty ? "" : "{\(result.joined(separator: ","))}"
    }

    /**
     * `toXML` converts the given RHT to XML string.
     */
    public func toXML() -> String {
        if self.nodeMapByKey.isEmpty {
            return ""
        }

        let sortedKeys = self.nodeMapByKey.keys.sorted()

        let xmlAttributes = sortedKeys.compactMap { key in
            if let value = self.nodeMapByKey[key] {
                return "\(key)=\"\(value.value)\""
            } else {
                return nil
            }
        }.joined(separator: " ")

        return " \(xmlAttributes)"
    }

    /**
     * `size` returns the size of RHT
     */
    public var size: Int {
        self.nodeMapByKey.count
    }

    /**
     * `toObject` returns the object of this hashtable.
     */
    func toObject() -> [String: (value: String, updatedAt: TimeTicket)] {
        var result = [String: (String, TimeTicket)]()
        self.nodeMapByKey.forEach { (key: String, node: RHTNode) in
            result[key] = (node.value, node.updatedAt)
        }

        return result
    }
}

extension RHT: Sequence {
    typealias Element = RHTNode

    func makeIterator() -> RHTIterator {
        let nodes = self.nodeMapByKey.map { $1 }
        return RHTIterator(nodes)
    }
}

class RHTIterator: IteratorProtocol {
    private var iteratorNext: Int = 0
    private let nodes: [RHTNode]

    init(_ nodes: [RHTNode]) {
        self.nodes = nodes
    }

    func next() -> RHTNode? {
        defer {
            self.iteratorNext += 1
        }
        guard let node = self.nodes[safe: iteratorNext] else {
            return nil
        }

        return node
    }
}
