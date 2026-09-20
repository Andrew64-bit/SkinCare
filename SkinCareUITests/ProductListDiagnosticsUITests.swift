import XCTest

/// Diagnostica dell'audit di accessibilità (saltata salvo `TEST_RUNNER_SKINCARE_AUDIT_LAB=1`).
extension ProductListUITests {
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

    /// Diagnostica: stampa identificatori e valori delle prime miniature in modalità stub.
    func testDiagImageStates() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SKINCARE_AUDIT_LAB"] == "1", "diagnostica: SKINCARE_AUDIT_LAB=1")
        let app = XCUIApplication()
        app.launchEnvironment["SKINCARE_UITEST"] = "1"
        app.launch()
        sleep(8)
        let images = app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'image.'")).allElementsBoundByIndex
        var report = ["images: \(images.count)"]
        for image in images.prefix(6) {
            report.append("\(image.identifier) → value=\(String(describing: image.value)) label=\(image.label)")
        }
        let featuredPredicate = NSPredicate(format: "identifier BEGINSWITH 'product.featured.'")
        let featured = app.descendants(matching: .any).matching(featuredPredicate).firstMatch
        report.append("featured exists=\(featured.exists) label=\(featured.exists ? featured.label : "-")")
        XCTFail("DIAG\n" + report.joined(separator: "\n"))
    }
}
