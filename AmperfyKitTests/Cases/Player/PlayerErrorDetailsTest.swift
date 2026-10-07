//
//  PlayerErrorDetailsTest.swift
//  AmperfyKitTests
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

@testable import AmperfyKit
import XCTest

// MARK: - PlayerErrorDetailsTestError

private enum PlayerErrorDetailsTestError: Error, LocalizedError {
  case sample

  var errorDescription: String? {
    "Couldn't parse the bytes from the stream. Status: The specified file type is not supported."
  }
}

// MARK: - PlayerErrorDetailsTest

@MainActor
class PlayerErrorDetailsTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    let context = cdHelper.createInMemoryManagedObjectContext()
    cdHelper.clearContext(context: context)
    library = LibraryStorage(context: context)
    account = library.getAccount(info: TestAccountInfo.create1())
    account.assignAccount(
      serverUrl: "https://music.example.com",
      userName: "testUser",
      apiType: .subsonic
    )
  }

  override func tearDown() {}

  private func createSong() -> Song {
    let artist = library.createArtist(account: account)
    artist.name = "Rick Astley"
    let album = library.createAlbum(account: account)
    album.name = "Whenever You Need Somebody"
    let song = library.createSong(account: account)
    song.id = "song-42"
    song.title = "Never Gonna Give You Up"
    song.track = 1
    song.year = 1987
    song.artist = artist
    song.album = album
    song.contentType = "audio/ogg"
    song.size = 123_456
    song.bitrate = 320
    return song
  }

  func testTrackAlbumAndFormatAreIncluded() {
    let song = createSong()

    let details = PlayerErrorDetails.create(
      error: PlayerErrorDetailsTestError.sample,
      playable: song,
      cleansedUrl: "https://music.example.com/rest/stream.view?id=42",
      playType: .stream,
      streamingMaxBitrate: .noLimit,
      transcodingFormat: .mp3,
      isOfflineMode: false,
      isPreload: false,
      fileManager: CacheFileManager.shared
    )

    XCTAssertTrue(details.contains("Never Gonna Give You Up"))
    XCTAssertTrue(details.contains("Rick Astley"))
    XCTAssertTrue(details.contains("Whenever You Need Somebody"))
    XCTAssertTrue(details.contains("song-42"))
    XCTAssertTrue(details.contains("audio/ogg"))
    XCTAssertTrue(details.contains("Song"))
    XCTAssertTrue(details.contains("Stream"))
    XCTAssertTrue(details.contains("music.example.com/rest/stream.view?id=42"))
    XCTAssertTrue(details.contains("Couldn't parse the bytes"))
    XCTAssertTrue(details.contains("Backend API: \(BackenApiType.subsonic.description)"))
  }

  func testUrlIsPassedThroughAlreadyCleansed() {
    // PlayerErrorDetails never cleanses the URL itself - the caller is
    // responsible for stripping credentials beforehand. This test documents
    // that a cleansed URL contains no password/token query items.
    let song = createSong()
    let cleansedUrl = "https://music.example.com/rest/stream.view?id=42&u=testUser"

    let details = PlayerErrorDetails.create(
      error: nil,
      playable: song,
      cleansedUrl: cleansedUrl,
      playType: .stream,
      streamingMaxBitrate: nil,
      transcodingFormat: nil,
      isOfflineMode: false,
      isPreload: false,
      fileManager: CacheFileManager.shared
    )

    XCTAssertFalse(details.contains("&p="))
    XCTAssertFalse(details.contains("&t="))
    XCTAssertFalse(details.contains("&s="))
    XCTAssertTrue(details.contains(cleansedUrl))
  }

  func testFileSectionForNonExistingCacheFile() {
    let song = createSong()
    song.relFilePath = URL(string: "songs/does-not-exist.mp3")

    let details = PlayerErrorDetails.create(
      error: nil,
      playable: song,
      cleansedUrl: nil,
      playType: .cache,
      streamingMaxBitrate: nil,
      transcodingFormat: nil,
      isOfflineMode: true,
      isPreload: false,
      fileManager: CacheFileManager.shared
    )

    XCTAssertTrue(details.contains("does-not-exist.mp3"))
    XCTAssertTrue(details.contains("File exists: false"))
    // the file does not exist, so no absolute path / size lines should appear
    XCTAssertFalse(details.contains("Absolute path"))
    XCTAssertFalse(details.contains("File size on disk"))
  }

  func testFileSectionForExistingCacheFile() throws {
    let song = createSong()
    let relFilePath = URL(string: "songs/player-error-details-test.mp3")!
    let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
    try CacheFileManager.shared.writeDataExcludedFromBackup(
      data: Data([0x00, 0x01, 0x02, 0x03]),
      to: absFilePath,
      accountInfo: account.info
    )
    defer { try? CacheFileManager.shared.removeItem(at: absFilePath, accountInfo: account.info) }
    song.relFilePath = relFilePath

    let details = PlayerErrorDetails.create(
      error: nil,
      playable: song,
      cleansedUrl: nil,
      playType: .cache,
      streamingMaxBitrate: nil,
      transcodingFormat: nil,
      isOfflineMode: true,
      isPreload: false,
      fileManager: CacheFileManager.shared
    )

    XCTAssertTrue(details.contains("File exists: true"))
    XCTAssertTrue(details.contains("Absolute path"))
    XCTAssertTrue(details.contains("File size on disk: 4 bytes"))
  }

  func testRadioWithoutFileDoesNotContainEmptyLines() {
    let radio = library.createRadio(account: account)
    radio.id = "radio-1"
    radio.title = "My Radio"
    radio.url = "https://stream.example.com/live"

    let details = PlayerErrorDetails.create(
      error: nil,
      playable: radio,
      cleansedUrl: radio.url,
      playType: .stream,
      streamingMaxBitrate: nil,
      transcodingFormat: nil,
      isOfflineMode: false,
      isPreload: true,
      fileManager: CacheFileManager.shared
    )

    XCTAssertTrue(details.contains("Radio"))
    XCTAssertTrue(details.contains("Preload: true"))
    XCTAssertFalse(details.contains("\n\n\n"))
    for line in details.components(separatedBy: "\n") {
      XCTAssertFalse(line.hasSuffix(": "), "found an empty value in line: \"\(line)\"")
    }
  }
}
