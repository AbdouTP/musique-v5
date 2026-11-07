import Foundation

/// Un titre de musique libre (Creative Commons) proposé au téléchargement.
struct OnlineTrack: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let downloadURL: URL
    let artworkURL: URL?
    let licenseLabel: String?
    let pageURL: URL?
}

enum CatalogError: LocalizedError {
    case missingKey
    case rejected(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Clé Jamendo manquante."
        case .rejected(let message): return "Jamendo a refusé la requête : \(message)"
        case .badResponse: return "Réponse inattendue du serveur."
        }
    }
}

enum NetworkErrorText {
    static func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut, .cannotConnectToHost, .cannotFindHost:
                return "Pas de connexion Internet. Seule la page Découvrir en a besoin : votre bibliothèque reste lisible hors connexion."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}

/// Lecture des réponses de l'API Jamendo (musique sous licence Creative Commons).
enum JamendoParser {
    private struct FlexibleString: Decodable {
        let value: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                value = string
            } else if let int = try? container.decode(Int.self) {
                value = String(int)
            } else {
                throw DecodingError.typeMismatch(
                    String.self,
                    .init(codingPath: decoder.codingPath, debugDescription: "Identifiant invalide")
                )
            }
        }
    }

    private struct Envelope: Decodable {
        let headers: Headers?
        let results: [Item]?
    }

    private struct Headers: Decodable {
        let status: String?
        let errorMessage: String?
    }

    private struct Item: Decodable {
        let id: FlexibleString
        let name: String?
        let duration: Int?
        let artistName: String?
        let albumName: String?
        let licenseCcurl: String?
        let albumImage: String?
        let image: String?
        let audiodownload: String?
        let audiodownloadAllowed: Bool?
        let shareurl: String?
    }

    static func parse(_ data: Data) throws -> [OnlineTrack] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope = try decoder.decode(Envelope.self, from: data)

        if let status = envelope.headers?.status, status != "success" {
            throw CatalogError.rejected(envelope.headers?.errorMessage ?? "requête invalide")
        }

        return (envelope.results ?? []).compactMap { item in
            guard item.audiodownloadAllowed != false,
                  let download = secureURL(item.audiodownload) else { return nil }
            let title = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return OnlineTrack(
                id: "jamendo:" + item.id.value,
                title: title.isEmpty ? "Sans titre" : title,
                artist: item.artistName ?? Track.unknownArtist,
                album: item.albumName ?? "",
                duration: Double(item.duration ?? 0),
                downloadURL: download,
                artworkURL: secureURL(item.albumImage) ?? secureURL(item.image),
                licenseLabel: licenseLabel(from: item.licenseCcurl),
                pageURL: secureURL(item.shareurl)
            )
        }
    }

    /// Force HTTPS (iOS bloque le HTTP non chiffré).
    static func secureURL(_ string: String?) -> URL? {
        guard let string, !string.isEmpty, var components = URLComponents(string: string) else { return nil }
        if components.scheme == "http" { components.scheme = "https" }
        guard components.scheme == "https" else { return nil }
        return components.url
    }

    /// "https://creativecommons.org/licenses/by-nc-sa/3.0/" → "CC BY-NC-SA 3.0"
    static func licenseLabel(from urlString: String?) -> String? {
        guard let urlString, let range = urlString.range(of: "/licenses/") else { return nil }
        let parts = urlString[range.upperBound...].split(separator: "/").map(String.init)
        guard let kind = parts.first, !kind.isEmpty else { return nil }
        var label = "CC " + kind.uppercased()
        if parts.count > 1 { label += " " + parts[1] }
        return label
    }
}

enum JamendoService {
    /// Recherche des titres téléchargeables. Sans requête : les titres les plus populaires du mois.
    static func search(query: String, clientID: String, limit: Int = 30) async throws -> [OnlineTrack] {
        let key = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw CatalogError.missingKey }

        var components = URLComponents(string: "https://api.jamendo.com/v3.0/tracks/")!
        var items = [
            URLQueryItem(name: "client_id", value: key),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "audiodownload_allowed", value: "true"),
            URLQueryItem(name: "imagesize", value: "300")
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            items.append(URLQueryItem(name: "order", value: "popularity_month"))
        } else {
            items.append(URLQueryItem(name: "search", value: trimmed))
        }
        components.queryItems = items

        guard let url = components.url else { throw CatalogError.badResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CatalogError.badResponse
        }
        return try JamendoParser.parse(data)
    }
}
