//
//  PlayerErrorDetails.swift
//  AmperfyKit
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

import Foundation

// MARK: - PlayerErrorDetails

/// Builds a human-readable, copyable debug text for a player error.
/// Only uses data the app already has at hand (no additional network request).
@MainActor
public struct PlayerErrorDetails {
  public static func create(
    error: Error?,
    playable: AbstractPlayable?,
    cleansedUrl: String?,
    playType: PlayType?,
    streamingMaxBitrate: StreamingMaxBitratePreference?,
    transcodingFormat: StreamingFormatPreference?,
    isOfflineMode: Bool,
    isPreload: Bool,
    fileManager: CacheFileManager
  )
    -> String {
    var sections = [String]()

    if let error {
      sections.append(errorSection(error: error))
    }
    if let playable {
      sections.append(trackSection(playable: playable))
      if let formatSection = formatSection(playable: playable) {
        sections.append(formatSection)
      }
      if let fileSection = fileSection(playable: playable, fileManager: fileManager) {
        sections.append(fileSection)
      }
      if let accountSection = accountSection(playable: playable) {
        sections.append(accountSection)
      }
    }
    sections.append(playbackSection(
      cleansedUrl: cleansedUrl,
      playType: playType,
      streamingMaxBitrate: streamingMaxBitrate,
      transcodingFormat: transcodingFormat,
      isOfflineMode: isOfflineMode,
      isPreload: isPreload
    ))

    return sections.joined(separator: "\n\n")
  }

  private static func errorSection(error: Error) -> String {
    var lines = ["Error: \(error.localizedDescription)"]
    let reflected = String(reflecting: error)
    if reflected != error.localizedDescription {
      lines.append("Error type: \(reflected)")
    }
    return lines.joined(separator: "\n")
  }

  private static func trackSection(playable: AbstractPlayable) -> String {
    var lines = ["Track:"]
    lines.append("  Title: \(playable.title)")
    if !playable.creatorName.isEmpty {
      lines.append("  Artist: \(playable.creatorName)")
    }
    if let album = playable.asSong?.album?.name, !album.isEmpty {
      lines.append("  Album: \(album)")
    }
    if playable.track > 0 {
      lines.append("  Track Nr.: \(playable.track)")
    }
    if playable.year > 0 {
      lines.append("  Year: \(playable.year)")
    }
    lines.append("  ID: \(playable.id)")
    lines.append("  Type: \(playableKind(playable: playable))")
    return lines.joined(separator: "\n")
  }

  private static func playableKind(playable: AbstractPlayable) -> String {
    if playable.isSong {
      return "Song"
    } else if playable.isPodcastEpisode {
      return "Podcast Episode"
    } else if playable.isRadio {
      return "Radio"
    } else {
      return "Unknown"
    }
  }

  private static func formatSection(playable: AbstractPlayable) -> String? {
    var lines = [String]()
    if let contentType = playable.contentType {
      lines.append("  Content-Type (server): \(contentType)")
    }
    if let transcoded = playable.contentTypeTranscoded {
      lines.append("  Content-Type (transcoded): \(transcoded)")
    }
    if let compatible = playable.iOsCompatibleContentType {
      lines.append("  Content-Type (used for playback): \(compatible)")
    }
    lines.append("  Playable on iOS: \(playable.isPlayableOniOS)")
    if playable.bitrate > 0 {
      lines.append("  Bitrate: \(playable.bitrate)")
    }
    if playable.size > 0 {
      lines.append("  Size (server): \(playable.size) bytes")
    }
    if playable.duration > 0 {
      lines.append("  Duration: \(playable.duration) s")
    }
    guard !lines.isEmpty else { return nil }
    return (["Format:"] + lines).joined(separator: "\n")
  }

  private static func fileSection(
    playable: AbstractPlayable,
    fileManager: CacheFileManager
  )
    -> String? {
    guard let relFilePath = playable.relFilePath else { return nil }
    var lines = [String]()
    lines.append("  Relative path: \(relFilePath.path)")
    lines.append("  File name: \(relFilePath.lastPathComponent)")
    let fileExtension = relFilePath.pathExtension
    if !fileExtension.isEmpty {
      lines.append("  File extension: \(fileExtension)")
    }
    let exists = fileManager.fileExits(relFilePath: relFilePath)
    lines.append("  File exists: \(exists)")
    if exists, let absUrl = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) {
      lines.append("  Absolute path: \(absUrl.path)")
      if let fileSize = fileManager.getFileSize(url: absUrl) {
        lines.append("  File size on disk: \(fileSize) bytes")
      }
    }
    return (["File:"] + lines).joined(separator: "\n")
  }

  private static func accountSection(playable: AbstractPlayable) -> String? {
    guard let account = playable.account else { return nil }
    var lines = [String]()
    if !account.serverUrl.isEmpty {
      lines.append("  Server URL: \(account.serverUrl)")
    }
    lines.append("  Backend API: \(account.apiType.description)")
    guard !lines.isEmpty else { return nil }
    return (["Account:"] + lines).joined(separator: "\n")
  }

  private static func playbackSection(
    cleansedUrl: String?,
    playType: PlayType?,
    streamingMaxBitrate: StreamingMaxBitratePreference?,
    transcodingFormat: StreamingFormatPreference?,
    isOfflineMode: Bool,
    isPreload: Bool
  )
    -> String {
    var lines = ["Playback:"]
    if let playType {
      lines.append("  Play type: \(playType == .stream ? "Stream" : "Cache")")
    }
    if let cleansedUrl, !cleansedUrl.isEmpty {
      lines.append("  URL: \(cleansedUrl)")
    }
    if let streamingMaxBitrate {
      lines.append("  Max bitrate: \(streamingMaxBitrate.description)")
    }
    if let transcodingFormat {
      lines.append("  Transcoding format: \(transcodingFormat.description)")
    }
    lines.append("  Offline mode: \(isOfflineMode)")
    lines.append("  Preload: \(isPreload)")
    return lines.joined(separator: "\n")
  }
}
