//
//  EventLogDetailView.swift
//  Amperfy
//
//  Created by Claude on 07.10.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import AmperfyKit
import SwiftUI

struct EventLogDetailView: View {
  let entry: LogEntry

  var typeText: String {
    var typeLabelText = "\(entry.type.description)"
    if entry.type == .error, entry.statusCode > 1 {
      typeLabelText += " \(CommonString.oneMiddleDot) Status code \(entry.statusCode)"
    }
    return typeLabelText
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(typeText)
            .font(.caption)
            .foregroundColor(.secondary)
          Text("\(entry.creationDate.asIso8601String)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Text(entry.message)
          .font(.subheadline)
        if let detailMessage = entry.detailMessage {
          Divider()
          Text(detailMessage)
            .font(.system(.footnote, design: .monospaced))
            .textSelection(.enabled)
        }
      }
      .padding()
    }
    .navigationTitle("Event Log Entry")
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: {
          UIPasteboard.general.string = entry.detailMessage ?? entry.message
        }) {
          Image(uiImage: .clipboard)
        }
      }
    }
  }
}
