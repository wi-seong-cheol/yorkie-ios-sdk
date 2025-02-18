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

extension String {
    func substring(from: Int, to: Int) -> String {
        guard from <= to, from < self.count else {
            return ""
        }

        let adaptedTo = min(to, self.count - 1)

        let start = index(self.startIndex, offsetBy: from)
        let end = index(self.startIndex, offsetBy: adaptedTo)
        let range = start ... end

        return String(self[range])
    }

    var toDocKey: String {
        let lower = self.lowercased()
        let regex = try? NSRegularExpression(pattern: "[^a-z0-9-]")

        return regex?.stringByReplacingMatches(in: lower, options: [], range: NSRange(0 ..< lower.count), withTemplate: "-").substring(from: 0, to: 119) ?? ""
    }

    var toJSONObject: Any {
        if let data = self.data(using: .utf8) {
            return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) ?? self
        }

        return self
    }

    var toJSONString: String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: self, options: [.fragmentsAllowed, .withoutEscapingSlashes]),
           let escapedValue = String(bytes: jsonData, encoding: .utf8)
        {
            return escapedValue
        }

        return ""
    }
}
