/*
 * Copyright 2023 The Yorkie Authors. All rights reserved.
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

import Combine
import Foundation

public typealias TextAttributes = Codable

/**
 * `stringifyAttributes` makes values of attributes to JSON parsable string.
 */
func stringifyAttributes(_ attributes: TextAttributes) -> [String: String] {
    guard let jsonData = try? JSONEncoder().encode(attributes),
          let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .fragmentsAllowed) as? [String: Any]
    else {
        return [:]
    }

    return jsonObject.mapValues {
        if let result = try? JSONSerialization.data(withJSONObject: $0, options: .fragmentsAllowed) {
            return String(data: result, encoding: .utf8) ?? ""
        } else {
            return ""
        }
    }
}

class TextChange {
    /**
     * `TextChangeType` is the type of TextChange.
     */
    public enum TextChangeType {
        case content
        case selection
        case style
    }

    public let type: TextChangeType
    public let actor: ActorID
    public let from: Int
    public let to: Int
    public var content: String?
    public var attributes: TextAttributes?

    init(type: TextChangeType, actor: ActorID, from: Int, to: Int, content: String? = nil, attributes: TextAttributes? = nil) {
        self.type = type
        self.actor = actor
        self.from = from
        self.to = to
        self.content = content
        self.attributes = attributes
    }
}

/**
 * `TextValue` is a value of Text
 * which has a attributes that expresses the text style.
 */
public final class TextValue: RGATreeSplitValue, CustomStringConvertible {
    required convenience init() {
        self.init("", RHT())
    }

    private var attributes: RHT
    /**
     * `content` returns content.
     */
    private(set) var content: NSString

    init(_ content: String, _ attributes: RHT = RHT()) {
        self.attributes = attributes
        self.content = content as NSString
    }

    /**
     * `length` returns the length of content.
     */
    public var count: Int {
        return self.content.length
    }

    /**
     * `substring` returns a sub-string value of the given range.
     */
    public func substring(from indexStart: Int, to indexEnd: Int) -> TextValue {
        let value = TextValue(self.content.substring(with: NSRange(location: indexStart, length: indexEnd - indexStart)), self.attributes.deepcopy())
        return value
    }

    /**
     * `setAttr` sets attribute of the given key, updated time and value.
     */
    public func setAttr(key: String, value: String, updatedAt: TimeTicket) {
        self.attributes.set(key: key, value: value, executedAt: updatedAt)
    }

    /**
     * `toString` returns content.
     */
    public var toString: String {
        self.content as String
    }

    /**
     * `toJSON` returns the JSON encoding of this .
     */
    public var toJSON: String {
        let attrs = self.attributes.toObject()

        var attrsString = ""

        if attrs.isEmpty == false {
            var data = [String]()

            attrs.forEach { key, value in
                if value.value.count > 2, value.value.first == "\"", value.value.last == "\"" {
                    data.append("\"\(key)\":\(value.value)")
                } else {
                    data.append("\"\(key)\":\(value.value)")
                }
            }

            attrsString = "\"attrs\":{\(data.joined(separator: ","))},"
        }

        let valString = self.toString.escaped()

        if attrsString.isEmpty && valString.isEmpty {
            return ""
        } else {
            return "{\(attrsString)\"val\":\"\(valString)\"}"
        }
    }

    /**
     * `getAttributes` returns the attributes of this value.
     */
    public func getAttributes() -> [String: (value: String, updatedAt: TimeTicket)] {
        self.attributes.toObject()
    }

    public var description: String {
        self.content as String
    }
}

final class CRDTText: CRDTGCElement {
    public typealias TextVal = (attributes: TextAttributes, content: String)

    var createdAt: TimeTicket
    var movedAt: TimeTicket?
    var removedAt: TimeTicket?

    /**
     * `rgaTreeSplit` returns rgaTreeSplit.
     *
     **/
    private(set) var rgaTreeSplit: RGATreeSplit<TextValue>
    private var selectionMap: [String: Selection]
    private var remoteChangeLock: Bool

    init(rgaTreeSplit: RGATreeSplit<TextValue>, createdAt: TimeTicket) {
        self.rgaTreeSplit = rgaTreeSplit
        self.selectionMap = [String: Selection]()
        self.remoteChangeLock = false
        self.createdAt = createdAt
    }

    /**
     * `edit` edits the given range with the given content and attributes.
     */
    @discardableResult
    public func edit(_ range: RGATreeSplitNodeRange,
                     _ content: String,
                     _ editedAt: TimeTicket,
                     _ attributes: TextAttributes? = nil,
                     _ latestCreatedAtMapByActor: [String: TimeTicket]? = nil) throws -> [String: TimeTicket]
    {
        return try self.edit(range,
                             content,
                             editedAt,
                             attributes != nil ? stringifyAttributes(attributes!) : nil,
                             latestCreatedAtMapByActor).0
    }

    @discardableResult
    func edit(_ range: RGATreeSplitNodeRange,
              _ content: String,
              _ editedAt: TimeTicket,
              _ attributes: [String: String]? = nil,
              _ latestCreatedAtMapByActor: [String: TimeTicket]? = nil) throws -> ([String: TimeTicket], [TextChange])
    {
        let value = !content.isEmpty ? TextValue(content) : nil
        if !content.isEmpty, let attributes {
            attributes.forEach { key, jsonValue in
                value?.setAttr(key: key, value: jsonValue, updatedAt: editedAt)
            }
        }

        let (caretPos, latestCreatedAtMap, contentChanges) = try self.rgaTreeSplit.edit(
            range,
            editedAt,
            value,
            latestCreatedAtMapByActor
        )

        var changes = contentChanges.compactMap { TextChange(type: .content, actor: $0.actor, from: $0.from, to: $0.to, content: $0.content?.toString) }

        if !content.isEmpty, let attributes {
            if let change = changes[safe: changes.count - 1] {
                change.attributes = attributes
            }
        }

        if let selectionChange = try self.selectPriv((caretPos, caretPos), editedAt) {
            changes.append(selectionChange)
        }

        return (latestCreatedAtMap, changes)
    }

