import XCTest
@testable import DogtorMyEyes

final class SlotScheduleTests: XCTestCase {
    private var newYorkCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Fixtures.newYork
        return calendar
    }

    func testSlotsAreGeneratedRelativeToNowInClinicTime() throws {
        let templates = [SlotTemplate(dayOffset: 1, hour: 9, minute: 30), SlotTemplate(dayOffset: 3, hour: 16, minute: 0)]

        let slots = SlotSchedule.slots(from: templates, in: Fixtures.newYork, relativeTo: Fixtures.now)

        XCTAssertEqual(slots.count, 2)
        let first = newYorkCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: slots[0])
        XCTAssertEqual(first, DateComponents(year: 2026, month: 10, day: 28, hour: 9, minute: 30))
        let second = newYorkCalendar.dateComponents([.month, .day, .hour], from: slots[1])
        XCTAssertEqual(second, DateComponents(month: 10, day: 30, hour: 16))
    }

    func testSlotsShiftWithTheCurrentDate() throws {
        let templates = [SlotTemplate(dayOffset: 2, hour: 10, minute: 0)]
        let weekLater = Fixtures.now.addingTimeInterval(7 * 86_400)

        let today = SlotSchedule.slots(from: templates, in: Fixtures.newYork, relativeTo: Fixtures.now)
        let later = SlotSchedule.slots(from: templates, in: Fixtures.newYork, relativeTo: weekLater)

        // The window crosses the Nov 1 DST change, so compare clinic wall-clock time rather than raw intervals.
        let calendar = newYorkCalendar
        let todayParts = try XCTUnwrap(today.first.map { calendar.dateComponents([.day, .hour], from: $0) })
        let laterParts = try XCTUnwrap(later.first.map { calendar.dateComponents([.day, .hour], from: $0) })
        XCTAssertEqual(todayParts, DateComponents(day: 29, hour: 10))
        XCTAssertEqual(laterParts, DateComponents(day: 5, hour: 10))
    }

    func testPastAndInvalidTemplatesAreDropped() {
        // Fixtures.now is 09:14 in New York, so 08:00 today has already passed.
        let templates = [
            SlotTemplate(dayOffset: 0, hour: 8, minute: 0),
            SlotTemplate(dayOffset: 0, hour: 9, minute: 14),
            SlotTemplate(dayOffset: 0, hour: 15, minute: 0),
            SlotTemplate(dayOffset: -1, hour: 15, minute: 0),
            SlotTemplate(dayOffset: 1, hour: 25, minute: 0),
            SlotTemplate(dayOffset: 1, hour: 10, minute: 75),
        ]

        let slots = SlotSchedule.slots(from: templates, in: Fixtures.newYork, relativeTo: Fixtures.now)

        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(newYorkCalendar.component(.hour, from: slots[0]), 15)
        XCTAssertTrue(slots.allSatisfy { $0 > Fixtures.now })
    }

    func testUpcomingSlotsHidesSlotsThatPassAfterLaunch() {
        let past = Fixtures.now.addingTimeInterval(-60)
        let soon = Fixtures.now.addingTimeInterval(60)
        let provider = Fixtures.provider(id: "p", slots: [soon, past])

        XCTAssertEqual(provider.upcomingSlots(after: Fixtures.now), [soon])
        XCTAssertTrue(provider.upcomingSlots(after: soon).isEmpty)
        XCTAssertFalse(provider.isBookable(past, now: Fixtures.now))
        XCTAssertTrue(provider.isBookable(soon, now: Fixtures.now))
    }

    func testFormatterUsesClinicTimeZoneNotDeviceTimeZone() {
        // 13:30 UTC is 9:30 AM in New York; a device in UTC would otherwise show 1:30 PM.
        let slot = Date(timeIntervalSince1970: 1_793_107_800)
        let locale = Locale(identifier: "en_US_POSIX")

        let newYork = SlotFormatter.string(for: slot, in: Fixtures.newYork, locale: locale)
        let tokyo = SlotFormatter.string(for: slot, in: TimeZone(identifier: "Asia/Tokyo") ?? .current, locale: locale)

        XCTAssertTrue(newYork.contains("9:30"), newYork)
        XCTAssertTrue(tokyo.contains("10:30"), tokyo)
        XCTAssertNotEqual(newYork, tokyo)
    }

    func testBundledCatalogNeverExposesPastSlots() throws {
        let catalog = ProviderCatalog.decode(try Fixtures.bundledProvidersJSON(), now: Fixtures.now)
        let farFuture = Fixtures.now.addingTimeInterval(400 * 86_400)
        let later = ProviderCatalog.decode(try Fixtures.bundledProvidersJSON(), now: farFuture)

        for provider in catalog.providers + later.providers {
            XCTAssertTrue(provider.availableSlots.allSatisfy { $0 > Fixtures.now }, provider.id)
        }
        XCTAssertTrue(later.providers.contains { !$0.availableSlots.isEmpty }, "Relative slots should not go stale")
        XCTAssertTrue(catalog.providers.contains { $0.availableSlots.isEmpty }, "Fixture should include a no-openings provider")
    }
}
