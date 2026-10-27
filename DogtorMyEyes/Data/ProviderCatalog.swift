import Foundation

/// Decodes each element independently so one malformed entry doesn't discard the rest.
struct LossyArray<Element: Decodable>: Decodable {
    private(set) var elements: [Element] = []
    private(set) var failures: [Error] = []

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            do {
                elements.append(try container.decode(Element.self))
            } catch {
                failures.append(error)
                // A failed decode doesn't advance the container; consume the element explicitly.
                _ = try container.decode(SkippedElement.self)
            }
        }
    }

    private struct SkippedElement: Decodable {
        init(from decoder: Decoder) throws {}
    }
}

/// On-disk shape of `providers.json`. Openings are templates so demo data never goes stale.
struct ProviderRecord: Decodable {
    let id: String
    let name: String
    let breed: String
    let specialty: Specialty
    let acceptedPlans: [InsurancePlan]
    let acceptsSelfPay: Bool
    let rating: Double
    let reviewCount: Int
    let distanceMiles: Double
    let bio: String
    let services: [String]
    let timeZoneIdentifier: String?
    let slotTemplates: [SlotTemplate]
    let avatarColor: String
    let droppedValueCount: Int

    private enum CodingKeys: String, CodingKey {
        case id, name, breed, specialty, acceptedPlans, acceptsSelfPay, rating, reviewCount
        case distanceMiles, bio, services, timeZone, slotTemplates, avatarColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        breed = try container.decode(String.self, forKey: .breed)
        specialty = try container.decode(Specialty.self, forKey: .specialty)
        rating = try container.decode(Double.self, forKey: .rating)
        reviewCount = try container.decode(Int.self, forKey: .reviewCount)
        distanceMiles = try container.decode(Double.self, forKey: .distanceMiles)
        acceptsSelfPay = try container.decodeIfPresent(Bool.self, forKey: .acceptsSelfPay) ?? true
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        services = try container.decodeIfPresent([String].self, forKey: .services) ?? []
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZone)
        avatarColor = try container.decodeIfPresent(String.self, forKey: .avatarColor) ?? ""

        let plans = try container.decodeIfPresent(LossyArray<InsurancePlan>.self, forKey: .acceptedPlans)
        let templates = try container.decodeIfPresent(LossyArray<SlotTemplate>.self, forKey: .slotTemplates)
        acceptedPlans = plans?.elements ?? []
        slotTemplates = templates?.elements ?? []
        droppedValueCount = (plans?.failures.count ?? 0) + (templates?.failures.count ?? 0)
    }

    func provider(relativeTo now: Date) -> Provider {
        let timeZone = timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? Provider.defaultClinicTimeZone
        return Provider(
            id: id,
            name: name,
            breed: breed,
            specialty: specialty,
            acceptedPlans: acceptedPlans,
            acceptsSelfPay: acceptsSelfPay,
            rating: rating,
            reviewCount: reviewCount,
            distanceMiles: distanceMiles,
            bio: bio,
            services: services,
            timeZone: timeZone,
            availableSlots: SlotSchedule.slots(from: slotTemplates, in: timeZone, relativeTo: now),
            avatarColor: avatarColor
        )
    }
}

struct ProviderCatalog: Equatable {
    var providers: [Provider]
    var skippedRecordCount: Int
    var errorMessage: String?

    static let empty = ProviderCatalog(providers: [], skippedRecordCount: 0, errorMessage: nil)

    static func decode(_ data: Data, now: Date) -> ProviderCatalog {
        do {
            let records = try JSONDecoder().decode(LossyArray<ProviderRecord>.self, from: data)
            for failure in records.failures {
                AppLog.data.error("Skipped provider record: \(String(describing: failure))")
            }
            let dropped = records.elements.reduce(0) { $0 + $1.droppedValueCount }
            if dropped > 0 {
                AppLog.data.error("Dropped \(dropped) unrecognized plan or slot values from providers.json")
            }
            let providers = records.elements.map { $0.provider(relativeTo: now) }
            let message = providers.isEmpty ? "No providers are available right now." : nil
            return ProviderCatalog(providers: providers, skippedRecordCount: records.failures.count, errorMessage: message)
        } catch {
            AppLog.data.error("providers.json is unreadable: \(String(describing: error))")
            return ProviderCatalog(
                providers: [],
                skippedRecordCount: 0,
                errorMessage: "The provider directory couldn’t be read. Please reinstall or update the app."
            )
        }
    }

    static func load(from bundle: Bundle, now: Date) -> ProviderCatalog {
        guard let url = bundle.url(forResource: "providers", withExtension: "json") else {
            AppLog.data.error("providers.json is missing from the app bundle")
            return ProviderCatalog(
                providers: [],
                skippedRecordCount: 0,
                errorMessage: "The provider directory is missing from this build."
            )
        }
        do {
            return decode(try Data(contentsOf: url), now: now)
        } catch {
            AppLog.data.error("providers.json could not be opened: \(String(describing: error))")
            return ProviderCatalog(
                providers: [],
                skippedRecordCount: 0,
                errorMessage: "The provider directory couldn’t be opened."
            )
        }
    }
}
