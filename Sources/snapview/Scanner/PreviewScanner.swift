import Foundation

struct PreviewEntry {
  let name: String
  let body: String
  let filePath: String
}

enum PreviewScanner {

  static func scan(source: String, filePath: String) -> [PreviewEntry] {
    var results: [PreviewEntry] = []
    let chars = Array(source)
    var i = 0

    while i < chars.count {
      guard let tokenRange = findToken("#Preview", in: chars, from: i) else { break }
      i = tokenRange.upperBound

      i = skipWhitespace(chars, from: i)

      var name: String?
      if i < chars.count, chars[i] == "(" {
        i += 1
        i = skipWhitespace(chars, from: i)
        if i < chars.count, chars[i] == "\"" {
          let (extracted, end) = extractString(chars, from: i)
          name = extracted
          i = end
          i = skipWhitespace(chars, from: i)
          if i < chars.count, chars[i] == ")" { i += 1 }
        }
      }

      i = skipWhitespace(chars, from: i)

      guard i < chars.count, chars[i] == "{" else { continue }

      guard let (body, end) = extractBraceBalanced(chars, from: i) else { continue }
      i = end

      let previewName = name ?? fileNameWithoutExtension(filePath)
      results.append(PreviewEntry(name: previewName, body: body, filePath: filePath))
    }

    return results
  }

  private static func findToken(_ token: String, in chars: [Character], from start: Int) -> Range<Int>? {
    let tokenChars = Array(token)
    var i = start
    while i <= chars.count - tokenChars.count {
      if Array(chars[i..<(i + tokenChars.count)]) == tokenChars {
        return i..<(i + tokenChars.count)
      }
      i += 1
    }
    return nil
  }

  private static func skipWhitespace(_ chars: [Character], from start: Int) -> Int {
    var i = start
    while i < chars.count, chars[i].isWhitespace || chars[i].isNewline { i += 1 }
    return i
  }

  private static func extractString(_ chars: [Character], from start: Int) -> (String, Int) {
    var i = start + 1
    var result: [Character] = []
    while i < chars.count {
      if chars[i] == "\\" && i + 1 < chars.count {
        result.append(chars[i])
        result.append(chars[i + 1])
        i += 2
      } else if chars[i] == "\"" {
        i += 1
        return (String(result), i)
      } else {
        result.append(chars[i])
        i += 1
      }
    }
    return (String(result), i)
  }

  private static func extractBraceBalanced(_ chars: [Character], from start: Int) -> (String, Int)? {
    guard start < chars.count, chars[start] == "{" else { return nil }
    var depth = 0
    var i = start
    var inString = false
    var inLineComment = false
    var inBlockComment = false

    while i < chars.count {
      let c = chars[i]

      if !inString && !inBlockComment && c == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
        inLineComment = true
        i += 2; continue
      }
      if inLineComment {
        if c == "\n" { inLineComment = false }
        i += 1; continue
      }

      if !inString && !inLineComment && c == "/" && i + 1 < chars.count && chars[i + 1] == "*" {
        inBlockComment = true
        i += 2; continue
      }
      if inBlockComment {
        if c == "*" && i + 1 < chars.count && chars[i + 1] == "/" {
          inBlockComment = false
          i += 2; continue
        }
        i += 1; continue
      }

      if c == "\"" && !inString {
        inString = true
        i += 1; continue
      }
      if inString {
        if c == "\\" { i += 2; continue }
        if c == "\"" { inString = false }
        i += 1; continue
      }

      if c == "{" { depth += 1 }
      if c == "}" {
        depth -= 1
        if depth == 0 {
          let bodyStart = start + 1
          let bodyEnd = i
          let body = String(chars[bodyStart..<bodyEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
          return (body, i + 1)
        }
      }
      i += 1
    }
    return nil
  }

  private static func fileNameWithoutExtension(_ path: String) -> String {
    let url = URL(filePath: path)
    return url.deletingPathExtension().lastPathComponent
  }
}
