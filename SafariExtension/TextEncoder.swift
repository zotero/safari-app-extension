// Source: https://github.com/theolampert/ECMASwift

// MIT License
// 
// Copyright (c) 2023 Theo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import JavaScriptCore

@objc
protocol TextEncoderExports: JSExport {
    var encoding: String { get set }
    func encode(_ input: String) -> [UInt8]
}

/// This implmenets the `TextEncoder` browser API.
///
/// Reference: [TextEncoder Reference on MDN](https://developer.mozilla.org/en-US/docs/Web/API/TextEncoder)
final class TextEncoder: NSObject, TextEncoderExports {
    var encoding: String = "utf-8"

    func encode(_ input: String) -> [UInt8] {
        return Array(input.utf8)
    }
}

/// Helper to register the ``TextEncoder`` API with a context.
public struct TextEncoderAPI {
    public func registerAPIInto(context: JSContext) {
        let textEncoderClass: @convention(block) () -> TextEncoder = {
            TextEncoder()
        }
        context.setObject(
            unsafeBitCast(textEncoderClass, to: AnyObject.self),
            forKeyedSubscript: "TextEncoder" as NSString
        )
    }
}