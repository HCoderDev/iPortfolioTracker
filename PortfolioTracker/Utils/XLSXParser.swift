//
//  XLSXParser.swift
//  PortfolioTracker
//

import Foundation
import zlib

struct XLSXSheet {
    let name: String
    let rid: String
    var path: String?
}

class XLSXParser: NSObject {
    
    // MARK: - ZIP Unpacker
    
    private struct ZipEntry {
        let path: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let dataOffset: Int
    }
    
    private static func parseZipEntries(data: Data) -> [ZipEntry] {
        var entries: [ZipEntry] = []
        let bytes = [UInt8](data)
        let total = bytes.count
        
        // 1. Try Central Directory parsing (most reliable for all XLSX files including those with Data Descriptors)
        var offset = 0
        while offset + 46 <= total {
            if bytes[offset] == 0x50 && bytes[offset+1] == 0x4b && bytes[offset+2] == 0x01 && bytes[offset+3] == 0x02 {
                let compressionMethod = UInt16(bytes[offset+10]) | (UInt16(bytes[offset+11]) << 8)
                let cSize = Int(UInt32(bytes[offset+20]) | (UInt32(bytes[offset+21]) << 8) | (UInt32(bytes[offset+22]) << 16) | (UInt32(bytes[offset+23]) << 24))
                let uSize = Int(UInt32(bytes[offset+24]) | (UInt32(bytes[offset+25]) << 8) | (UInt32(bytes[offset+26]) << 16) | (UInt32(bytes[offset+27]) << 24))
                let fnLen = Int(UInt16(bytes[offset+28]) | (UInt16(bytes[offset+29]) << 8))
                let extraLen = Int(UInt16(bytes[offset+30]) | (UInt16(bytes[offset+31]) << 8))
                let commentLen = Int(UInt16(bytes[offset+32]) | (UInt16(bytes[offset+33]) << 8))
                let localOffset = Int(UInt32(bytes[offset+42]) | (UInt32(bytes[offset+43]) << 8) | (UInt32(bytes[offset+44]) << 16) | (UInt32(bytes[offset+45]) << 24))
                
                let fnStart = offset + 46
                if fnStart + fnLen <= total {
                    let fnData = Data(bytes[fnStart..<(fnStart+fnLen)])
                    if let filename = String(data: fnData, encoding: .utf8) ?? String(data: fnData, encoding: .ascii) {
                        // Calculate dataOffset from local header
                        if localOffset + 30 <= total && bytes[localOffset] == 0x50 && bytes[localOffset+1] == 0x4b && bytes[localOffset+2] == 0x03 && bytes[localOffset+3] == 0x04 {
                            let localFnLen = Int(UInt16(bytes[localOffset+26]) | (UInt16(bytes[localOffset+27]) << 8))
                            let localExtraLen = Int(UInt16(bytes[localOffset+28]) | (UInt16(bytes[localOffset+29]) << 8))
                            let dataOffset = localOffset + 30 + localFnLen + localExtraLen
                            
                            entries.append(ZipEntry(
                                path: filename,
                                compressionMethod: compressionMethod,
                                compressedSize: cSize,
                                uncompressedSize: uSize,
                                dataOffset: dataOffset
                            ))
                        }
                    }
                }
                offset = fnStart + fnLen + extraLen + commentLen
            } else {
                offset += 1
            }
        }
        
        if !entries.isEmpty {
            return entries
        }
        
        // 2. Fallback to Local Header scanning
        offset = 0
        while offset + 30 <= total {
            if bytes[offset] == 0x50 && bytes[offset+1] == 0x4b && bytes[offset+2] == 0x03 && bytes[offset+3] == 0x04 {
                let compressionMethod = UInt16(bytes[offset+8]) | (UInt16(bytes[offset+9]) << 8)
                let cSize = Int(UInt32(bytes[offset+18]) | (UInt32(bytes[offset+19]) << 8) | (UInt32(bytes[offset+20]) << 16) | (UInt32(bytes[offset+21]) << 24))
                let uSize = Int(UInt32(bytes[offset+22]) | (UInt32(bytes[offset+23]) << 8) | (UInt32(bytes[offset+24]) << 16) | (UInt32(bytes[offset+25]) << 24))
                let fnLen = Int(UInt16(bytes[offset+26]) | (UInt16(bytes[offset+27]) << 8))
                let extraLen = Int(UInt16(bytes[offset+28]) | (UInt16(bytes[offset+29]) << 8))
                
                let fnStart = offset + 30
                if fnStart + fnLen <= total {
                    let fnData = Data(bytes[fnStart..<(fnStart+fnLen)])
                    if let filename = String(data: fnData, encoding: .utf8) ?? String(data: fnData, encoding: .ascii) {
                        let dataOffset = fnStart + fnLen + extraLen
                        entries.append(ZipEntry(
                            path: filename,
                            compressionMethod: compressionMethod,
                            compressedSize: cSize,
                            uncompressedSize: uSize,
                            dataOffset: dataOffset
                        ))
                    }
                }
                let step = cSize > 0 ? cSize : 1
                offset = fnStart + fnLen + extraLen + step
            } else {
                offset += 1
            }
        }
        
        return entries
    }
    
