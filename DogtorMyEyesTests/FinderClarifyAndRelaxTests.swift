import XCTest
@testable import DogtorMyEyes

/// Design review fixes for the finder: guessed chips, the clarify prompt, no-match relaxation,
/// keyword fallback, and VoiceOver announcements.
final class FinderGuessedChipTests: XCTestCase {
    private let parser = RuleBasedQueryParser()
    private let areas = ["Brooklyn", "Manhattan", "Queens"]

    func testExplicitValuesAreConfirmedAndInferredOrCorrectedOnesAreGuessed() {
        let stated = parser.filters(for: "ophthalmologist, VSP, Brooklyn, Saturday", knownAreas: areas)
        XCTAssertTrue(stated.guessed.isEmpty)

        let inferred = parser.filters(for: "cloudy eye, VSP, Brooklyn, Saturday", knownAreas: areas)
        XCTAssertEqual(inferred.guessed, [.specialty])

        let typos = parser.filters(for: "exam, spectra, brooklin, saterday", knownAreas: areas)
        XCTAssertEqual(typos.guessed, [.plan, .near, .urgency])
    }

    func testUrgentSoonestIsNeverShownAsAGuess() {
        let filters = parser.filters(for: "my dog's eye is bleeding, saterday", knownAreas: areas)

        XCTAssertEqual(filters.urgency, .asap)
        XCTAssertFalse(filters.guessed.contains(.urgency))
    }

    func testMergeMarksModelOnlyValuesAsGuessed() {
        var model = FinderFilters()
        model.specialty = .optometry
        model.area = "Queens"
        let rules = parser.filters(for: "VSP exam in Queens", knownAreas: areas)

        let merged = ResilientFinderParser.merge(model: model, rules: rules, context: FinderParseContext(knownAreas: areas, now: Fixtures.now))
        XCTAssertFalse(merged.guessed.contains(.specialty), "Model agrees with an explicit rules match")
        XCTAssertFalse(merged.guessed.contains(.near))

        var disagreeing = FinderFilters()
        disagreeing.specialty = .lasikConsult
        let overridden = ResilientFinderParser.merge(model: disagreeing, rules: rules, context: FinderParseContext(knownAreas: areas, now: Fixtures.now))
        XCTAssertTrue(overridden.guessed.contains(.specialty))
    }

    @MainActor
    func testPlanFromSettingsIsGuessedUntilTheUserConfirmsIt() async {
        let finder = FinderModel(parser: ResilientFinderParser(primary: nil))
        finder.query = "routine exam"

        await finder.submit(knownAreas: areas, savedCoverage: .insurance(.davis), now: Fixtures.now)
        XCTAssertTrue(finder.filters.guessed.contains(.plan))

        finder.setPlan(.coverage(.insurance(.davis)))
        XCTAssertFalse(finder.filters.guessed.contains(.plan))
    }

    @MainActor
    func testEditingAChipConfirmsIt() async {
        let finder = FinderModel(parser: ResilientFinderParser(primary: nil))
        finder.query = "cloudy eye, spectra, brooklin, saterday"
        await finder.submit(knownAreas: areas, savedCoverage: .selfPay, now: Fixtures.now)
        XCTAssertEqual(finder.filters.guessed, [.specialty, .plan, .near, .urgency])

        finder.setSpecialty(.ophthalmology)
        finder.setNear(area: "Brooklyn", maxDistanceMiles: nil)
        finder.setUrgency(.weekday(7))
        finder.setInNetworkOnly(true)

        XCTAssertTrue(finder.filters.guessed.isEmpty)
    }
}

final class ClarifyQuestionTests: XCTestCase {
    private func filters(_ build: (inout FinderFilters) -> Void) -> FinderFilters {
        var filters = FinderFilters()
        build(&filters)
        return filters
    }

    func testAsksWhatTheDogNeedsWhenNothingWasUnderstood() {
        let question = ClarifyQuestion.make(filters: FinderFilters(), plan: nil, planFromSettings: false)

        XCTAssertEqual(question?.slot, .specialty)
        XCTAssertEqual(question?.answers.first?.action, .specialty(.ophthalmology))
    }

    func testGuessedSpecialtyOutranksGuessedPlan() {
        let guessedBoth = filters {
            $0.specialty = .ophthalmology
            $0.triage = .symptom
            $0.guessed = [.specialty, .plan]
        }

        let question = ClarifyQuestion.make(filters: guessedBoth, plan: .coverage(.insurance(.vsp)), planFromSettings: true)

        XCTAssertEqual(question?.slot, .specialty)
        XCTAssertEqual(question?.prompt, "Sounds like Ophthalmology. Is that right?")
    }

