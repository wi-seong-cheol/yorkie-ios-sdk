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
import Yorkie

/**
 * TextView emulates an external editor like CodeMirror to test whether change
 * events are delivered properly.
 */
class TextView {
    private var value: String = ""

    public func applyChanges(changes: [TextChange], enableLog: Bool = false) {
        let oldValue = self.value
        var changeLogs = [String]()
        changes.forEach { change in
            if change.type == .content {
                self.value = [
                    self.value.substring(from: 0, to: change.from - 1),
                    change.content ?? "",
                    self.value.substring(from: change.to, to: self.value.count - 1)
                ].joined(separator: "")

                changeLogs.append("{f:\(change.from), t:\(change.to), c:\(change.content ?? "")}")
            }
        }

        if enableLog {
            print("apply: \(oldValue)->\(self.value) [\(changeLogs.joined(separator: ","))]")
        }
    }

    public var toString: String {
        self.value
    }
}

private extension String {
    func substring(from: Int, to: Int) -> String {
        guard from <= to, from < self.count, from >= 0 else {
            return ""
        }

        let adaptedTo = min(to, self.count - 1)

        let start = index(self.startIndex, offsetBy: from)
        let end = index(self.startIndex, offsetBy: adaptedTo)
        let range = start ... end

        return String(self[range])
    }
}
