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
 * `DocEventType` is document event types
 */
public enum DocEventType: String {
    /**
     * snapshot event type
     */
    case snapshot
    /**
     * local document change event type
     */
    case localChange = "local-change"
    /**
     * remote document change event type
     */
    case remoteChange = "remote-change"
    /**
     * `PeersChanged` means that the presences of the peer clients has changed.
     * // TODO(hackerwins): We'll use peers means others. We need to find a better
     * // name for this event.
     */
    case peersChanged = "peers-changed"
}

/**
 * An event that occurs in ``Document``. It can be delivered
 * using ``Document/eventStream``.
 */
public protocol DocEvent {
    var type: DocEventType { get }
}

/**
 * `SnapshotEvent` is an event that occurs when a snapshot is received from
 * the server.
 *
 */
public struct SnapshotEvent: DocEvent {
    /**
     * ``DocEventType.snapshot``
     */
    public let type: DocEventType = .snapshot
    /**
     * SnapshotEvent type
     */
    public var value: Data
}

protocol ChangeEvent: DocEvent {
    var type: DocEventType { get }
    var value: ChangeInfo { get }
}

/**
 * `ChangeInfo` represents the modifications made during a document update
 * and the message passed.
 */
public struct ChangeInfo {
    public let message: String
    public let operations: [any OperationInfo]
    public let actorID: ActorID?
}

/**
 * `LocalChangeEvent` is an event that occurs when the document is changed
 * by local changes.
 *
 */
public struct LocalChangeEvent: ChangeEvent {
    /**
     * ``DocEventType/localChange``
     */
    public let type: DocEventType = .localChange
    /**
     * LocalChangeEvent type
     */
    public var value: ChangeInfo
}

/**
 * `RemoteChangeEvent` is an event that occurs when the document is changed
 * by remote changes.
 *
 */
public struct RemoteChangeEvent: ChangeEvent {
    /**
     * ``DocEventType/remoteChange``
     */
    public let type: DocEventType = .remoteChange
    /**
     * RemoteChangeEvent type
     */
    public var value: ChangeInfo
}

/**
 * `PeersChangedEventType` is peers changed event types
 */
enum PeersChangedEventType {
    case initialized
    case watched
    case unwatched
    case presenceChanged
}

/**
 * `PeersChangedValue` represents the value of the PeersChanged event.
 */
public typealias PeerElement = (clientID: ActorID, presence: PresenceData)

public enum PeersChangedValue {
    /**
     * `Initialized` means that the peer list has been initialized.
     */
    case initialized(peers: [PeerElement])
    /**
     * `Watched` means that the peer has established a connection with the server,
     * enabling real-time synchronization.
     */
    case watched(peer: PeerElement)
    /**
     * `Unwatched` means that the connection has been disconnected.
     */
    case unwatched(peer: PeerElement)
    /**
     * `PeersChanged` means that the presences of the peer has updated.
     */
    case presenceChanged(peer: PeerElement)
}

/**
 * `PeersChangedEvent` is an event that occurs when the states of another peers
 * of the attached documents changes. *
 */
public struct PeersChangedEvent: DocEvent {
    /**
     * ``DocEventType/peersChanged``
     */
    public let type: DocEventType = .peersChanged
    /**
     * RemoteChangeEvent type
     */
    public var value: PeersChangedValue
}