    func testPlanFromSettingsAsksToConfirm() {
        let onlyPlanGuessed = filters {
            $0.specialty = .optometry
            $0.guessed = [.plan]
        }

        let question = ClarifyQuestion.make(filters: onlyPlanGuessed, plan: .coverage(.insurance(.vsp)), planFromSettings: true)

        XCTAssertEqual(question?.slot, .plan)
        XCTAssertEqual(question?.answers.first?.title, "Yes, VSP")
        XCTAssertFalse(question?.answers.dropFirst().contains { $0.action == .plan(.coverage(.insurance(.vsp))) } ?? true)
    }

    func testUnsupportedPlanOffersSupportedAlternatives() {
        let question = ClarifyQuestion.make(
            filters: filters { $0.specialty = .optometry },
            plan: .unsupported("Aetna"),
            planFromSettings: false
        )

        XCTAssertEqual(question?.slot, .plan)
        XCTAssertTrue(question?.answers.contains { $0.action == .plan(.coverage(.selfPay)) } ?? false)
        XCTAssertEqual(question?.answers.last?.title, "Keep Aetna")
    }

    func testGuessedWeekdayKeepsItsCapitalization() {
        let question = ClarifyQuestion.make(
            filters: filters {
                $0.specialty = .optometry
                $0.urgency = .weekday(7)
                $0.guessed = [.urgency]
            },
            plan: .coverage(.selfPay),
            planFromSettings: false
        )

        XCTAssertEqual(question?.prompt, "Did you mean Saturday?")
    }

    func testUrgentRequestsAreNeverQuestioned() {
        let urgent = filters {
            $0.triage = .urgent
            $0.specialty = .ophthalmology
            $0.guessed = [.specialty, .plan]
        }

        XCTAssertNil(ClarifyQuestion.make(filters: urgent, plan: nil, planFromSettings: true))
    }

    func testNothingToAskWhenEveryChipIsConfirmed() {
        XCTAssertNil(ClarifyQuestion.make(filters: filters { $0.specialty = .optometry }, plan: .coverage(.selfPay), planFromSettings: false))
    }

    @MainActor
    func testAnsweringAppliesTheValueAndAsksOnlyOnce() async throws {
        let finder = FinderModel(parser: ResilientFinderParser(primary: nil))
        finder.query = "cloudy eye, spectra"
        await finder.submit(knownAreas: [], savedCoverage: .selfPay, now: Fixtures.now)

        let question = try XCTUnwrap(finder.clarifyQuestion)
        XCTAssertEqual(question.slot, .specialty)
        finder.answer(try XCTUnwrap(question.answers.first { $0.action == .specialty(.optometry) }))

        XCTAssertEqual(finder.filters.specialty, .optometry)
        XCTAssertFalse(finder.filters.guessed.contains(.specialty))
        XCTAssertNil(finder.clarifyQuestion, "Only one question per query, even though the plan is still guessed")

        finder.query = "cloudy eye, spectra"
        await finder.submit(knownAreas: [], savedCoverage: .selfPay, now: Fixtures.now)
        XCTAssertNotNil(finder.clarifyQuestion, "A new query can ask again")
    }

    @MainActor
    func testDismissHidesTheQuestion() async {
        let finder = FinderModel(parser: ResilientFinderParser(primary: nil))
        finder.query = "help"
        await finder.submit(knownAreas: [], savedCoverage: .selfPay, now: Fixtures.now)
        XCTAssertNotNil(finder.clarifyQuestion)

        finder.dismissClarify()

        XCTAssertNil(finder.clarifyQuestion)
    }
}

final class FinderRelaxationTests: XCTestCase {
    private var providers: [Provider] {
        [
            Fixtures.provider(id: "far-vsp", specialty: .ophthalmology, plans: [.vsp], distance: 6, area: "Brooklyn"),
            Fixtures.provider(id: "near-eyemed", specialty: .ophthalmology, plans: [.eyeMed], acceptsSelfPay: false, distance: 1, area: "Queens"),
            Fixtures.provider(id: "optom-vsp", specialty: .optometry, plans: [.vsp], distance: 1.5, area: "Queens"),
        ]
    }

    func testNamesDistanceFirstWhenWideningItHelps() throws {
        var filters = FinderFilters()
        filters.specialty = .ophthalmology
        filters.maxDistanceMiles = 2

        let relaxation = try XCTUnwrap(FinderRanker.relaxation(for: providers, filters: filters, plan: .coverage(.insurance(.vsp))))

        XCTAssertEqual(relaxation.slot, .near)
        XCTAssertEqual(relaxation.change, .clearNear)
        XCTAssertEqual(relaxation.actionTitle, "Widen distance")
        XCTAssertEqual(relaxation.resultCount, 1)
        XCTAssertEqual(
            relaxation.message,
            "No Ophthalmology providers within 2 mi take VSP. Near is limiting results. Widen distance to see 1 match?"
        )
    }