    /**
     * `setStyle` applies the style of the given range.
     * 01. split nodes with from and to
     * 02. style nodes between from and to
     *
     * @param range - range of RGATreeSplitNode
     * @param attributes - style attributes
     * @param editedAt - edited time
     */
    public func setStyle(_ range: RGATreeSplitNodeRange,
                         _ attributes: TextAttributes,
                         _ editedAt: TimeTicket) throws
    {
        try self.setStyle(range, stringifyAttributes(attributes), editedAt)
    }

    @discardableResult
    func setStyle(_ range: RGATreeSplitNodeRange,
                  _ attributes: [String: String],
                  _ editedAt: TimeTicket) throws -> [TextChange]
    {
        // 01. split nodes with from and to
        let toRight = try self.rgaTreeSplit.findNodeWithSplit(range.1, editedAt).1
        let fromRight = try self.rgaTreeSplit.findNodeWithSplit(range.0, editedAt).1

        // 02. style nodes between from and to
        var changes = [TextChange]()
        let nodes = self.rgaTreeSplit.findBetween(fromRight, toRight)
        for node in nodes {
            if node.isRemoved {
                continue
            }

            let (fromIdx, toIdx) = try self.rgaTreeSplit.findIndexesFromRange(node.createRange)
            changes.append(TextChange(type: .style,
                                      actor: editedAt.actorID!,
                                      from: fromIdx,
                                      to: toIdx,
                                      content: nil,
                                      attributes: attributes))

            attributes.forEach { key, jsonValue in
                node.value.setAttr(key: key, value: jsonValue, updatedAt: editedAt)
            }
        }

        return changes
    }

    /**
     * `select` stores that the given range has been selected.
     */
    @discardableResult
    public func select(_ range: RGATreeSplitNodeRange, _ updatedAt: TimeTicket) throws -> TextChange? {
        if self.remoteChangeLock {
            return nil
        }

        return try self.selectPriv(range, updatedAt)
    }

    /**
     * `hasRemoteChangeLock` checks whether remoteChangeLock has.
     */
    public var hasRemoteChangeLock: Bool {
        self.remoteChangeLock
    }

    /**
     * `createRange` returns pair of RGATreeSplitNodePos of the given integer offsets.
     */
    public func createRange(_ fromIdx: Int, _ toIdx: Int) throws -> RGATreeSplitNodeRange {
        let fromPos = try self.rgaTreeSplit.findNodePos(fromIdx)
        if fromIdx == toIdx {
            return (fromPos, fromPos)
        }

        return try (fromPos, self.rgaTreeSplit.findNodePos(toIdx))
    }

    /**
     * `toJSON` returns the JSON encoding of this rich text.
     */
    public func toJSON() -> String {
        var json = [String]()

        self.rgaTreeSplit.forEach {
            if !$0.isRemoved {
                let nodeValue = $0.value.toJSON
                if nodeValue.isEmpty == false {
                    json.append(nodeValue)
                }
            }
        }

        return "[\(json.joined(separator: ","))]"
    }

    /**
     * `toSortedJSON` returns the sorted JSON encoding of this rich text.
     */
    public func toSortedJSON() -> String {
        self.toJSON()
    }

    /**
     * `toTestString` returns a String containing the meta data of this value
     * for debugging purpose.
     */
    public var toTestString: String {
        self.rgaTreeSplit.toTestString
    }

    public var plainText: String {
        self.rgaTreeSplit.compactMap { $0.isRemoved ? nil : $0.value.toString }.joined(separator: "")
    }

    public var values: [TextValue]? {
        self.rgaTreeSplit.compactMap { $0.isRemoved ? nil : $0.value }
    }

    /**
     * `removedNodesLen` returns length of removed nodes
     */
    public var removedNodesLength: Int {
        self.rgaTreeSplit.removedNodesLength
    }

    /**
     * `purgeRemovedNodesBefore` purges removed nodes before the given time.
     */
    public func purgeRemovedNodesBefore(ticket: TimeTicket) -> Int {
        self.rgaTreeSplit.purgeRemovedNodesBefore(ticket)
    }

    /**
     * `deepcopy` copies itself deeply.
     */
    public func deepcopy() -> CRDTElement {
        let text = CRDTText(rgaTreeSplit: self.rgaTreeSplit.deepcopy(), createdAt: self.createdAt)
        text.remove(self.removedAt)
        return text
    }

    private func selectPriv(_ range: RGATreeSplitNodeRange, _ updatedAt: TimeTicket) throws -> TextChange? {
        guard let actorID = updatedAt.actorID else {
            return nil
        }

        let postProcess = {
            self.selectionMap[actorID] = Selection(range, updatedAt)

            let (from, to) = try self.rgaTreeSplit.findIndexesFromRange(range)
            return TextChange(type: .selection, actor: actorID, from: from, to: to)
        }

        if let prevSelection = self.selectionMap[actorID] {
            if updatedAt.after(prevSelection.updatedAt) {
                return try postProcess()
            }
        } else {
            return try postProcess()
        }

        return nil
    }
}
