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

    /// Attende che una miniatura sia caricata, da foto originale («loaded») o da ritaglio («loaded:cutout»).
    private func waitLoaded(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value == 'loaded' OR value == 'loaded:cutout'")
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 15)
        XCTAssertEqual(
            result, .completed, "\(element.identifier): non caricata (\(element.value ?? "nil"))", file: file, line: line
        )
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
            waitLoaded(image)
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
        waitLoaded(images(in: app).firstMatch)
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
        // Bar: la ricerca dell'app Contatti di sistema (stesso simulatore, contatti di esempio precaricati:
        // «ha» → Anna Haro, Hank Zakroff). Impostazioni non ha indice di ricerca nel simulatore e la ricerca
        // del sample Landmarks vive nella colonna laterale dello split view: nessuna delle due dà risultati.
        let bar = XCUIApplication(bundleIdentifier: "com.apple.MobileAddressBook")
        bar.launch()
        sleep(3)
        var barField = bar.searchFields.firstMatch
        if !barField.waitForExistence(timeout: 5) {
            bar.swipeDown()
            barField = bar.searchFields.firstMatch
        }
        XCTAssertTrue(barField.waitForExistence(timeout: 10), "ricerca del bar assente")
        barField.tap()
        barField.typeText("ha")
        sleep(3)
        attach(bar.screenshot(), name: "bar-search")
        barField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "zzzzqqqq")
        sleep(3)
        attach(bar.screenshot(), name: "bar-empty")
        bar.terminate()

        let ours = XCUIApplication()
        ours.launch() // nessuna variabile: rete reale, foto vere
        XCTAssertTrue(rows(in: ours).firstMatch.waitForExistence(timeout: 15))
        search("nivea", in: ours)
        sleep(6)
        attach(ours.screenshot(), name: "ours-search")
        clearSearch(in: ours)
        search("zzzzqqqq", in: ours)
        sleep(2)
        attach(ours.screenshot(), name: "ours-empty")
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - v0.3: Italia in evidenza e immagini ritagliate

    private func badges(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'product.badge.italy.'"))
    }

    func testItalianBadgeIsShownAndItalianProductsComeFirst() {
        let app = launch(.stubbed)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        let badge = badges(in: app).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 10), "nessun badge «Venduto in Italia» visibile")
        XCTAssertEqual(badge.label, "Venduto in Italia")
        // La prima riga di ogni schermata iniziale è italiana: il badge della prima riga esiste.
        let firstRow = rows(in: app).firstMatch
        let firstID = firstRow.identifier.replacingOccurrences(of: "product.row.", with: "")
        XCTAssertTrue(app.descendants(matching: .any)["product.badge.italy.\(firstID)"].exists,
                      "la prima riga (\(firstID)) non è italiana: l'ordine italiani-prima non è rispettato")
    }

    func testItalyFilterHidesNonItalianRows() {
        let app = launch(.stubbed)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        app.buttons["filter.menu"].tap()
        app.buttons["filter.italy"].tap()
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            for row in rows(in: app).allElementsBoundByIndex {
                let id = row.identifier.replacingOccurrences(of: "product.row.", with: "")
                XCTAssertTrue(app.descendants(matching: .any)["product.badge.italy.\(id)"].exists,
                              "riga non italiana visibile con il filtro attivo: \(id)")
            }
            app.swipeUp()
        }
        app.buttons["filter.menu"].tap()
        app.buttons["filter.all"].tap()
        XCTAssertGreaterThanOrEqual(distinctRows(in: app, minimum: 20).count, 20)
    }

    func testCutoutImagesLoadOnRowsThatHaveThem() {
        let app = launch(.stubbed)
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 10))
        // Le miniature con ritaglio espongono value «loaded:cutout»; i primi prodotti (italiani in cima) possono
        // non averne, quindi si scorre finché una compare (al massimo 8 schermate).
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'image.' AND value == 'loaded:cutout'")
        let cutout = app.images.matching(predicate).firstMatch
        var found = cutout.waitForExistence(timeout: 8)
        var swipes = 0
        while !found && swipes < 8 {
            app.swipeUp()
            swipes += 1
            found = cutout.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(found, "nessuna miniatura ritagliata caricata nelle prime \(swipes + 1) schermate")
    }
}