    func testFallsThroughToSpecialtyThenPlan() throws {
        var filters = FinderFilters()
        filters.specialty = .lasikConsult
        let bySpecialty = try XCTUnwrap(FinderRanker.relaxation(for: providers, filters: filters, plan: .coverage(.insurance(.vsp))))
        XCTAssertEqual(bySpecialty.slot, .specialty)

        filters.specialty = .ophthalmology
        filters.area = "Queens"
        // Near alone still leaves ophthalmology + VSP in Brooklyn, so Near wins over Plan here.
        XCTAssertEqual(FinderRanker.relaxation(for: providers, filters: filters, plan: .coverage(.insurance(.vsp)))?.slot, .near)

        let onlyOutOfNetwork = providers.filter { $0.id == "near-eyemed" }
        let byPlan = try XCTUnwrap(FinderRanker.relaxation(for: onlyOutOfNetwork, filters: filters, plan: .coverage(.insurance(.vsp))))
        XCTAssertEqual(byPlan.slot, .plan)
        XCTAssertEqual(byPlan.change, .includeOutOfNetwork)
    }

    func testNoSingleChangeHelpsReturnsNil() {
        var filters = FinderFilters()
        filters.specialty = .pediatric
        filters.area = "Bronx"

        XCTAssertNil(FinderRanker.relaxation(for: providers, filters: filters, plan: .coverage(.insurance(.davis))))
    }

    @MainActor
    func testRelaxingUpdatesResultsAndConfirmsTheChip() async throws {
        let finder = FinderModel(parser: ResilientFinderParser(primary: nil))
        finder.query = "ophthalmology within 2 miles, VSP"
        await finder.submit(knownAreas: ["Brooklyn", "Queens"], savedCoverage: .selfPay, now: Fixtures.now)
        XCTAssertTrue(finder.results(from: providers, now: Fixtures.now).isEmpty)

        finder.relax(try XCTUnwrap(finder.relaxation(for: providers)))

        XCTAssertEqual(finder.results(from: providers, now: Fixtures.now).map(\.provider.id), ["far-vsp"])
        XCTAssertNil(finder.filters.maxDistanceMiles)
    }
}

final class FinderKeywordAndAnnouncementTests: XCTestCase {
    private var providers: [Provider] {
        [
            Fixtures.provider(id: "biscuit", name: "Dr. Biscuit Barkley, OD", breed: "Golden Retriever", plans: [.vsp]),
            Fixtures.provider(id: "luna", name: "Dr. Luna Lensworth, MD", breed: "Border Collie", plans: [.vsp]),
        ]
    }

    @MainActor
    func testKeywordSearchIsTheFallbackWhenNothingElseWasUnderstood() async {
        let finder = FinderModel(parser: ResilientFinderParser(primary: nil))
        finder.query = "Dr. Biscuit"
        await finder.submit(knownAreas: [], savedCoverage: .insurance(.vsp), now: Fixtures.now)

        let results = finder.results(from: providers, now: Fixtures.now)

        XCTAssertEqual(results.map(\.provider.id), ["biscuit"])
        XCTAssertTrue(results[0].reason.hasPrefix("Matches “biscuit”"))
    }

    func testKeywordsIgnoreStopWordsAndMatchBreeds() {
        XCTAssertTrue(FinderRanker.keywordHits(in: providers, query: "my dog needs help").isEmpty)
        XCTAssertEqual(FinderRanker.keywordHits(in: providers, query: "border collie"), ["luna": "border"])
    }

    @MainActor
    func testUnmatchedKeywordsShowEveryoneRatherThanNothing() async {
        let finder = FinderModel(parser: ResilientFinderParser(primary: nil))
        finder.query = "help"
        await finder.submit(knownAreas: [], savedCoverage: .insurance(.vsp), now: Fixtures.now)

        XCTAssertEqual(finder.results(from: providers, now: Fixtures.now).count, 2)
    }

    @MainActor
    func testAnnouncementsCountResultsAndMentionFallbackOnlyForANewParse() async {
        let finder = FinderModel(parser: ResilientFinderParser(primary: nil, primaryUnavailableReason: .modelUnavailable))
        XCTAssertNil(finder.announcement(matchCount: 3, isNewParse: true), "Nothing to announce before results exist")

        finder.query = "VSP"
        await finder.submit(knownAreas: [], savedCoverage: .selfPay, now: Fixtures.now)

        XCTAssertEqual(
            finder.announcement(matchCount: 6, isNewParse: true),
            "6 matches. Smart matching isn’t available, so keyword matching is on."
        )
        XCTAssertEqual(finder.announcement(matchCount: 1, isNewParse: false), "1 match")
        XCTAssertEqual(finder.announcement(matchCount: 0, isNewParse: false), "No matches")
    }

    @MainActor
    func testNoFallbackNoteWhenTheModelWasTurnedOffOnPurpose() async {
        let finder = FinderModel(parser: ResilientFinderParser(primary: nil, primaryUnavailableReason: .disabled))
        finder.query = "VSP"
        await finder.submit(knownAreas: [], savedCoverage: .selfPay, now: Fixtures.now)

        XCTAssertEqual(finder.announcement(matchCount: 2, isNewParse: true), "2 matches")
    }
}
