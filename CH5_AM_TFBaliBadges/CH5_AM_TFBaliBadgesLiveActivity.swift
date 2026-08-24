//
//  CH5_AM_TFBaliBadgesLiveActivity.swift
//  CH5_AM_TFBaliBadges
//
//  Created by Nurkahfi Rahmada on 12/08/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CH5_AM_TFBaliBadgesAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CH5_AM_TFBaliBadgesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CH5_AM_TFBaliBadgesAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension CH5_AM_TFBaliBadgesAttributes {
    fileprivate static var preview: CH5_AM_TFBaliBadgesAttributes {
        CH5_AM_TFBaliBadgesAttributes(name: "World")
    }
}

extension CH5_AM_TFBaliBadgesAttributes.ContentState {
    fileprivate static var smiley: CH5_AM_TFBaliBadgesAttributes.ContentState {
        CH5_AM_TFBaliBadgesAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CH5_AM_TFBaliBadgesAttributes.ContentState {
         CH5_AM_TFBaliBadgesAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CH5_AM_TFBaliBadgesAttributes.preview) {
   CH5_AM_TFBaliBadgesLiveActivity()
} contentStates: {
    CH5_AM_TFBaliBadgesAttributes.ContentState.smiley
    CH5_AM_TFBaliBadgesAttributes.ContentState.starEyes
}
