import Foundation
import SwiftReadability
import SwiftReadabilityFixtureSupport

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private struct ContractResult: Encodable {
    let name: String
    let parsed: Bool
    let threw: Bool
    let readerable: Bool
    let title: String?
    let byline: String?
    let direction: String?
    let language: String?
    let excerpt: String?
    let siteName: String?
    let publishedTime: String?
    let content: String?
    let textContent: String?
    let length: Int?
}

private struct Arguments {
    var pagesPath = "Tests/SwiftReadabilityTests/Fixtures/test-pages"
    var filter: String?
    var casesFromStandardInput = false
    var fixturesPathWasExplicit = false
}

private struct ContractCase: Decodable {
    let name: String
    let html: String
    let url: String
    let options: ContractOptions?
}

private struct ContractOptions: Decodable {
    let maxElemsToParse: Int?
    let nbTopCandidates: Int?
    let charThreshold: Int?
    let classesToPreserve: [String]?
    let keepClasses: Bool?
    let disableJSONLD: Bool?
    let allowedVideoRegex: ContractRegex?
    let linkDensityModifier: Double?
    let serializer: ContractSerializer?

    func readabilityOptions() throws -> ReadabilityOptions {
        let defaults = ReadabilityOptions()
        return ReadabilityOptions(
            maxElemsToParse: maxElemsToParse ?? defaults.maxElemsToParse,
            nbTopCandidates: nbTopCandidates ?? defaults.nbTopCandidates,
            charThreshold: charThreshold ?? defaults.charThreshold,
            classesToPreserve: classesToPreserve ?? defaults.classesToPreserve,
            keepClasses: keepClasses ?? defaults.keepClasses,
            serializer: serializer?.implementation,
            disableJSONLD: disableJSONLD ?? defaults.disableJSONLD,
            allowedVideoRegex: try allowedVideoRegex?.regularExpression(),
            linkDensityModifier: linkDensityModifier ?? defaults.linkDensityModifier
        )
    }
}

private struct ContractRegex: Decodable {
    let pattern: String
    let flags: String

    func regularExpression() throws -> NSRegularExpression {
        var options: NSRegularExpression.Options = []
        var seen = Set<Character>()
        for flag in flags {
            guard seen.insert(flag).inserted else {
                throw CorpusError("Duplicate regular-expression flag: \(flag)")
            }
            switch flag {
            case "i": options.insert(.caseInsensitive)
            case "m": options.insert(.anchorsMatchLines)
            case "s": options.insert(.dotMatchesLineSeparators)
            default: throw CorpusError("Unsupported regular-expression flag: \(flag)")
            }
        }
        return try NSRegularExpression(pattern: pattern, options: options)
    }
}

private enum ContractSerializer: String, Decodable {
    case mutateAndReturnMarker = "mutate-and-return-marker"

    var implementation: ReadabilityOptions.Serializer {
        switch self {
        case .mutateAndReturnMarker:
            return { element in
                _ = try? element.text("SERIALIZER_MUTATION")
                return "SERIALIZER_MARKER"
            }
        }
    }
}

private func parseArguments(_ values: [String]) throws -> Arguments {
    var arguments = Arguments()
    var index = 1
    while index < values.count {
        switch values[index] {
        case "--fixtures":
            guard index + 1 < values.count else { throw CorpusError("--fixtures requires a path") }
            arguments.pagesPath = values[index + 1]
            arguments.fixturesPathWasExplicit = true
            index += 2
        case "--filter":
            guard index + 1 < values.count else { throw CorpusError("--filter requires a value") }
            arguments.filter = values[index + 1]
            index += 2
        case "--cases-stdin":
            guard !arguments.casesFromStandardInput else {
                throw CorpusError("--cases-stdin may be supplied only once")
            }
            arguments.casesFromStandardInput = true
            index += 1
        default:
            throw CorpusError("Unknown argument: \(values[index])")
        }
    }
    if arguments.casesFromStandardInput,
       arguments.fixturesPathWasExplicit || arguments.filter != nil {
        throw CorpusError("--cases-stdin cannot be combined with --fixtures or --filter")
    }
    return arguments
}

private func contractResult(
    name: String,
    readerable: Bool,
    result: ReadabilityResult?,
    threw: Bool
) -> ContractResult {
    ContractResult(
        name: name,
        parsed: result != nil,
        threw: threw,
        readerable: readerable,
        title: result?.title,
        byline: result?.byline,
        direction: result?.dir,
        language: result?.lang,
        excerpt: result?.excerpt,
        siteName: result?.siteName,
        publishedTime: result?.publishedTime,
        content: result?.content,
        textContent: result?.textContent,
        length: result?.length
    )
}

private func runCasesFromStandardInput() throws -> [ContractResult] {
    let input = FileHandle.standardInput.readDataToEndOfFile()
    guard !input.isEmpty else { throw CorpusError("--cases-stdin requires a JSON payload") }
    let cases = try JSONDecoder().decode([ContractCase].self, from: input)
    guard !cases.isEmpty else { throw CorpusError("Option case payload is empty") }

    return try cases.map { testCase in
        guard let url = URL(string: testCase.url) else {
            throw CorpusError("Invalid URL for option case \(testCase.name)")
        }
        let options = try testCase.options?.readabilityOptions() ?? ReadabilityOptions()
        let readerable = Readability.isProbablyReaderable(html: testCase.html)
        do {
            let result = try Readability(
                html: testCase.html,
                url: url,
                options: options
            ).parse()
            return contractResult(
                name: testCase.name,
                readerable: readerable,
                result: result,
                threw: false
            )
        } catch {
            return contractResult(
                name: testCase.name,
                readerable: readerable,
                result: nil,
                threw: true
            )
        }
    }
}

private func run() throws {
    let arguments = try parseArguments(CommandLine.arguments)
    if arguments.casesFromStandardInput {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(runCasesFromStandardInput()))
        return
    }

    let pagesURL = URL(fileURLWithPath: arguments.pagesPath, isDirectory: true)
    let fixtures = try FixtureCorpus.load(pagesURL: pagesURL, nameFilter: arguments.filter)

    let results = try fixtures.map { fixture in
        let readerable = Readability.isProbablyReaderable(html: fixture.html)
        let result = try Readability(
            html: fixture.html,
            url: fixture.url
        ).parse()
        return contractResult(
            name: fixture.name,
            readerable: readerable,
            result: result,
            threw: false
        )
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(results))
}

do {
    try run()
} catch {
    let message = "SwiftReadabilityContract: \(error)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(EXIT_FAILURE)
}
