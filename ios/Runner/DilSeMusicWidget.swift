import WidgetKit
import SwiftUI

struct MusicWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let artworkPath: String?
    let isPlaying: Bool
    let isShuffle: Bool
    let repeatMode: String
    let progressPercent: Int
    let currentTime: String
    let totalDuration: String
    let dominantColorHex: String
    let playlists: [WidgetPlaylistItem]
}

struct WidgetPlaylistItem: Identifiable {
    let id: String
    let title: String
    let artworkPath: String?
}

struct MusicWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MusicWidgetEntry {
        MusicWidgetEntry(
            date: Date(),
            title: "DilSe Music",
            artist: "Tap to play",
            artworkPath: nil,
            isPlaying: false,
            isShuffle: false,
            repeatMode: "off",
            progressPercent: 30,
            currentTime: "0:45",
            totalDuration: "3:30",
            dominantColorHex: "#14141E",
            playlists: defaultPlaylists()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MusicWidgetEntry) -> Void) {
        completion(loadCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MusicWidgetEntry>) -> Void) {
        let entry = loadCurrentEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func loadCurrentEntry() -> MusicWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.com.example.musicApp") ?? UserDefaults.standard
        let title = defaults.string(forKey: "title") ?? "DilSe Music"
        let artist = defaults.string(forKey: "artist") ?? "Tap to play"
        let artworkPath = defaults.string(forKey: "artwork_path")
        let isPlaying = defaults.bool(forKey: "is_playing")
        let isShuffle = defaults.bool(forKey: "is_shuffle")
        let repeatMode = defaults.string(forKey: "repeat_mode") ?? "off"
        let progressPercent = defaults.integer(forKey: "progress_percent")
        let currentTime = defaults.string(forKey: "current_time") ?? "0:00"
        let totalDuration = defaults.string(forKey: "total_duration") ?? "0:00"
        let dominantColorHex = defaults.string(forKey: "dominant_color_hex") ?? "#14141E"

        var playlists: [WidgetPlaylistItem] = []
        for i in 1...5 {
            let pId = defaults.string(forKey: "playlist_id_\(i)") ?? "playlist_\(i)"
            let pTitle = defaults.string(forKey: "playlist_title_\(i)") ?? "Mix \(i)"
            let pArt = defaults.string(forKey: "playlist_art_\(i)")
            playlists.append(WidgetPlaylistItem(id: pId, title: pTitle, artworkPath: pArt))
        }

        return MusicWidgetEntry(
            date: Date(),
            title: title,
            artist: artist,
            artworkPath: artworkPath,
            isPlaying: isPlaying,
            isShuffle: isShuffle,
            repeatMode: repeatMode,
            progressPercent: progressPercent,
            currentTime: currentTime,
            totalDuration: totalDuration,
            dominantColorHex: dominantColorHex,
            playlists: playlists
        )
    }

    private func defaultPlaylists() -> [WidgetPlaylistItem] {
        return [
            WidgetPlaylistItem(id: "liked", title: "Liked", artworkPath: nil),
            WidgetPlaylistItem(id: "global_top_50", title: "Top 50", artworkPath: nil),
            WidgetPlaylistItem(id: "trending_telugu", title: "Telugu", artworkPath: nil),
            WidgetPlaylistItem(id: "party_hits", title: "Party", artworkPath: nil),
            WidgetPlaylistItem(id: "chill_mix", title: "Chill", artworkPath: nil)
        ]
    }
}

struct DilSeMusicWidgetEntryView: View {
    var entry: MusicWidgetEntry

    var dominantColor: Color {
        Color(hex: entry.dominantColorHex)
    }

    var body: some View {
        ZStack {
            // Dynamic dominant color background with rounded gradient overlay
            dominantColor
            LinearGradient(
                colors: [Color.black.opacity(0.15), Color.black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 8) {
                // Top Section: Album Cover Left, Center Title/Artist, Controls & Scrubber Right
                HStack(alignment: .center, spacing: 12) {
                    // Album Cover on the Left
                    Link(destination: URL(string: "dilse://player")!) {
                        if let artPath = entry.artworkPath, let uiImage = UIImage(contentsOfFile: artPath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 82, height: 82)
                                .cornerRadius(14)
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 82, height: 82)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white.opacity(0.8))
                                )
                        }
                    }

                    // Right Side: Title, Artist, Controls, Scrubber
                    VStack(alignment: .center, spacing: 3) {
                        // Title Centered
                        Text(entry.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)

                        // Artist Name at bottom of Title with smaller font
                        Text(entry.artist)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                            .multilineTextAlignment(.center)

                        // Controls in exact order: 1. Shuffle, 2. Previous, 3. Play/Pause, 4. Next, 5. Repeat
                        HStack(spacing: 10) {
                            // 1. Shuffle
                            Link(destination: URL(string: "dilse://widget/shuffle")!) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(entry.isShuffle ? Color(hex: "#FF4B8B") : .white.opacity(0.7))
                            }

                            // 2. Previous
                            Link(destination: URL(string: "dilse://widget/previous")!) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            // 3. Play / Pause
                            Link(destination: URL(string: "dilse://widget/play_pause")!) {
                                Image(systemName: entry.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            // 4. Next
                            Link(destination: URL(string: "dilse://widget/next")!) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            // 5. Repeat
                            Link(destination: URL(string: "dilse://widget/repeat")!) {
                                Image(systemName: entry.repeatMode == "one" ? "repeat.1" : "repeat")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(entry.repeatMode != "off" ? Color(hex: "#FF4B8B") : .white.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 2)

                        // Responsive Scrubber below controls on right side
                        ProgressView(value: Double(min(max(entry.progressPercent, 0), 100)), total: 100.0)
                            .accentColor(Color(hex: "#FF4B8B"))
                            .scaleEffect(x: 1, y: 0.7, anchor: .center)

                        // Current elapsed time and total song duration
                        HStack {
                            Text(entry.currentTime)
                                .font(.system(size: 8.5, weight: .regular))
                                .foregroundColor(.white.opacity(0.65))
                            Spacer()
                            Text(entry.totalDuration)
                                .font(.system(size: 8.5, weight: .regular))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        .padding(.top, 1)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Bottom Section: Top 5 Playlists as app icon size across bottom of all things
                HStack(spacing: 8) {
                    ForEach(entry.playlists) { playlist in
                        let urlString = "dilse://playlist?id=\(playlist.id)&title=\(playlist.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                        Link(destination: URL(string: urlString)!) {
                            VStack(spacing: 2) {
                                if let artPath = playlist.artworkPath, let uiImage = UIImage(contentsOfFile: artPath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 36, height: 36)
                                        .cornerRadius(8)
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "music.note.list")
                                                .font(.system(size: 16))
                                                .foregroundColor(.white.opacity(0.8))
                                        )
                                }

                                Text(playlist.title)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                                    .frame(maxWidth: 52)
                            }
                        }
                    }
                }
            }
            .padding(10)
        }
    }
}

@main
struct DilSeMusicWidget: Widget {
    let kind: String = "DilSeMusicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MusicWidgetTimelineProvider()) { entry in
            DilSeMusicWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("DilSe Music")
        .description("Control music playback and launch your favorite playlists.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 20, 20, 30)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
