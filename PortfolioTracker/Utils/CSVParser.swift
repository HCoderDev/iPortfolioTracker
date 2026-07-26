//
//  CSVParser.swift
//  PortfolioTracker
//

import Foundation

struct CSVParser {
    /// Parses a CSV string into a 2D array of strings (`[[String]]`).
    /// Automatically detects delimiter (comma, semicolon, tab) if not specified.
    static func parse(content: String, delimiter: Character? = nil) -> [[String]] {
        let cleanContent = content.replacingOccurrences(of: "\r\n", with: "\n")
                                  .replacingOccurrences(of: "\r", with: "\n")
        
        let actualDelimiter = delimiter ?? detectDelimiter(in: cleanContent)
        
        var result: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        let scalarDelimiter = actualDelimiter.unicodeScalars.first!
        let quoteScalar = UnicodeScalar("\"")
        let newlineScalar = UnicodeScalar("\n")
        
        var index = cleanContent.unicodeScalars.startIndex
        let endIndex = cleanContent.unicodeScalars.endIndex
        
        while index < endIndex {
            let char = cleanContent.unicodeScalars[index]
            
            if insideQuotes {
                if char == quoteScalar {
                    let nextIndex = cleanContent.unicodeScalars.index(after: index)
                    if nextIndex < endIndex && cleanContent.unicodeScalars[nextIndex] == quoteScalar {
                        // Escaped quote ("")
                        currentField.append("\"")
                        index = nextIndex
                    } else {
                        // End of quoted field
                        insideQuotes = false
                    }
                } else {
                    currentField.append(Character(char))
                }
            } else {
                if char == quoteScalar {
                    insideQuotes = true
                } else if char == scalarDelimiter {
                    currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                } else if char == newlineScalar {
                    currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        result.append(currentRow)
                    }
                    currentRow = []
                    currentField = ""
                } else {
                    currentField.append(Character(char))
                }
            }
            
            index = cleanContent.unicodeScalars.index(after: index)
        }
        
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                result.append(currentRow)
            }
        }
        
        return result
    }
    
    private static func detectDelimiter(in text: String) -> Character {
        let sampleLines = text.components(separatedBy: "\n").prefix(5)
        var commaCount = 0
        var semicolonCount = 0
        var tabCount = 0
        
        for line in sampleLines {
            commaCount += line.filter { $0 == "," }.count
            semicolonCount += line.filter { $0 == ";" }.count
            tabCount += line.filter { $0 == "\t" }.count
        }
        
        if tabCount > commaCount && tabCount > semicolonCount {
            return "\t"
        } else if semicolonCount > commaCount {
            return ";"
        } else {
            return ","
        }
    }
}
