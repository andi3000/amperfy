//
//  LogEntryTest.swift
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

@MainActor
class LogEntryTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    let context = cdHelper.createInMemoryManagedObjectContext()
    cdHelper.clearContext(context: context)
    library = LibraryStorage(context: context)
  }

  override func tearDown() {}

  func testDetailMessageDefaultsToNil() {
    let entry = library.createLogEntry()
    entry.message = "Something went wrong"
    XCTAssertNil(entry.detailMessage)
  }

  func testDetailMessageRoundTrips() {
    let entry = library.createLogEntry()
    entry.message = "Something went wrong"
    entry.detailMessage = "Track: Foo\nURL: https://example.com"
    XCTAssertEqual(entry.detailMessage, "Track: Foo\nURL: https://example.com")

    entry.detailMessage = nil
    XCTAssertNil(entry.detailMessage)
  }

  func testEncodingOmitsDetailMessageWhenNil() throws {
    let entry = library.createLogEntry()
    entry.message = "Short message"
    entry.statusCode = 2
    entry.type = .error

    let jsonString = entry.asJSONString()
    XCTAssertFalse(jsonString.contains("detailMessage"))
  }

  func testEncodingIncludesDetailMessageWhenSet() throws {
    let entry = library.createLogEntry()
    entry.message = "Short message"
    entry.detailMessage = "Long debug text with multiple\nlines"
    entry.statusCode = 2
    entry.type = .error

    let jsonString = entry.asJSONString()
    XCTAssertTrue(jsonString.contains("Long debug text"))
  }
}
