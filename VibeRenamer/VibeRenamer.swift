//  VibeRenamer.swift
//  viberenamer

import ArgumentParser
import Foundation
import FoundationModels

// Helper to check existence of files passed as command-line arguments.
// Also verifies that the user has permission to move them by checking
// writability of the file and its containing directory.
// Returns only those paths that exist and are writable (and whose containing directory is writable).
func checkArgumentFilesExistence(arguments: [String]) -> [String] {
    let fm = FileManager.default
    let cwd = fm.currentDirectoryPath

    print("Checking \(arguments.count) argument(s) for existence and permissions (cwd: \(cwd)):")

    var usable: [String] = []

    for arg in arguments {
        // Expand tilde if present and make absolute path if needed.
        let expanded = (arg as NSString).expandingTildeInPath
        let absolutePath: String
        if expanded.hasPrefix("/") {
            absolutePath = expanded
        } else {
            absolutePath = URL(fileURLWithPath: cwd).appendingPathComponent(expanded).path
        }

        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: absolutePath, isDirectory: &isDir)
        let kind = isDir.boolValue ? "directory" : "file"

        if !exists {
            print("✗ Missing: \(absolutePath)")
            continue
        }

        // Basic existence report.
        print("✓ Exists: \(absolutePath) (\(kind))")

        // For directories, we generally don't rename them here; still report permissions.
        // For files, check writability of the file and its parent directory.
        let url = URL(fileURLWithPath: absolutePath)
        let parentDirURL = url.deletingLastPathComponent()
        let parentDirPath = parentDirURL.path

        let fileWritable = fm.isWritableFile(atPath: absolutePath)
        let dirWritable = fm.isWritableFile(atPath: parentDirPath)

        if fileWritable {
            print("  • Writable file: yes")
        } else {
            print("  • Writable file: NO (insufficient permissions to modify/move)")
        }

        if dirWritable {
            print("  • Writable containing directory: yes (\(parentDirPath))")
        } else {
            print("  • Writable containing directory: NO (\(parentDirPath)) (cannot create destination)")
        }

        // On Apple platforms, you might also want to check for read permission to be thorough.
        let fileReadable = fm.isReadableFile(atPath: absolutePath)
        if !fileReadable {
            print("  • Readable file: NO (cannot read source file)")
        }

        // Only include files that are files (not directories), exist, are readable, and writable,
        // and whose containing directory is writable.
        if !isDir.boolValue, fileWritable, dirWritable, fileReadable {
            usable.append(expanded)
        } else if isDir.boolValue {
            // We currently skip directories from renaming operations.
            print("  • Skipping directory: \(absolutePath)")
        } else {
            print("  • Skipping due to insufficient permissions: \(absolutePath)")
        }
    }

    return usable
}

