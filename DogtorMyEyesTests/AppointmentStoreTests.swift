import XCTest
@testable import DogtorMyEyes

final class AppointmentStoreTests: XCTestCase {
    private let hour: TimeInterval = 3_600

    private func provider(_ id: String, slots: [TimeInterval]) -> Provider {
        Fixtures.provider(id: id, specialty: .ophthalmology, slots: slots.map { Fixtures.now.addingTimeInterval($0) })
    }

    func testSavingCreatesARequestedAppointmentWithSnapshot() throws {
        let store = AppointmentStore(userDefaults: nil)
        let vet = provider("luna", slots: [2 * hour])
        let slot = vet.availableSlots[0]

        let request = try store.requestAppointment(with: vet, slot: slot, coverage: .insurance(.davis), now: Fixtures.now)

        XCTAssertEqual(store.requests, [request])
        XCTAssertEqual(request.providerID, "luna")
        XCTAssertEqual(request.providerName, vet.name)
        XCTAssertEqual(request.specialty, .ophthalmology)
        XCTAssertEqual(request.slot, slot)
        XCTAssertEqual(request.coverage, .insurance(.davis))
        XCTAssertEqual(request.status, .requested)
        XCTAssertEqual(request.timeZoneIdentifier, "America/New_York")
    }

    func testPastOrUnknownSlotsCannotBeBooked() {
        let store = AppointmentStore(userDefaults: nil)
        let vet = provider("luna", slots: [-hour, hour])

        XCTAssertThrowsError(try store.requestAppointment(with: vet, slot: vet.availableSlots[0], coverage: .selfPay, now: Fixtures.now)) {
            XCTAssertEqual($0 as? BookingError, .slotInPast)
        }
        XCTAssertThrowsError(try store.requestAppointment(with: vet, slot: Fixtures.now.addingTimeInterval(5 * hour), coverage: .selfPay, now: Fixtures.now)) {
            XCTAssertEqual($0 as? BookingError, .slotUnavailable)
        }
        XCTAssertTrue(store.requests.isEmpty)
    }

    func testRequestingTheSameSlotTwiceDoesNotDuplicate() throws {
        let store = AppointmentStore(userDefaults: nil)
        let vet = provider("luna", slots: [hour])

        let first = try store.requestAppointment(with: vet, slot: vet.availableSlots[0], coverage: .selfPay, now: Fixtures.now)
        let second = try store.requestAppointment(with: vet, slot: vet.availableSlots[0], coverage: .selfPay, now: Fixtures.now)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(store.requests.count, 1)
    }

    func testRequestsPersistAcrossLaunches() throws {
        let defaults = try Fixtures.isolatedDefaults()
        let vet = provider("luna", slots: [hour, 3 * hour])
        let saved = AppointmentStore(userDefaults: defaults)
        try saved.requestAppointment(with: vet, slot: vet.availableSlots[1], coverage: .insurance(.vsp), now: Fixtures.now)
        try saved.requestAppointment(with: vet, slot: vet.availableSlots[0], coverage: .selfPay, now: Fixtures.now)

        let relaunched = AppointmentStore(userDefaults: defaults)

        XCTAssertEqual(relaunched.requests.map(\.id), saved.requests.map(\.id))
        XCTAssertEqual(relaunched.requests.map(\.slot), saved.requests.map(\.slot))
        XCTAssertEqual(relaunched.requests.map(\.coverage), [.insurance(.vsp), .selfPay])
    }

    func testCorruptStorageLoadsEmptyInsteadOfCrashing() throws {
        let defaults = try Fixtures.isolatedDefaults()
        defaults.set(Data("{oops".utf8), forKey: AppointmentStore.storageKey)

        XCTAssertTrue(AppointmentStore(userDefaults: defaults).requests.isEmpty)
    }

    func testSectionsSortUpcomingSoonestFirstAndPastMostRecentFirst() throws {
        let store = AppointmentStore(userDefaults: nil)
        let vet = provider("luna", slots: [hour, 2 * hour, 30 * hour, 50 * hour])
        for slot in [vet.availableSlots[2], vet.availableSlots[0], vet.availableSlots[3], vet.availableSlots[1]] {
            try store.requestAppointment(with: vet, slot: slot, coverage: .selfPay, now: Fixtures.now)
        }

        let later = Fixtures.now.addingTimeInterval(24 * hour)
        let sections = store.sections(now: later)

        XCTAssertEqual(sections.upcoming.map(\.slot), [vet.availableSlots[2], vet.availableSlots[3]])
        XCTAssertEqual(sections.past.map(\.slot), [vet.availableSlots[1], vet.availableSlots[0]])
        XCTAssertFalse(sections.isEmpty)
        XCTAssertTrue(AppointmentStore(userDefaults: nil).sections(now: later).isEmpty)
    }

    func testAccessibilityLabelIncludesEveryVisibleField() throws {
        let store = AppointmentStore(userDefaults: nil)
        let vet = provider("luna", slots: [hour])
        let request = try store.requestAppointment(with: vet, slot: vet.availableSlots[0], coverage: .insurance(.vsp), now: Fixtures.now)

        let label = request.accessibilityLabel(locale: Locale(identifier: "en_US_POSIX"))

        for fragment in [vet.name, "Ophthalmology", "VSP", "Requested", "10:14"] {
            XCTAssertTrue(label.contains(fragment), "\(fragment) missing from \(label)")
        }
    }
}
