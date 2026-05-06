import Foundation
import Supabase

// ─────────────────────────────────────────────────────────────
// MARK: - Configuration
// Replace these two values with your Supabase project credentials.
// Dashboard → Settings → API
// ─────────────────────────────────────────────────────────────
enum SupabaseConfig {
    static let projectURL = URL(string: "https://jmwlizpemivsadimplsa.supabase.co")!
    static let anonKey    = "sb_publishable_F6P82ztNKJI8TErL565OgQ_tYK-cKcr"
    /// Base URL shown in sitter share links.
    static let sitterLinkBase = "https://snoot-web-zeta.vercel.app"
}

// ─────────────────────────────────────────────────────────────
// MARK: - SupabaseService singleton
// ─────────────────────────────────────────────────────────────
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.projectURL,
            supabaseKey: SupabaseConfig.anonKey
        )
    }

    // MARK: - Photo upload
    /// Uploads JPEG data to the dog-photos bucket and returns the public URL string.
    func uploadDogPhoto(data: Data, dogId: String) async throws -> String {
        let path = "\(dogId)/photo_\(Int(Date().timeIntervalSince1970)).jpg"
        try await client.storage
            .from("dog-photos")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try client.storage.from("dog-photos").getPublicURL(path: path)
        return publicURL.absoluteString
    }
}
