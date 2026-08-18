//
//  CH5_AM_TFBaliBadgesBundle.swift
//  CH5_AM_TFBaliBadges
//
//  Created by Nurkahfi Rahmada on 12/08/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

@main
struct CH5_AM_TFBaliBadgesBundle: WidgetBundle {
    var body: some Widget {
        RoutingActivityWidget()
    }
}

struct RoutingActivityWidget: Widget {
    let kind: String = "RoutingActivityWidget"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutingActivityAttributes.self) { context in
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.currentInstruction)
                            .font(.headline)
                        Text(context.state.currentDistance)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                if let next = context.state.nextInstruction {
                    Divider()
                    Text(next)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let landmark = context.state.nearbyLandmarkName {
                    Divider()
                    HStack {
                        Text("📍 \(landmark)")
                        Spacer()
                        Text("\(context.state.landmarkSide ?? "near") · \(context.state.landmarkDistance ?? "—")")
                    }
                    .font(.caption2)
                }

                if let transfer = context.state.transferSummary {
                    Divider()
                    Text(transfer)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.orange)
                } else if let nextStop = context.state.nextStopName {
                    Divider()
                    HStack {
                        Text("🚌 Next stop: \(nextStop)")
                        Spacer()
                    }
                    .font(.caption2)
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.currentInstruction)
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.currentDistance)
                        .font(.caption2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 2) {
                        Text(context.attributes.routeName)
                            .font(.caption2)
                        if let transfer = context.state.transferSummary {
                            Text(transfer)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.orange)
                        } else if let nextStop = context.state.nextStopName {
                            Text("Next stop: \(nextStop)")
                                .font(.caption2)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "arrow.right")
            } compactTrailing: {
                Text(context.state.currentDistance)
                    .font(.caption2)
            } minimal: {
                Image(systemName: "arrow.right")
            }
        }
    }
}
