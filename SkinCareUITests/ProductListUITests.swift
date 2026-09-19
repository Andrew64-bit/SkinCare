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

    /// Digita nella barra di ricerca di sistema (la crea se serve toccandola).
    private func search(_ text: String, in app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "barra di ricerca assente")
        field.tap()
        field.typeText(text)
    }

    /// Svuota il campo con i tasti di cancellazione (indipendente dalla lingua del pulsante «Annulla»).
    private func clearSearch(in app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        guard field.exists else { return }
        field.tap()
        let length = (field.value as? String)?.count ?? 0
        if length > 0 {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: length + 2))
        }
    }

    private func featuredCards(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'product.featured.'"))
    }

    /// L'attribuzione è l'ultima sezione: con centinaia di righe non si raggiunge scorrendo, ma una ricerca
    /// senza risultati lascia in lista solo lo stato vuoto e la riga di attribuzione (obbligo di licenza in
    /// ogni stato).
    private func reachAttribution(in app: XCUIApplication) -> XCUIElement {
        search("zzzzqqqq", in: app)
        let line = attribution(in: app)
        _ = line.waitForExistence(timeout: 10)
        return line
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
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        // Il pulsante «i» espone la data del catalogo corrente: dopo il refresh dallo stub deve essere quella remota.
        wait(for: app.buttons["attribution.button"], value: Self.remoteGeneratedAt)
        let line = reachAttribution(in: app)
        XCTAssertTrue(line.exists)
        wait(for: line, value: Self.remoteGeneratedAt)
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
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        let line = reachAttribution(in: app)
        XCTAssertTrue(line.exists)
        XCTAssertTrue(line.label.contains("Open Beauty Facts"), line.label)
        // La riga stessa apre la scheda (il pulsante «i» della barra è nascosto mentre il campo di ricerca è attivo).
        line.tap()
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

    // MARK: - Ricerca

    func testSearchByBrandFiltersRows() {
        let app = launch(.stubbed)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(featuredCards(in: app).firstMatch.exists, "card in evidenza attesa prima della ricerca")
        search("Nivea", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["product.row.4005800001192"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["product.row.3600551020419"].exists, "Mixa non deve comparire")
        XCTAssertFalse(featuredCards(in: app).firstMatch.exists, "la card in evidenza sparisce durante la ricerca")
    }

    func testSearchMultiWordAndEmptyState() {
        let app = launch(.stubbed)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        search("nivea creme", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["product.row.4005800001192"].waitForExistence(timeout: 10))
        clearSearch(in: app)
        search("zzzzqqqq", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["search.empty"].waitForExistence(timeout: 10))
        XCTAssertFalse(rows(in: app).firstMatch.exists, "nessuna riga con una ricerca senza risultati")
    }

    func testCancelSearchRestoresList() {
        let app = launch(.stubbed)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        search("zzzzqqqq", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["search.empty"].waitForExistence(timeout: 10))
        clearSearch(in: app)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10), "righe assenti dopo aver svuotato la ricerca")
        XCTAssertGreaterThanOrEqual(distinctRows(in: app, minimum: 20).count, 20)
    }

    /// Catture per il gauntlet P6 (bar: ricerca del sample Landmarks; nostra: rete reale), come allegati.
    func testCaptureSearchScreens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SKINCARE_BAR_CAPTURE"] == "1", "catture: SKINCARE_BAR_CAPTURE=1")
        let bar = XCUIApplication(bundleIdentifier: "com.example.apple-samplecode.Landmarks")
        bar.launch()
        sleep(3)
        let back = bar.navigationBars.buttons.firstMatch
        if back.exists { back.tap() }
        let barField = bar.searchFields.firstMatch
        XCTAssertTrue(barField.waitForExistence(timeout: 10), "ricerca del bar assente")
        barField.tap()
        barField.typeText("Mount")
        sleep(3)
        attach(bar.screenshot(), name: "bar-search")
        bar.terminate()

        let ours = XCUIApplication()
        ours.launch() // nessuna variabile: rete reale, foto vere
        XCTAssertTrue(rows(in: ours).firstMatch.waitForExistence(timeout: 15))
        search("nivea", in: ours)
        sleep(6)
        attach(ours.screenshot(), name: "ours-search")
        search("", in: ours)
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
