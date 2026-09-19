import XCTest

/// Test UI della lista prodotti. Modalità via launchEnvironment (mai argomenti con trattino):
/// `SKINCARE_UITEST=1` → store isolato, rete stubbata nel processo dell'app (catalogo remoto più nuovo
/// datato 2027-03-04, immagini generate); `SKINCARE_UITEST_NETWORK=deny` → ogni richiesta fallisce.
/// Raccoglie le issue dell'audit dentro la closure (che non può catturare il test case in Swift 6).
final class AuditIssueLog: @unchecked Sendable {
    var lines: [String] = []
}

final class ProductListUITests: XCTestCase {
    enum Mode { case stubbed, offline }

    private static let remoteGeneratedAt = "2027-03-04T00:00:00Z"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ mode: Mode, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SKINCARE_UITEST"] = "1"
        if mode == .offline {
            app.launchEnvironment["SKINCARE_UITEST_NETWORK"] = "deny"
        }
        app.launchArguments += arguments
        app.launch()
        return app
    }

    private func rows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'product.row.'"))
    }

    private func images(in app: XCUIApplication) -> XCUIElementQuery {
        app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'image.'"))
    }

    private func attribution(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["catalog.attribution"]
    }

    /// Scorre la lista raccogliendo gli identificatori delle righe finché ne vede almeno `minimum`.
    private func distinctRows(in app: XCUIApplication, minimum: Int) -> Set<String> {
        var seen = Set<String>()
        for _ in 0..<10 {
            for element in rows(in: app).allElementsBoundByIndex {
                seen.insert(element.identifier)
            }
            if seen.count >= minimum { break }
            app.swipeUp()
        }
        return seen
    }

    private func wait(for element: XCUIElement, value: String, timeout: TimeInterval = 15,
                      file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element.identifier): atteso value '\(value)', trovato '\(element.value ?? "nil")'",
                       file: file, line: line)
    }

    // MARK: - Lista e immagini

    func testListShowsAtLeastTwentyRows() {
        let app = launch(.stubbed)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(distinctRows(in: app, minimum: 20).count, 20)
    }

    func testFirstThreeImagesReachLoadedState() {
        let app = launch(.stubbed)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        let firstThree = Array(images(in: app).allElementsBoundByIndex.prefix(3))
        XCTAssertEqual(firstThree.count, 3)
        for image in firstThree {
            wait(for: image, value: "loaded")
        }
    }

    func testRemoteRefreshUpdatesAttributionDate() {
        let app = launch(.stubbed)
        XCTAssertTrue(attribution(in: app).waitForExistence(timeout: 10))
        wait(for: attribution(in: app), value: Self.remoteGeneratedAt)
    }

    // MARK: - Offline

    func testOfflineShowsBundledCatalogWithPlaceholders() {
        let app = launch(.offline)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        wait(for: images(in: app).firstMatch, value: "placeholder")
        XCTAssertGreaterThanOrEqual(distinctRows(in: app, minimum: 20).count, 20)
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Attribuzione

    func testAttributionLineAndSheet() {
        let app = launch(.stubbed)
        let line = attribution(in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 10))
        XCTAssertTrue(line.label.contains("Open Beauty Facts"), line.label)
        app.buttons["attribution.button"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["attribution.sheet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'ODbL'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'CC BY-SA 3.0'")).firstMatch.exists)
    }

    func testContextMenuOffersOpenBeautyFactsLink() {
        let app = launch(.stubbed)
        let first = rows(in: app).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Apri su Open Beauty Facts"].waitForExistence(timeout: 5))
    }

    // MARK: - Accessibilità

    func testAccessibilityAudit() throws {
        let app = launch(.stubbed)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        wait(for: images(in: app).firstMatch, value: "loaded")
        // Le issue vengono raccolte (return true = non registrate dall'audit) e riportate in un'unica
        // asserzione con tipo, descrizione ed elemento: così il fallimento dice sempre quale elemento è.
        let issues = AuditIssueLog()
        try app.performAccessibilityAudit { issue in
            issues.lines.append("type=\(issue.auditType) \(issue.compactDescription)\n\(issue.detailedDescription)"
                + "\nelement=\(issue.element.map { "\($0)" } ?? "nil")")
            return true
        }
        XCTAssertTrue(issues.lines.isEmpty, "Audit di accessibilità:\n" + issues.lines.joined(separator: "\n---\n"))
    }

    func testAccessibilityLargeTextKeepsFirstRowReadable() {
        let app = launch(.stubbed, arguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"
        ])
        let firstRow = rows(in: app).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        // Una riga più alta dello spazio rimasto può legittimamente proseguire sotto il bordo (la lista scorre):
        // ciò che deve essere vero è che la riga inizi sullo schermo e che il titolo sia interamente
        // visibile e dentro la riga.
        let window = app.windows.firstMatch.frame
        let rowFrame = firstRow.frame
        XCTAssertTrue(rowFrame.minY >= window.minY && rowFrame.minY < window.maxY - 44,
                      "riga \(rowFrame) non inizia sullo schermo \(window)")
        XCTAssertGreaterThan(rowFrame.height, 0)
        let title = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'product.name.'")).firstMatch
        XCTAssertTrue(title.exists)
        XCTAssertTrue(window.contains(title.frame), "titolo \(title.frame) fuori dallo schermo \(window)")
        XCTAssertTrue(rowFrame.insetBy(dx: -1, dy: -1).contains(title.frame),
                      "titolo \(title.frame) fuori dalla riga \(rowFrame)")
    }

    /// Diagnostica: audita una variante alla volta e stampa il rapporto (fallisce sempre, di proposito).
    func testAuditLab() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SKINCARE_AUDIT_LAB"] == "1", "diagnostica: SKINCARE_AUDIT_LAB=1")
        var report: [String] = []
        for variant in ["full", "compose:hRt"] {
            let app = XCUIApplication()
            app.launchEnvironment["SKINCARE_UITEST"] = "1"
            app.launchEnvironment["SKINCARE_UITEST_LAB"] = variant
            app.launch()
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
            sleep(2)
            let issues = AuditIssueLog()
            try app.performAccessibilityAudit { issue in
                issues.lines.append(issue.compactDescription)
                return true
            }
            report.append("\(variant): \(issues.lines.isEmpty ? "ok" : issues.lines.joined(separator: " | "))")
            app.terminate()
        }
        XCTFail("LAB REPORT\n" + report.joined(separator: "\n"))
    }

    /// Diagnostica: bisezione della lista reale per attribuire un'issue senza elemento.
    func testAuditBisect() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SKINCARE_AUDIT_LAB"] == "1", "diagnostica: SKINCARE_AUDIT_LAB=1")
        func audit(_ variant: String) throws -> [String] {
            let app = XCUIApplication()
            app.launchEnvironment["SKINCARE_UITEST"] = "1"
            app.launchEnvironment["SKINCARE_UITEST_LAB"] = variant
            app.launch()
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
            sleep(2)
            let issues = AuditIssueLog()
            try app.performAccessibilityAudit { issue in
                issues.lines.append(issue.compactDescription)
                return true
            }
            app.terminate()
            return issues.lines
        }
        var report: [String] = []
        var start = 0
        var count = 120
        let all = try audit("rows:\(start):\(count)")
        report.append("rows:\(start):\(count) → \(all)")
        if all.isEmpty {
            XCTFail("REPORT\n" + report.joined(separator: "\n") + "\nnessuna issue con le sole righe: composizione")
            return
        }
        while count > 1 {
            let half = count / 2
            let left = try audit("rows:\(start):\(half)")
            report.append("rows:\(start):\(half) → \(left)")
            if !left.isEmpty { count = half; continue }
            let right = try audit("rows:\(start + half):\(count - half)")
            report.append("rows:\(start + half):\(count - half) → \(right)")
            if !right.isEmpty { start += half; count -= half; continue }
            report.append("nessuna metà riproduce: dipende dal numero di righe o dallo scorrimento")
            break
        }
        XCTFail("REPORT\n" + report.joined(separator: "\n") + "\nrange finale: \(start):\(count)")
    }
}