    private static func decompressZipEntry(entry: ZipEntry, fileData: Data) -> Data? {
        guard entry.dataOffset + entry.compressedSize <= fileData.count else { return nil }
        let rawData = fileData.subdata(in: entry.dataOffset..<(entry.dataOffset + entry.compressedSize))
        
        if entry.compressionMethod == 0 {
            return rawData
        } else if entry.compressionMethod == 8 {
            return decompressDeflate(rawData, uncompressedSize: entry.uncompressedSize)
        }
        return nil
    }
    
    private static func decompressDeflate(_ data: Data, uncompressedSize: Int) -> Data? {
        var stream = z_stream()
        let dataCount = data.count
        return data.withUnsafeBytes { rawBuffer -> Data? in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: baseAddress.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(dataCount)
            
            // -15 for raw deflate
            guard inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                return nil
            }
            defer { inflateEnd(&stream) }
            
            var decompressed = Data(capacity: max(uncompressedSize, 1024))
            let chunkSize = 65536
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
            defer { buffer.deallocate() }
            
            var status: Int32 = Z_OK
            repeat {
                stream.next_out = buffer
                stream.avail_out = uInt(chunkSize)
                status = inflate(&stream, Z_NO_FLUSH)
                let count = chunkSize - Int(stream.avail_out)
                if count > 0 {
                    decompressed.append(buffer, count: count)
                }
            } while status == Z_OK && stream.avail_out == 0
            
            if status == Z_STREAM_END || status == Z_OK {
                return decompressed
            }
            return decompressed.isEmpty ? nil : decompressed
        }
    }
    
    // MARK: - Internal APIs
    
    /// Reads available sheet names from an XLSX file.
    static func getSheetNames(fileURL: URL) -> [String] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return getSheetNames(data: data)
    }
    
    static func getSheetNames(data: Data) -> [String] {
        let entries = parseZipEntries(data: data)
        guard let workbookEntry = entries.first(where: { $0.path.hasSuffix("workbook.xml") && !$0.path.contains("_rels") }),
              let workbookData = decompressZipEntry(entry: workbookEntry, fileData: data)
        else { return [] }
        
        let sheets = parseWorkbookXML(data: workbookData)
        return sheets.map { $0.name }
    }
    
    /// Parses a specified sheet (or 1st sheet if sheetName is nil) into 2D string grid.
    static func parse(fileURL: URL, sheetName: String? = nil) -> [[String]] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return parse(data: data, sheetName: sheetName)
    }
    
    static func parse(data: Data, sheetName: String? = nil) -> [[String]] {
        let entries = parseZipEntries(data: data)
        
        // 1. Parse Shared Strings
        var sharedStrings: [String] = []
        if let sstEntry = entries.first(where: { $0.path.hasSuffix("sharedStrings.xml") }),
           let sstData = decompressZipEntry(entry: sstEntry, fileData: data) {
            sharedStrings = parseSharedStringsXML(data: sstData)
        }
        
        // 2. Parse Workbook sheets & rels
        guard let workbookEntry = entries.first(where: { $0.path.hasSuffix("workbook.xml") && !$0.path.contains("_rels") }),
              let workbookData = decompressZipEntry(entry: workbookEntry, fileData: data)
        else { return [] }
        
        var sheets = parseWorkbookXML(data: workbookData)
        
        // Parse relationships to resolve rId to filename
        if let relsEntry = entries.first(where: { $0.path.hasSuffix("workbook.xml.rels") }),
           let relsData = decompressZipEntry(entry: relsEntry, fileData: data) {
            let relsMap = parseRelsXML(data: relsData)
            for i in 0..<sheets.count {
                if let target = relsMap[sheets[i].rid] {
                    // Normalize target path
                    var targetPath = target
                    if targetPath.hasPrefix("/") { targetPath = String(targetPath.dropFirst()) }
                    if !targetPath.contains("xl/") && !targetPath.hasPrefix("xl/") {
                        targetPath = "xl/" + targetPath
                    }
                    sheets[i].path = targetPath
                }
            }
        }
        
        // Find target sheet
        let selectedSheet: XLSXSheet?
        if let name = sheetName {
            selectedSheet = sheets.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) ?? sheets.first
        } else {
            selectedSheet = sheets.first
        }
        
        guard let targetSheet = selectedSheet else { return [] }
        
        // Locate worksheet entry
        let worksheetEntry = entries.first(where: { entry in
            if let path = targetSheet.path {
                return entry.path.hasSuffix(path) || path.hasSuffix(entry.path)
            }
            return entry.path.contains("sheet1.xml")
        })
        
        guard let sheetEntry = worksheetEntry,
              let sheetData = decompressZipEntry(entry: sheetEntry, fileData: data)
        else { return [] }
        
        return parseWorksheetXML(data: sheetData, sharedStrings: sharedStrings)
    }
    
    // MARK: - XML Parsers
    
    private static func parseWorkbookXML(data: Data) -> [XLSXSheet] {
        class Delegate: NSObject, XMLParserDelegate {
            var sheets: [XLSXSheet] = []
            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                if elementName.hasSuffix("sheet") || elementName == "sheet" {
                    let name = attributeDict["name"] ?? "Sheet"
                    let rid = attributeDict["r:id"] ?? attributeDict["id"] ?? ""
                    sheets.append(XLSXSheet(name: name, rid: rid))
                }
            }
        }
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.sheets
    }
    
    private static func parseRelsXML(data: Data) -> [String: String] {
        class Delegate: NSObject, XMLParserDelegate {
            var map: [String: String] = [:]
            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                if elementName.hasSuffix("Relationship") || elementName == "Relationship" {
                    if let id = attributeDict["Id"], let target = attributeDict["Target"] {
                        map[id] = target
                    }
                }
            }
        }
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.map
    }
    
    private static func parseSharedStringsXML(data: Data) -> [String] {
        class Delegate: NSObject, XMLParserDelegate {
            var strings: [String] = []
            var currentString = ""
            var insideT = false
            
            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                if elementName == "si" {
                    currentString = ""
                } else if elementName == "t" {
                    insideT = true
                }
            }
            
            func parser(_ parser: XMLParser, foundCharacters string: String) {
                if insideT {
                    currentString += string
                }
            }
            
            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                if elementName == "t" {
                    insideT = false
                } else if elementName == "si" {
                    strings.append(currentString.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }
    
    private static func parseWorksheetXML(data: Data, sharedStrings: [String]) -> [[String]] {
        class Delegate: NSObject, XMLParserDelegate {
            let sharedStrings: [String]
            var grid: [Int: [Int: String]] = [:] // rowIdx -> colIdx -> value
            
            var currentRowIndex = 0
            var currentColIndex = 0
            var currentCellType = ""
            var currentVal = ""
            var insideVal = false
            var insideInlineStr = false
            
            init(sharedStrings: [String]) {
                self.sharedStrings = sharedStrings
            }
            
            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                if elementName == "row" {
                    if let r = attributeDict["r"], let rowNum = Int(r) {
                        currentRowIndex = rowNum - 1
                    } else {
                        currentRowIndex += 1
                    }
                    currentColIndex = 0
                } else if elementName == "c" {
                    currentCellType = attributeDict["t"] ?? "n"
                    if let ref = attributeDict["r"] {
                        currentColIndex = XLSXParser.columnIndexFromRef(ref)
                    }
                    currentVal = ""
                } else if elementName == "v" || elementName == "t" {
                    insideVal = true
                }
            }
            
            func parser(_ parser: XMLParser, foundCharacters string: String) {
                if insideVal {
                    currentVal += string
                }
            }
            
            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                if elementName == "v" || elementName == "t" {
                    insideVal = false
                } else if elementName == "c" {
                    var finalVal = currentVal.trimmingCharacters(in: .whitespacesAndNewlines)
                    if currentCellType == "s", let idx = Int(finalVal), idx >= 0 && idx < sharedStrings.count {
                        finalVal = sharedStrings[idx]
                    }
                    
                    if grid[currentRowIndex] == nil {
                        grid[currentRowIndex] = [:]
                    }
                    grid[currentRowIndex]?[currentColIndex] = finalVal
                    currentColIndex += 1
                }
            }
        }
        
        let delegate = Delegate(sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        
        guard let maxRow = delegate.grid.keys.max() else { return [] }
        var result: [[String]] = []
        
        for r in 0...maxRow {
            let rowMap = delegate.grid[r] ?? [:]
            let maxCol = rowMap.keys.max() ?? 0
            var rowArray: [String] = []
            if !rowMap.isEmpty {
                for c in 0...maxCol {
                    rowArray.append(rowMap[c] ?? "")
                }
            }
            result.append(rowArray)
        }
        
        return result
    }
    
    private static func columnIndexFromRef(_ ref: String) -> Int {
        var colStr = ""
        for char in ref {
            if char.isLetter {
                colStr.append(char)
            } else {
                break
            }
        }
        var col = 0
        for char in colStr.uppercased() {
            guard let scalar = char.unicodeScalars.first else { continue }
            col = col * 26 + Int(scalar.value - 65 + 1)
        }
        return max(0, col - 1)
    }
}
