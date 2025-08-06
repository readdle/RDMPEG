//
//  RDMPEGSubtitleASSParser.swift
//  RDMPEG
//
//  Created by Max Berezhnoy on 15/07/2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

import Foundation

@objcMembers
public class RDMPEGSubtitleASSParser: NSObject {

    public class func parseEvents(_ events: String) -> [String]? {
        guard let range = events.range(of: "[Events]") else { return nil }
        var position = range.upperBound

        guard let formatRange = events.range(of: "Format:", range: position..<events.endIndex) else { return nil }
        position = formatRange.upperBound

        guard let newlineRange = events.rangeOfCharacter(
            from: .newlines,
            range: position..<events.endIndex
        ) else {
            return nil
        }

        let format = events[position..<newlineRange.lowerBound]
        let fields = format.components(separatedBy: ",")

        guard fields.isEmpty == false else { return nil }

        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    public class func parseDialogue(_ dialogue: String, numFields: UInt) -> [String]? {
        guard dialogue.hasPrefix("Dialogue:") else { return nil }

        var fields: [String] = []
        var range = dialogue.index(dialogue.startIndex, offsetBy: "Dialogue:".count)..<dialogue.endIndex
        var currentField: UInt = 0

        while range.lowerBound != dialogue.endIndex && currentField < numFields {
            let position = range.lowerBound

            if let commaRange = dialogue.range(of: ",", range: position..<dialogue.endIndex) {
                range = commaRange.upperBound..<dialogue.endIndex
            }
            else {
                range = dialogue.endIndex..<dialogue.endIndex
            }

            let field = dialogue[position..<range.lowerBound]
                .replacingOccurrences(of: "\\N", with: "\n")
            fields.append(String(field))

            currentField += 1
        }

        return fields
    }

    public class func removeCommandsFromEventText(_ text: String) -> String {
        var result = ""
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil

        while scanner.isAtEnd == false {
            if let scanned = scanner.scanUpToString("{\\") {
                result += scanned
            }

            if scanner.scanString("{\\") != nil,
               scanner.scanUpToString("}") != nil,
               scanner.scanString("}") != nil {
                continue
            }
            else {
                break
            }
        }

        return result
    }
}