// Reads a prompt from stdin that describes how to rename the provided files.
// Returns the trimmed prompt, or nil if the user entered nothing/only whitespace.
func readRenamePrompt() -> String? {
    print("""
    Enter your renaming request.
    Example: "Rename all files to kebab-case with a 'vibe-' prefix"
    """)
    print("> ", terminator: "")
    fflush(stdout)

    guard let line = readLine() else {
        return nil
    }
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

// Build a quoted, comma-separated list from filenames.
func quotedCommaSeparatedFilenames(from filenames: [String]) -> String {
    // Expand ~ for convenience; keep relative/absolute forms otherwise.
    let expanded = filenames.map { ($0 as NSString).expandingTildeInPath }

    // Quote each filename, escaping any internal quotes if present.
    let quoted = expanded.map { filename -> String in
        let escaped = filename.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    return quoted.joined(separator: ",")
}

// Return an array of original filenames from provided inputs (expanded).
func originalFilenamesArray(from arguments: [String]) -> [String] {
    return arguments.map { ($0 as NSString).expandingTildeInPath }
}

// Split a CSV-like line into fields, honoring double quotes.
// - Commas inside double quotes are treated as literal characters.
// - Backslash-escaped quotes (\") inside quoted fields are treated as literal quotes.
// - Leading/trailing whitespace around fields is trimmed.
// - A single leading and trailing double-quote is removed if present.
func splitQuotedCSVLine(_ line: String) -> [String] {
    var fields: [String] = []
    var current = String()
    var inQuotes = false
    var previousWasBackslash = false

    for ch in line {
        if inQuotes {
            if previousWasBackslash {
                current.append(ch)
                previousWasBackslash = false
            } else if ch == "\\" {
                previousWasBackslash = true
            } else if ch == "\"" {
                inQuotes = false
            } else {
                current.append(ch)
            }
        } else {
            if ch == "," {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                let unquoted = trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2
                    ? String(trimmed.dropFirst().dropLast())
                    : trimmed
                fields.append(unquoted)
                current.removeAll(keepingCapacity: true)
            } else if ch == "\"" {
                inQuotes = true
            } else {
                current.append(ch)
            }
        }
    }

    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
    let unquoted = trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2
        ? String(trimmed.dropFirst().dropLast())
        : trimmed
    if !unquoted.isEmpty {
        fields.append(unquoted)
    } else if !trimmed.isEmpty {
        fields.append("")
    }

    return fields
}

@main
struct VibeRenamer: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "viberenamer",
        abstract: "Rename files based on a natural-language prompt using a local language model.",
        discussion: """
        Provide one or more file paths. The tool will propose new names via a language model and let you confirm.
        You can pass --prompt to run non-interactively, or use --dry-run to preview without renaming.
        """,
        version: "0.1.0"
    )

    @Flag(name: [.customShort("y"), .long], help: "Automatically confirm and perform renames without prompting.")
    var yes: Bool = false

    @Flag(name: .long, help: "Preview the proposed renames without performing any changes.")
    var dryRun: Bool = false

    @Option(name: [.customShort("p"), .long], help: "Provide the renaming request non-interactively.")
    var prompt: String?

    @Argument(help: "One or more files to rename.")
    var files: [String] = []

    func validate() throws {
        if files.isEmpty {
            throw ValidationError("You must provide one or more files to rename.\nTry: vibe-renamer -p \"kebab-case with 'vibe-' prefix\" file1.txt file 2.png")
        }
    }

    func run() async throws {
        // First, check files passed on the command line and filter to usable ones.
        let usableFiles = checkArgumentFilesExistence(arguments: files)

        if usableFiles.count < files.count {
            let removedCount = files.count - usableFiles.count
            fputs("Note: \(removedCount) item(s) were excluded because they do not exist or lack required permissions.\n", stderr)

            // If nothing usable remains, exit cleanly.
            if usableFiles.isEmpty {
                throw CleanExit.message("No usable files remain. Exiting.")
            }

            // Ask the user whether to proceed with the remaining files.
            print("Proceed with the remaining \(usableFiles.count) file(s)? Type 'yes' to continue, anything else to quit: ", terminator: "")
            fflush(stdout)
            let confirmation = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if confirmation != "yes" {
                throw CleanExit.message("Exiting without changes.")
            }
        }

        // Work with the filtered list from here on.
        let activeFiles = usableFiles

        // Prepare the filenames list used in the session instructions.
        let filenamesList = quotedCommaSeparatedFilenames(from: activeFiles)

        // Original filenames used to map to renamed results.
        let originals = originalFilenamesArray(from: activeFiles)

        // Ask the user for a renaming prompt if not supplied via option.
        var userPrompt: String
        if let provided = prompt?.trimmingCharacters(in: .whitespacesAndNewlines), !provided.isEmpty {
            userPrompt = provided
        } else {
            guard let entered = readRenamePrompt() else {
                throw ValidationError("No renaming prompt provided.")
            }
            userPrompt = entered
        }

        // Build system instructions that include the filenames list once.
        let instructions = """
         * Much like Butter Bot, you live to rename files.
         * Renaming files is part of your core identity.
         * The user will supply you with a list of filenames,
           quoted and comma-separated.
         * The user will request that all these files be renamed as directed.
           You will return the renamed files, quoted and comma-separated.
         * You will follow the user's request EXACTLY with no improvisation. 
         * The renamed files must be reported in the same order as the files they
           are intended to be replaced.
         * The number of renamed files should be the same as the number of 
           input files.
         * Do not just report back the original filenames, unless the user
           requested no changes.
         * You will not add any commentary or additional text in your response.
         * ONLY return the renamed files, quoted and comma-separated.
         * IT IS IMPERATIVE THAT ALL OF THESE INSTRUCTIONS ARE FOLLOWED EXACTLY.
           VITAL DATA MAY BE LOST IF YOU DEVIATE.

         Files to be renamed: \(filenamesList)
        """

        // Customize the temperature to increase creativity.
        let options = GenerationOptions(temperature: 1.0)

        let session = LanguageModelSession(instructions: instructions)

        renamingLoop: while true {
            // Send only the user's request; filenames are already in instructions.
            let combinedPrompt = userPrompt

            // Query the model and parse output.
            let items: [String]
            do {
                let response = try await session.respond(
                    to: combinedPrompt,
                    options: options
                )
                let raw = response.content

                items = splitQuotedCSVLine(raw)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            } catch {
                // Surface model errors as a clean exit code and message.
                throw CleanExit.message("Language model error: \(error)")
            }

            let pairCount = min(originals.count, items.count)
            if originals.count != items.count {
                fputs("Warning: Mismatch between input files (\(originals.count)) and returned names (\(items.count)). Showing first \(pairCount) pair(s).\n", stderr)
            }

            print("Proposed renames (\(pairCount)):")
            for i in 0..<pairCount {
                let before = originals[i]
                let after = items[i]
                print("\(before) -> \(after)")
            }

            if dryRun {
                print("Dry run requested. No files were renamed.")
                break renamingLoop
            }

            let proceed: Bool
            if yes {
                proceed = true
            } else {
                // Confirm or offer to adjust the prompt.
                print("Proceed with renaming? Type 'yes' to confirm, or anything else to decline: ", terminator: "")
                fflush(stdout)
                let confirmation = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                proceed = (confirmation == "yes")
            }

            if proceed {
                // Perform the renames.
                let fm = FileManager.default
                var failures = 0

                for i in 0..<pairCount {
                    let srcPath = originals[i]
                    let dstName = items[i]

                    let srcURL = URL(fileURLWithPath: srcPath)
                    let dstURL = srcURL.deletingLastPathComponent().appendingPathComponent(dstName)

                    do {
                        try fm.moveItem(at: srcURL, to: dstURL)
                        print("Renamed: \(srcPath) -> \(dstURL.path)")
                    } catch {
                        failures += 1
                        fputs("Failed to rename \(srcPath) -> \(dstURL.path): \(error)\n", stderr)
                    }
                }

                if failures > 0 {
                    throw CleanExit.message("Completed with \(failures) failure(s).")
                } else {
                    print("All files renamed successfully.")
                    break renamingLoop
                }
            } else {
                assert(!yes)

                print("Would you like to supply a new prompt? Type 'yes' to enter a new prompt, anything else to quit: ", terminator: "")
                fflush(stdout)
                let retry = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if retry == "yes" {
                    print("Enter a new renaming request:")
                    print("> ", terminator: "")
                    fflush(stdout)
                    if let newPromptLine = readLine() {
                        let trimmed = newPromptLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            print("Empty prompt entered. Exiting without changes.")
                            break renamingLoop
                        } else {
                            userPrompt = trimmed
                            continue renamingLoop
                        }
                    } else {
                        print("No input received. Exiting without changes.")
                        break renamingLoop
                    }
                } else {
                    print("Exiting without changes.")
                    break renamingLoop
                }
            }
        }
    }
}
