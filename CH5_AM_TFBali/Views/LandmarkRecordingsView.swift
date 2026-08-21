//
//  LandmarkRecordingsView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 18/08/26.
//

import SwiftUI
import SwiftData

struct LandmarkRecordingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let landmarkIndex: Int
    /// Set only when these recordings belong to a `Place` marking rather than a fixed
    /// Kuta-loop landmark — see the note on `LandmarkVideo.placeKey`.
    var placeKey: String? = nil
    let landmarkName: String
    let info: LandmarkInfo?
    let videosBaseDirectory: URL?

    @State private var recordings: [LandmarkVideo] = []
    @State private var playback: ClipPlayback?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.red.opacity(0.12))
                        Image(systemName: info?.icon ?? "mappin.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.red)
                    }
                    .frame(height: 140)

                    if let info {
                        Text(info.category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.red, in: Capsule())

                        Text(info.summary)
                            .font(.body)
                            .foregroundStyle(.primary)
                    } else {
                        Text("No information available for this landmark yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    markingsSection
                }
                .padding()
            }
            .navigationTitle(info?.title ?? landmarkName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Haptics.tap()
                        dismiss()
                    }
                }
            }
        }
        .task {
            loadRecordings()
        }
        .fullScreenCover(item: $playback) { playback in
            ClipPlayerView(title: playback.title, clips: playback.clips)
        }
    }

    @ViewBuilder
    private var markingsSection: some View {
        HStack {
            Text("Markings")
                .font(.subheadline.weight(.semibold))
            Spacer()
            if !recordings.isEmpty {
                Text("\(recordings.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green, in: Capsule())
            }
        }

        if recordings.isEmpty {
            Text("Not marked yet — get near this landmark on a route to record one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(recordings) { recording in
                    HStack {
                        Text(recording.recordedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }

            Button("Play Markings (\(recordings.count))") {
                Haptics.success()
                playback = ClipPlayback(title: info?.title ?? landmarkName, clips: clips())
            }
            .buttonStyle(.borderedProminent)
            .disabled(clips().isEmpty)
        }
    }

    /// Oldest first, so playback tells the landmark's story in the order it was marked —
    /// `recordings` itself stays newest-first for the list above.
    private func clips() -> [TripClip] {
        guard let videosBaseDirectory else { return [] }
        let directory = videosBaseDirectory.appendingPathComponent(LandmarkVideo.storageFolder(landmarkIndex: landmarkIndex, placeKey: placeKey), isDirectory: true)

        return recordings.sorted { $0.recordedAt < $1.recordedAt }.compactMap { recording in
            let url = directory.appendingPathComponent(recording.fileName)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return TripClip(name: recording.landmarkName, url: url)
        }
    }

    private func loadRecordings() {
        let index = landmarkIndex
        let key = placeKey
        let descriptor: FetchDescriptor<LandmarkVideo>
        if let key {
            descriptor = FetchDescriptor<LandmarkVideo>(
                predicate: #Predicate { $0.placeKey == key },
                sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<LandmarkVideo>(
                predicate: #Predicate { $0.landmarkIndex == index && $0.placeKey == nil },
                sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
            )
        }
        do {
            recordings = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load landmark recordings: \(error)")
        }
    }
}
