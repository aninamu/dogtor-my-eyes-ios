import Foundation

/// Deterministic keyword and rule parser. Used whenever the on-device model is unavailable, slow, or fails,
/// and always used for triage. Patterns are space-separated words; a trailing `*` matches a prefix.
struct RuleBasedQueryParser: FinderQueryParser {
    func parse(_ query: String, context: FinderParseContext) async throws -> FinderFilters {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FinderParserError.emptyQuery }
        return filters(for: trimmed, knownAreas: context.knownAreas)
    }

    func filters(for query: String, knownAreas: [String]) -> FinderFilters {
        let tokens = Self.tokenize(query)
        let text = TokenText(tokens: tokens)
        var filters = FinderFilters()

        filters.triage = triage(in: text)
        filters.specialty = specialty(in: text, triage: filters.triage)
        filters.plan = plan(in: text)
        filters.inNetworkOnly = !text.matchesAny(Vocabulary.outOfNetworkOK)
        filters.area = area(in: text, knownAreas: knownAreas)
        filters.prefersNearby = text.matchesAny(Vocabulary.nearby)
        filters.maxDistanceMiles = maxDistance(in: tokens)
        filters.urgency = filters.triage == .urgent ? .asap : urgency(in: text)
        return filters
    }

    // MARK: - Fields

    private func triage(in text: TokenText) -> Triage {
        if text.matchesAny(Vocabulary.urgent) { return .urgent }
        if text.matchesAny(Vocabulary.symptoms) { return .symptom }
        if text.matchesAny(Vocabulary.eyeContext) && text.matchesAny(Vocabulary.symptomsNeedingEyeContext) {
            return .symptom
        }
        return .none
    }

    private func specialty(in text: TokenText, triage: Triage) -> Specialty? {
        if text.matchesAny(Vocabulary.lasik) { return .lasikConsult }
        if text.matchesAny(Vocabulary.framesAndContacts) { return .contactsAndFrames }
        if text.matchesAny(Vocabulary.pediatric) { return .pediatric }
        if text.matchesAny(Vocabulary.ophthalmology) || triage != .none { return .ophthalmology }
        if text.matchesAny(Vocabulary.optometry) { return .optometry }
        return nil
    }

    private func plan(in text: TokenText) -> PlanUnderstanding? {
        for (plan, patterns) in Vocabulary.plans where text.matchesAny(patterns) {
            return .coverage(.insurance(plan))
        }
        for (name, patterns) in Vocabulary.unsupportedPlans where text.matchesAny(patterns) {
            return .unsupported(name)
        }
        if text.matchesAny(Vocabulary.selfPay) { return .coverage(.selfPay) }
        return nil
    }

    private func area(in text: TokenText, knownAreas: [String]) -> String? {
        for area in knownAreas where text.matches(Pattern(area)) {
            return area
        }
        for (alias, borough) in Vocabulary.areaAliases where text.matches(Pattern(alias)) {
            if let known = knownAreas.first(where: { $0.caseInsensitiveCompare(borough) == .orderedSame }) {
                return known
            }
        }
        return nil
    }

    private func maxDistance(in tokens: [String]) -> Double? {
        for (index, token) in tokens.enumerated() {
            if let (value, unit) = Self.splitNumberAndUnit(token) {
                let nextUnit = unit ?? (index + 1 < tokens.count ? tokens[index + 1] : "")
                if let miles = Self.miles(value, unit: nextUnit), miles > 0, miles <= 100 {
                    return miles
                }
            }
        }
        return nil
    }

    private func urgency(in text: TokenText) -> FinderUrgency {
        if text.matchesAny(Vocabulary.asap) { return .asap }
        if text.matchesAny(Vocabulary.today) { return .today }
        if text.matchesAny(Vocabulary.tomorrow) { return .tomorrow }
        if text.matchesAny(Vocabulary.weekend) { return .weekend }
        for (weekday, patterns) in Vocabulary.weekdays where text.matchesAny(patterns) {
            return .weekday(weekday)
        }
        return .anyTime
    }

    // MARK: - Tokenizing

    /// Lowercases, strips diacritics, and splits on anything that isn't a letter or digit
    /// (a `.` between digits is kept so "2.5" stays one token).
    static func tokenize(_ text: String) -> [String] {
        let folded = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let characters = Array(folded)
        var tokens: [String] = []
        var current = ""
        for (index, character) in characters.enumerated() {
            let isDecimalPoint = character == "."
                && current.last?.isNumber == true
                && index + 1 < characters.count
                && characters[index + 1].isNumber
            if character.isLetter || character.isNumber || isDecimalPoint {
                current.append(character)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func splitNumberAndUnit(_ token: String) -> (Double, String?)? {
        let digits = token.prefix { $0.isNumber || $0 == "." }
        guard !digits.isEmpty, let value = Double(digits) else { return nil }
        let rest = token.dropFirst(digits.count)
        return (value, rest.isEmpty ? nil : String(rest))
    }

    private static func miles(_ value: Double, unit: String) -> Double? {
        if unit == "mi" || unit.hasPrefix("mile") || unit == "millas" { return value }
        if unit == "km" || unit.hasPrefix("kilomet") { return (value * 0.621371 * 10).rounded() / 10 }
        return nil
    }
}

// MARK: - Matching

struct Pattern {
    enum Word {
        case exact(String)
        case prefix(String)
    }

    let words: [Word]

    init(_ text: String) {
        words = text.split(separator: " ").flatMap { raw -> [Word] in
            let isPrefix = raw.hasSuffix("*")
            let parts = RuleBasedQueryParser.tokenize(String(isPrefix ? raw.dropLast() : raw))
            return parts.enumerated().map { index, part in
                isPrefix && index == parts.count - 1 ? .prefix(part) : .exact(part)
            }
        }
    }
}

struct TokenText {
    let tokens: [String]

    func matchesAny(_ patterns: [Pattern]) -> Bool {
        patterns.contains(where: matches)
    }

    func matches(_ pattern: Pattern) -> Bool {
        let count = pattern.words.count
        guard count > 0, tokens.count >= count else { return false }
        for start in 0...(tokens.count - count) {
            let window = tokens[start..<(start + count)]
            if zip(window, pattern.words).allSatisfy({ Self.matches(token: $0, word: $1) }) {
                return true
            }
        }
        return false
    }

    /// Typos are tolerated only on longer words, where a one- or two-letter slip can't plausibly be a different word.
    private static func matches(token: String, word: Pattern.Word) -> Bool {
        switch word {
        case .exact(let word):
            if token == word { return true }
            guard word.count >= 6, token.count >= 5 else { return false }
            return editDistance(token, word) <= allowedEdits(for: word)
        case .prefix(let stem):
            if token.hasPrefix(stem) { return true }
            guard stem.count >= 6, token.count >= stem.count - 1 else { return false }
            let lengths = (stem.count - 1)...(stem.count + 1)
            return lengths.contains { editDistance(String(token.prefix($0)), stem) <= 1 }
        }
    }

    private static func allowedEdits(for word: String) -> Int {
        word.count >= 8 ? 2 : 1
    }

    /// Optimal string alignment distance (Levenshtein plus adjacent transpositions).
    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { table[i][0] = i }
        for j in 0...b.count { table[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                table[i][j] = min(table[i - 1][j] + 1, table[i][j - 1] + 1, table[i - 1][j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    table[i][j] = min(table[i][j], table[i - 2][j - 2] + 1)
                }
            }
        }
        return table[a.count][b.count]
    }
}

// MARK: - Vocabulary

/// English plus common Spanish, French, and German terms. Keep entries lowercase and unaccented.
private enum Vocabulary {
    static func patterns(_ texts: [String]) -> [Pattern] { texts.map(Pattern.init) }

    static let urgent = patterns([
        "sudden* blind*", "sudden* can t see", "went blind", "gone blind", "going blind", "can t see", "cannot see",
        "cant see", "lost vision", "lost his vision", "lost her vision", "vision loss", "lost sight", "lost his sight",
        "lost her sight", "injur*", "injery", "trauma*", "wound*", "cut", "cuts", "scratch*", "hit in the eye", "poked",
        "foreign object", "stuck in eye", "bleed*", "bleding*", "bledding*", "blood", "bloody",
        "severe* pain*", "extreme* pain*", "intense pain*", "in pain", "lot of pain", "agony", "screaming", "yelp*",
        "popped out", "pop* out", "bulg*", "protrud*", "chemical*", "bleach",
        "emergenc*", "emergancy", "emergencia", "urgence", "notfall",
        "ciego", "ciega", "ceguera", "no ve", "no puede ver", "sangr*", "herid*", "golpe*", "mucho dolor", "dolor fuerte",
        "aveugle", "saign*", "blesse*", "blessure*", "douleur forte",
        "erblindet", "blut*", "verletz*", "starke schmerzen",
    ])

    static let symptoms = patterns([
        "cloud*", "clowdy", "cataract*", "catarata*", "redness", "bloodshot", "swollen", "swelling", "discharg*",
        "goop*", "goo", "gunk*", "crust*", "pus", "squint*", "squnit*", "watery", "weeping", "itchy", "pawing at",
        "cornea*", "ulcer*", "glaucoma", "cherry eye", "infect*", "irritat*", "inflam*", "blur*", "hazy", "haze",
        "milky", "bumping into", "blind*", "pink eye", "conjunctiv*",
        "nublado", "nublada", "turbio", "turbia", "hinchad*", "leganas", "picazon", "infeccion", "ojo rojo",
        "rouge", "gonfle*", "ecoulement", "oeil rouge",
        "trub*", "geschwollen", "entzund*", "ausfluss",
    ])

    static let symptomsNeedingEyeContext = patterns([
        "red", "tear*", "sore", "pain*", "hurt*", "puff*", "film", "rub*", "weep*", "itch*", "blink*", "dolor", "rojo",
    ])

    static let eyeContext = patterns(["eye*", "ojo*", "oeil", "yeux", "auge*", "vision", "see*", "sight"])

    static let lasik = patterns(["lasik", "lasic", "laser*", "refractive surgery"])
    static let framesAndContacts = patterns([
        "frame*", "contacts", "contact lens*", "contacts and frames", "lens", "lenses", "goggle*", "doggles", "sunglass*", "glasses", "eyeglass*", "eyewear",
        "gafas", "lentes", "lunettes", "brille",
    ])
    static let pediatric = patterns([
        "puppy", "puppies", "pediatric*", "paediatric*", "young", "baby", "newborn", "weeks old", "months old", "month old",
        "cachorr*", "chiot*", "welpe*",
    ])
    static let ophthalmology = patterns(["ophthalm*", "opthalm*", "specialist", "surgeon", "surgery", "retina*"])
    static let optometry = patterns([
        "optometr*", "exam", "exams", "examination", "check up", "checkup", "routine", "annual", "vision test", "eye test", "prescription*",
        "chequeo", "examen", "revision", "untersuchung",
    ])

    static let plans: [(InsurancePlan, [Pattern])] = [
        (.vsp, patterns(["vsp", "v s p"])),
        (.eyeMed, patterns(["eyemed", "eye med", "eyemd"])),
        (.davis, patterns(["davis", "davis vision"])),
        (.spectera, patterns(["spectera"])),
    ]

    static let unsupportedPlans: [(String, [Pattern])] = [
        ("Aetna", patterns(["aetna"])),
        ("Cigna", patterns(["cigna"])),
        ("Humana", patterns(["humana"])),
        ("Blue Cross", patterns(["blue cross", "bcbs", "blue shield"])),
        ("UnitedHealthcare", patterns(["united healthcare", "unitedhealthcare", "uhc"])),
        ("Kaiser", patterns(["kaiser"])),
        ("Medicaid", patterns(["medicaid"])),
        ("Medicare", patterns(["medicare"])),
        ("Trupanion", patterns(["trupanion"])),
        ("Nationwide", patterns(["nationwide"])),
        ("Lemonade", patterns(["lemonade"])),
        ("Embrace", patterns(["embrace pet*", "embrace insurance"])),
        ("Healthy Paws", patterns(["healthy paws"])),
        ("Pet insurance", patterns(["pet insurance"])),
    ]

    static let selfPay = patterns([
        "self pay", "selfpay", "out of pocket", "no insurance", "uninsured", "without insurance", "cash",
        "pay myself", "sin seguro", "sans assurance", "ohne versicherung",
    ])

    static let outOfNetworkOK = patterns([
        "out of network", "any network", "don t care about network", "dont care about network",
        "network doesn t matter", "fuera de red",
    ])

    static let nearby = patterns([
        "near me", "nearby", "close by", "close to me", "closest", "nearest", "around me", "cerca de mi", "pres de moi",
    ])

    static let areaAliases: [(String, String)] = [
        ("bk", "Brooklyn"), ("park slope", "Brooklyn"), ("williamsburg", "Brooklyn"), ("dumbo", "Brooklyn"),
        ("bushwick", "Brooklyn"), ("astoria", "Queens"), ("flushing", "Queens"), ("long island city", "Queens"),
        ("harlem", "Manhattan"), ("soho", "Manhattan"), ("midtown", "Manhattan"), ("upper west side", "Manhattan"),
        ("upper east side", "Manhattan"), ("the bronx", "Bronx"),
    ]

    static let asap = patterns([
        "asap", "as soon as possible", "urgent*", "right away", "right now", "immediately", "soonest", "earliest",
        "first available", "lo antes posible", "cuanto antes", "au plus vite", "dringend", "sofort",
    ])
    static let today = patterns([
        "today", "tonight", "this afternoon", "this morning", "this evening", "hoy", "aujourd hui", "heute",
    ])
    static let tomorrow = patterns(["tomorrow", "tmrw", "manana", "demain", "morgen"])
    static let weekend = patterns(["weekend", "week end", "fin de semana", "wochenende"])

    static let weekdays: [(Int, [Pattern])] = [
        (7, patterns(["saturday*", "sat", "sabado", "samedi", "samstag"])),
        (1, patterns(["sunday*", "domingo", "dimanche", "sonntag"])),
        (2, patterns(["monday*", "lunes", "lundi", "montag"])),
        (3, patterns(["tuesday*", "martes", "mardi", "dienstag"])),
        (4, patterns(["wednesday*", "miercoles", "mercredi", "mittwoch"])),
        (5, patterns(["thursday*", "jueves", "jeudi", "donnerstag"])),
        (6, patterns(["friday*", "viernes", "vendredi", "freitag"])),
    ]
}
