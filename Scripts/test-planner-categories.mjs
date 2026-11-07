#!/usr/bin/env node
// Runs the real category model/store without an app build or real preferences.
// The UI is intentionally excluded; adaptive colours use their light value here.
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const source = readFileSync(new URL('../Klimax/PlannerCategories.swift', import.meta.url), 'utf8');
const boundary = source.indexOf('/// The caller supplies the font, foreground style, and container dimensions.');
if (boundary < 0) throw new Error('Category model boundary changed; review this test harness.');
const model = source.slice(0, boundary);
const tests = String.raw`

// The live app supplies UIColor-backed light/dark adaptation in Theme.swift.
extension Color {
    static func adaptive(_ light: Color, _ dark: Color) -> Color { light }
}

final class VolatileDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    override func data(forKey defaultName: String) -> Data? { values[defaultName] as? Data }
    override func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
}

MainActor.assumeIsolated {
    var checks = 0
    func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
        guard condition() else { fatalError("FAIL: \(description)") }
        checks += 1
    }

    let defaults = VolatileDefaults()
    let store = PlannerCategoryStore(defaults: defaults)
    expect(store.categories.isEmpty, "New store is empty")
    expect(store.category(id: nil) == nil, "Nil ID has no category")
    expect(store.category(id: UUID()) == nil, "Unknown ID has no category")

    var family = PlannerCategory(name: "  Οἰκογένεια \n", symbol: "house.fill", emoji: "👨‍👩‍👧‍👦🌿", colorID: "sage")
    store.save(family)
    expect(store.categories.count == 1, "Saving adds one category")
    expect(store.category(id: family.id)?.name == "Οἰκογένεια", "Saved name is trimmed")
    expect(store.category(id: family.id)?.emoji == "👨‍👩‍👧‍👦", "Emoji truncation preserves family grapheme")
    expect(store.category(id: family.id)?.colorID == "sage", "Stable palette ID survives save")
    expect(defaults.data(forKey: "today.categories.v1") != nil, "Save encodes into injected defaults")

    let loaded = PlannerCategoryStore(defaults: defaults)
    expect(loaded.categories == store.categories, "New store decodes saved data")
    expect(loaded.categories[0].id == family.id, "Persistence retains category identity")
    expect(store.hasDuplicateName("οικογενεια"), "Duplicate matching ignores Greek accents and case")
    expect(!store.hasDuplicateName("Οἰκογένεια", excluding: family.id), "Editing self is not a duplicate")
    store.save(PlannerCategory(name: "ΟΙΚΟΓΕΝΕΙΑ", symbol: "heart.fill"))
    expect(store.categories.count == 1, "Duplicate name cannot create a second category")

    family.name = "Σπίτι"
    family.symbol = "heart.fill"
    family.emoji = ""
    family.colorID = "rose"
    store.save(family)
    expect(store.categories.count == 1, "Editing replaces rather than appends")
    expect(store.category(id: family.id)?.name == "Σπίτι", "Edited title is saved")
    expect(store.category(id: family.id)?.symbol == "heart.fill", "Edited symbol is saved")
    expect(store.category(id: family.id)?.emoji == "", "Switching from emoji to symbol clears emoji")
    expect(store.category(id: family.id)?.colorID == "rose", "Edited colour is saved")

    var second = PlannerCategory(name: "Δημιουργία", symbol: "", emoji: "word", colorID: "not-a-colour")
    store.save(second)
    expect(store.categories.count == 2, "A distinct category is reusable")
    expect(store.category(id: second.id)?.symbol == "sparkles", "Empty symbol gets safe fallback")
    expect(store.category(id: second.id)?.emoji == "", "Ordinary text cannot become an emoji")
    expect(store.category(id: second.id)?.colorID == "burgundy", "Unknown palette ID gets safe fallback")

    second.name = "σπιτι"
    store.save(second)
    expect(store.category(id: second.id)?.name == "Δημιουργία", "Cannot rename to another category's name")
    store.save(PlannerCategory(name: "  \n "))
    store.save(PlannerCategory(name: String(repeating: "a", count: 41)))
    expect(store.categories.count == 2, "Blank and overlong category names are rejected")
    expect(PlannerCategoryStore(defaults: defaults).categories == store.categories, "Re-edits survive reload")

    expect(PlannerCategory.singleEmoji(from: "  🇬🇷 🇨🇾 ") == "🇬🇷", "Flag stays one grapheme")
    expect(PlannerCategory.singleEmoji(from: "🙏🏽🌿") == "🙏🏽", "Skin-tone modifier stays attached")
    expect(PlannerCategory.singleEmoji(from: "1️⃣") == "1️⃣", "Keycap emoji remains valid")
    expect(PlannerCategory.singleEmoji(from: "1") == "", "Plain digit is not treated as emoji")
    expect(PlannerCategory.singleEmoji(from: "") == "", "Empty emoji remains empty")

    let corrupt = VolatileDefaults()
    corrupt.set(Data("not-json".utf8), forKey: "today.categories.v1")
    expect(PlannerCategoryStore(defaults: corrupt).categories.isEmpty, "Corrupt data fails safely")
    expect(Set(PlannerPalette.options.map(\.id)).count == PlannerPalette.options.count, "Palette IDs are unique")
    print("PASS: \(checks) planner category checks; no app preferences changed.")
}
`;

const cache = mkdtempSync(join(tmpdir(), 'klimax-planner-category-tests-'));
try {
    const result = spawnSync('xcrun', ['swift', '-module-cache-path', cache, '-'], {
        input: `${model}\n${tests}`,
        encoding: 'utf8',
        timeout: 120_000,
        maxBuffer: 2 * 1024 * 1024,
    });
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) throw result.error;
    process.exitCode = result.status ?? 1;
} finally {
    rmSync(cache, { recursive: true, force: true });
}
