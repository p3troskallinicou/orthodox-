//
//  LessonModels.swift
//  Klimax
//
//  Data model for a single lesson (teaching card + exercises + closing
//  apophthegm), matching the JSON schema of lesson_apotage_01.json.
//  Decodable only — the app never needs to re-encode a lesson.
//
//  Drop this file into the project alongside ContentModels.swift. It does
//  not touch Virtue/Saint/Teaching — those are untouched.
//

import Foundation

// MARK: - Exercise

enum ExerciseType: String, Decodable {
    case multipleChoice, readingPassage, trueFalse, fillBlank, match, order
}

enum LessonCardKind: String, Decodable, Hashable {
    case keimeno, erotisi, antistoixisi, seira, stoma, siopi
}

struct PatristicSource: Decodable, Hashable, Identifiable {
    let father: String
    let work: String
    let homily: String
    let pg: String

    var id: String { "\(father)|\(work)|\(homily)|\(pg)" }
}

struct ExerciseMetadata: Decodable, Hashable {
    let ektenis: String?
    let prototypo: String?
    let sources: [PatristicSource]
    let nodeId: String?
    let cardKind: LessonCardKind?

    static let empty = ExerciseMetadata(
        ektenis: nil,
        prototypo: nil,
        sources: [],
        nodeId: nil,
        cardKind: nil
    )

    var hasPatristicLayers: Bool {
        !(ektenis ?? "").isEmpty || !(prototypo ?? "").isEmpty
    }
}

struct MatchPair: Decodable, Hashable {
    let left: String
    let right: String
}

indirect enum Exercise: Identifiable, Hashable {
    case multipleChoice(id: String, prompt: String, options: [String], answerIndex: Int, explanation: String)
    case readingPassage(id: String, source: String, passage: String, gloss: String, question: String, options: [String], answerIndex: Int, explanation: String)
    case trueFalse(id: String, statement: String, answer: Bool, explanation: String)
    case fillBlank(id: String, textBefore: String, textAfter: String, answer: String, options: [String], explanation: String)
    case match(id: String, instruction: String, pairs: [MatchPair], explanation: String)
    case order(id: String, prompt: String, items: [String], explanation: String)
    case annotated(base: Exercise, metadata: ExerciseMetadata)

    var id: String {
        switch self {
        case .multipleChoice(let id, _, _, _, _): return id
        case .readingPassage(let id, _, _, _, _, _, _, _): return id
        case .trueFalse(let id, _, _, _): return id
        case .fillBlank(let id, _, _, _, _, _): return id
        case .match(let id, _, _, _): return id
        case .order(let id, _, _, _): return id
        case .annotated(let base, _): return base.id
        }
    }

    var metadata: ExerciseMetadata {
        if case .annotated(_, let metadata) = self { return metadata }
        return .empty
    }

    var unwrapped: Exercise {
        if case .annotated(let base, _) = self { return base.unwrapped }
        return self
    }

    var isGraded: Bool {
        switch metadata.cardKind {
        case .keimeno, .siopi: return false
        default: return true
        }
    }
}

extension Exercise: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, type, prompt, options, answerIndex, explanation
        case source, passage, gloss, question
        case statement, answer
        case textBefore, textAfter
        case instruction, pairs
        case items
        case ektenis, prototypo, sources, nodeId, cardKind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id)
        let type = try c.decode(ExerciseType.self, forKey: .type)
        let explanation = try c.decode(String.self, forKey: .explanation)
        let base: Exercise
        switch type {
        case .multipleChoice:
            base = .multipleChoice(
                id: id,
                prompt: try c.decode(String.self, forKey: .prompt),
                options: try c.decode([String].self, forKey: .options),
                answerIndex: try c.decode(Int.self, forKey: .answerIndex),
                explanation: explanation)
        case .readingPassage:
            base = .readingPassage(
                id: id,
                source: try c.decode(String.self, forKey: .source),
                passage: try c.decode(String.self, forKey: .passage),
                gloss: try c.decode(String.self, forKey: .gloss),
                question: try c.decode(String.self, forKey: .question),
                options: try c.decode([String].self, forKey: .options),
                answerIndex: try c.decode(Int.self, forKey: .answerIndex),
                explanation: explanation)
        case .trueFalse:
            base = .trueFalse(
                id: id,
                statement: try c.decode(String.self, forKey: .statement),
                answer: try c.decode(Bool.self, forKey: .answer),
                explanation: explanation)
        case .fillBlank:
            base = .fillBlank(
                id: id,
                textBefore: try c.decode(String.self, forKey: .textBefore),
                textAfter: try c.decode(String.self, forKey: .textAfter),
                answer: try c.decode(String.self, forKey: .answer),
                options: try c.decode([String].self, forKey: .options),
                explanation: explanation)
        case .match:
            base = .match(
                id: id,
                instruction: try c.decode(String.self, forKey: .instruction),
                pairs: try c.decode([MatchPair].self, forKey: .pairs),
                explanation: explanation)
        case .order:
            base = .order(
                id: id,
                prompt: try c.decode(String.self, forKey: .prompt),
                items: try c.decode([String].self, forKey: .items),
                explanation: explanation)
        }

        let metadata = ExerciseMetadata(
            ektenis: try c.decodeIfPresent(String.self, forKey: .ektenis),
            prototypo: try c.decodeIfPresent(String.self, forKey: .prototypo),
            sources: try c.decodeIfPresent([PatristicSource].self, forKey: .sources) ?? [],
            nodeId: try c.decodeIfPresent(String.self, forKey: .nodeId),
            cardKind: try c.decodeIfPresent(LessonCardKind.self, forKey: .cardKind)
        )

        self = metadata == .empty ? base : .annotated(base: base, metadata: metadata)
    }
}

// MARK: - Bible course packages

struct BibleMemoryNode: Decodable, Hashable, Identifiable {
    let id: String
    let kind: String
    let statement: String
    let martyriaId: String?
}

struct BibleChapterLesson: Decodable, Hashable, Identifiable {
    let id: String
    let unitId: String
    let order: Int
    let title: String
    let cards: [Exercise]
}

struct BibleChapterUnit: Decodable, Hashable, Identifiable {
    let id: String
    let book: String
    let chapter: Int
    let verses: [Int]
    let title: String
    let liturgical: String
    let lessons: [BibleChapterLesson]
}

struct BibleChapterPackage: Decodable {
    let schemaVersion: String
    let book: String
    let bookTitle: String
    let chapter: Int
    let chapterTitle: String
    let sourceText: String
    let reviewStatus: String
    let verified: Bool
    let nodes: [BibleMemoryNode]
    let units: [BibleChapterUnit]
}

// MARK: - Lesson

/// Named LessonTeaching (not "Teaching") because ContentModels.swift already
/// defines a different, unrelated 'Teaching' type for saints' teachings.
struct LessonTeaching: Decodable, Hashable {
    let title: String
    let body: String
    let sources: [String]
}

struct Closing: Decodable, Hashable {
    let type: String
    let text: String
    let gloss: String
    let source: String
}

struct LessonUnit: Decodable, Hashable {
    let id: String
    let rung: Int
    let numeral: String
    let virtue: String
    let title: String
    let source: String
}

struct LessonContent: Decodable, Hashable, Identifiable {
    let id: String
    let index: Int
    let title: String
    let teaching: LessonTeaching
    let exercises: [Exercise]
    let closing: Closing
    let xp: Int
}

struct LessonPackage: Decodable {
    let schemaVersion: String
    let track: String
    let unit: LessonUnit
    let lesson: LessonContent
}

// MARK: - Sample data (the real, approved Ἀποταγή Μάθημα 1 — for Previews & testing)

extension LessonContent {
    static let sampleApotage = LessonContent(
        id: "ladder-01-apotage-lesson-01",
        index: 1,
        title: "Τὸ κίνητρο",
        teaching: LessonTeaching(
            title: "Τὸ κίνητρο",
            body: "Τὸ ἴδιο καλὸ μπορεῖ νὰ γίνει ἀπὸ τρεῖς ἐντελῶς διαφορετικὲς ρίζες: φόβο, ἀνταμοιβή, ἀγάπη. Μόνο ἡ μία κρατάει καὶ σὲ ἀλλάζει στ’ ἀλήθεια. Οἱ πιὸ πολλοὶ ζοῦμε στὶς δύο πρῶτες χωρὶς νὰ τὸ καταλαβαίνουμε. Σκοπὸς δὲν εἶναι νὰ πιέσεις τὸν ἑαυτό σου στὴν ἀγάπη, ἀλλὰ νὰ πάψεις νὰ περνᾶς τὶς ἄλλες δύο γι’ αὐτήν.",
            sources: ["Κλῖμαξ, Λόγος Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Δύο φίλοι ξεκινοῦν τὸ ἴδιο καλό, νηστεία καὶ προσευχή. Ὁ ἕνας τὸ κρατᾶ γιὰ χρόνια, ὁ ἄλλος τὸ παρατᾶ σὲ λίγους μῆνες. Ποιὰ εἶναι ἡ πιθανότερη διαφορὰ μεταξύ τους;",
                options: [
                    "Ὁ ἕνας εἶχε πιὸ δυνατὴ θέληση ἀπ’ τὸν ἄλλο.",
                    "Ὁ ἕνας εἶχε περισσότερο χρόνο καὶ λιγότερες ὑποχρεώσεις.",
                    "Οἱ δυό τους τὸ ξεκίνησαν γιὰ διαφορετικὸ λόγο μέσα τους.",
                    "Ὁ ἕνας ἦταν πιὸ πιστὸς ἀπ’ τὴν ἀρχή."
                ],
                answerIndex: 2,
                explanation: "Δὲν σὲ κρατᾶ ἡ θέληση οὔτε ὁ χρόνος. Σὲ κρατᾶ ἢ σὲ ἀφήνει ὁ λόγος γιὰ τὸν ὁποῖο ξεκίνησες. Αὐτὸ εἶναι τὸ κίνητρο, καὶ εἶναι τὸ θέμα ὅλου τοῦ βήματος."
            ),
            .readingPassage(
                id: "ex2",
                source: "Κλῖμαξ, Λόγος Α´",
                passage: "Ὁ μὲν ἐκ φόβου τὴν ὑποταγὴν ποιησάμενος, ἴσως τῷ καιομένῳ θυμιάματι προσέοικεν, ἐν ἀρχαῖς μὲν ἐξ εὐωδίας ἀρξάμενον, ὕστερον δὲ εἰς καπνὸν καταλῆξαν· ὁ δὲ ἐκ μισθοῦ, ὀνικὸς μύλος καθίσταται· ὁ δὲ ἐξ ἀγάπης θείας τὴν ἀναχώρησιν ποιούμενος, εὐθέως πῦρ ἐν προοιμίοις κέκτηται.",
                gloss: "Ὅποιος ξεκινᾶ ἀπὸ φόβο μοιάζει μὲ θυμίαμα ποὺ σβήνει σὲ καπνό· ἀπὸ ἀνταμοιβὴ μοιάζει μὲ ζῶο ποὺ γυρίζει μονότονα τὸν μύλο· ἀπὸ ἀγάπη ἔχει φωτιὰ ἀπ’ τὴν ἀρχή.",
                question: "Ἀπ’ τὴν εἰκόνα τοῦ ἁγίου, τί ἰσχύει γιὰ τὸν φόβο ὡς κίνητρο στὴ ζωή σου;",
                options: [
                    "Εἶναι κακὸς καὶ πρέπει νὰ τὸν διώξεις ἀμέσως.",
                    "Ξεκινᾶ καλὰ σὰν εὐωδία, ἀλλὰ μόνος του σβήνει· εἶναι ἀρχή, ὄχι τέλος.",
                    "Εἶναι τὸ σταθερότερο κίνητρο, γιατὶ ὁ φόβος δὲν φεύγει ποτέ.",
                    "Δὲν ἔχει καμία ἀξία στὴν πνευματικὴ ζωή."
                ],
                answerIndex: 1,
                explanation: "Ὁ ἅγιος δὲν πετᾶ τὸν φόβο, τὸν βάζει χαμηλά. Εἶναι μιὰ τίμια ἀρχή, ἀλλὰ ξεθυμαίνει. Ἂν ξεκίνησες ἀπὸ φόβο ἢ ἐνοχή, δὲν εἶσαι σὲ λάθος δρόμο· ἁπλῶς μὴ μείνεις ἐκεῖ."
            ),
            .multipleChoice(
                id: "ex3",
                prompt: "Κάνεις τὸ σωστό, μὰ παρατηρεῖς ὅτι τὸ κάνεις πιὸ πρόθυμα ὅταν κάποιος τὸ βλέπει ἢ θὰ σὲ ἐπαινέσει. Μὲ τὴ γλώσσα τοῦ ἁγίου, ποιὸ κίνητρο κινεῖται ἐδῶ;",
                options: [
                    "Ἡ φωτιά: ἀγαπᾶς αὐτὸ ποὺ κάνεις.",
                    "Τὸ θυμίαμα: φόβος μὴν κατακριθεῖς.",
                    "Ὁ μύλος: κινεῖσαι ἀπὸ ἀνταμοιβὴ καὶ ἀναγνώριση.",
                    "Κανένα: εἶναι φυσικὸ καὶ δὲν σημαίνει τίποτα."
                ],
                answerIndex: 2,
                explanation: "Ὁ μύλος γυρίζει ἀτέλειωτα καὶ μένει στὸ ἴδιο σημεῖο. Ἡ προσπάθεια ποὺ τρέφεται ἀπ’ τὸ βλέμμα τῶν ἄλλων σταματᾶ μόλις φύγει τὸ βλέμμα, καὶ δὲν ἀλλάζει τὴν καρδιά. Δὲν εἶναι κατηγορία, εἶναι κάτι ποὺ ὅλοι τὸ ζοῦμε."
            ),
            .multipleChoice(
                id: "ex4",
                prompt: "Πῶς ξεχωρίζεις ὅτι κάτι τὸ κάνεις ἀπὸ ἀγάπη κι ὄχι ἀπὸ φόβο ἢ ἀνταμοιβή;",
                options: [
                    "Ὅταν τὸ κάνεις τέλεια, χωρὶς κανένα λάθος.",
                    "Ὅταν συνεχίζεις τὸ ἴδιο κι ὅταν κανείς δὲν βλέπει.",
                    "Ὅταν νιώθεις πάντα ὄμορφα συναισθήματα ἐνῶ τὸ κάνεις.",
                    "Ὅταν οἱ ἄλλοι ἀναγνωρίζουν πόσο καλὸς εἶσαι."
                ],
                answerIndex: 1,
                explanation: "Ἡ ἀγάπη δὲν εἶναι ἡ τελειότητα οὔτε τὸ εὐχάριστο συναίσθημα. Εἶναι ἡ φωτιὰ ποὺ καίει καὶ στὸ σκοτάδι, ὅταν κανείς δὲν βλέπει καὶ τίποτα δὲν κερδίζεις. Αὐτὸ εἶναι τὸ κριτήριο."
            ),
            .trueFalse(
                id: "ex5",
                statement: "Γιὰ νὰ φτάσω στὴν ἀγάπη, πρέπει νὰ πιέσω τὸν ἑαυτό μου νὰ νιώσει ἀγάπη.",
                answer: false,
                explanation: "Ἡ ἀγάπη δὲν βγαίνει μὲ πίεση. Ξεκινᾶς ἀπ’ ὅπου εἶσαι, ἀκόμη κι ἀπ’ τὸν φόβο, καὶ σταματᾶς νὰ περνᾶς τὸν φόβο καὶ τὴν ἀνταμοιβὴ γιὰ ἀγάπη. Ἡ φωτιὰ ἀνάβει μόνη της ὅταν τῆς ἀνοίξεις χῶρο."
            ),
            .multipleChoice(
                id: "ex6",
                prompt: "Τὸ πρῶτο βῆμα μετὰ ἀπ’ αὐτὸ τὸ μάθημα δὲν εἶναι νὰ ἀλλάξεις τί κάνεις, ἀλλὰ νὰ κάνεις τί;",
                options: [
                    "Νὰ δεῖς ἀπὸ ποιὸ κίνητρο τὸ κάνεις.",
                    "Νὰ κάνεις περισσότερα καλά.",
                    "Νὰ τὰ κάνεις ὅλα τέλεια.",
                    "Νὰ σταματήσεις νὰ κάνεις λάθη."
                ],
                answerIndex: 0,
                explanation: "Ἡ ἀλλαγὴ ξεκινᾶ ἀπ’ τὴν ἐπίγνωση. Πρῶτα βλέπεις καθαρὰ τὸ κίνητρο· ὕστερα, ἥσυχα, ἀρχίζει νὰ ἀλλάζει μόνο του."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Ὁ φόβος ἀνάβει καὶ σβήνει. Ἡ ἀνταμοιβὴ σὲ κρατᾶ σὲ κίνηση καὶ ἀκίνητο. Μόνο ἡ ἀγάπη ἔχει φωτιὰ ἀπ’ τὴν ἀρχή.",
            gloss: "Μὴν κυνηγᾶς τὴν ἀγάπη μὲ πίεση. Δὲς πρῶτα ποιὸ κίνητρο ἔχεις τώρα, καὶ ἄφησε τὴ φωτιὰ νὰ ἀνάψει.",
            source: "Κλῖμαξ, Λόγος Α´"
        ),
        xp: 20
    )
}

extension LessonContent {
    static let apotageLesson2 = LessonContent(
        id: "ladder-01-apotage-lesson-02",
        index: 2,
        title: "Ποῦ στέκεσαι",
        teaching: LessonTeaching(
            title: "Ποῦ στέκεσαι",
            body: "Ὁ ἅγιος Ἰωάννης ἀνοίγει τὸν Λόγο του μὲ μιὰ κατάταξη: ὅλοι στέκονται ἀπέναντι στὸν Θεὸ ὡς φίλοι, γνήσιοι δοῦλοι, ἀχρεῖοι δοῦλοι, ξένοι, ἢ ἐχθροί. Δὲν εἶναι ἐργαλεῖο γιὰ νὰ κρίνεις ἄλλους, εἶναι καθρέφτης γιὰ νὰ δεῖς ποῦ στέκεσαι ἐσύ. Καὶ ὁ Θεός, λέει, εἶναι «ζωὴ πάντων», χωρὶς προσωποληψία: ἡ πόρτα εἶναι ἀνοιχτὴ γιὰ κάθε τύπο ἀνθρώπου, ὅπου κι ἂν εἶναι τώρα.",
            sources: ["Κλῖμαξ, Λόγος Α´"]
        ),
        exercises: [
            .readingPassage(
                id: "ex1",
                source: "Κλῖμαξ, Λόγος Α´",
                passage: "Πάντων τῶν προαιρουμένων ὁ Θεὸς πάντων ἡ ζωή· πάντων ἡ σωτηρία πιστῶν, ἀπίστων· δικαίων, ἀδίκων· εὐσεβῶν, ἀσεβῶν· μοναχῶν, κοσμικῶν· σοφῶν, ἰδιωτῶν. Οὐ γὰρ προσωποληψία παρὰ Θεῷ.",
                gloss: "Γιὰ ὅλους ὅσους τὸ θέλουν, ὁ Θεὸς εἶναι ἡ ζωὴ καὶ ἡ σωτηρία τῶν πάντων, πιστῶν καὶ ἀπίστων, δικαίων καὶ ἀδίκων, μοναχῶν καὶ κοσμικῶν, σοφῶν καὶ ἁπλῶν. Διότι ὁ Θεὸς δὲν κάνει διακρίσεις προσώπων.",
                question: "Ἕνας φίλος διαβάζει τὸ χωρίο καὶ λέει: «ἄρα δὲν ἔχει σημασία πῶς ζεῖς, ὅλοι σώζονται». Ποῦ εἶναι τὸ λάθος του;",
                options: [
                    "Δὲν ὑπάρχει λάθος, αὐτὸ ἀκριβῶς λέει τὸ κείμενο.",
                    "Τὸ λάθος εἶναι ὅτι ὁ Θεὸς σώζει μόνο ὅσους πιστεύουν σωστά.",
                    "Μιλᾶ γιὰ τὴν προσφορὰ τοῦ Θεοῦ σὲ ὅλους, ὄχι γιὰ τὸ ἀποτέλεσμα.",
                    "Εἶναι θέμα ἑρμηνείας, δὲν βγαίνει ἄκρη."
                ],
                answerIndex: 2,
                explanation: "Ἡ φράση «πάντων ἡ σωτηρία» δείχνει ὅτι ὁ Θεὸς προσφέρεται σὲ ὅλους, χωρὶς νὰ ξεχωρίζει πρόσωπα. Προσφορὰ ὅμως δὲν σημαίνει ἐξαναγκασμός: ἡ πόρτα εἶναι ἀνοιχτὴ γιὰ ὅλους, ὁ καθένας ὅμως τὴν περνᾶ μόνος του. Οὔτε «ὅλοι σώζονται αὐτόματα» λέει, οὔτε «μόνο οἱ δικοί μας»."
            ),
            .multipleChoice(
                id: "ex2",
                prompt: "Διαβάζεις τὴν κατάταξη (φίλος, δοῦλος, ἀχρεῖος, ξένος, ἐχθρός) καὶ ἀμέσως σκέφτεσαι σὲ ποιά ἀνήκει ὁ καθένας γύρω σου. Τί φανερώνει αὐτὴ ἡ πρώτη σου κίνηση;",
                options: [
                    "Ὅτι κατάλαβες σωστὰ τὸν σκοπὸ τῆς κατάταξης.",
                    "Ὅτι ἔχεις διάκριση καὶ ξέρεις νὰ κρίνεις χαρακτῆρες.",
                    "Ὅτι ξέφυγες ἀπ' τὸ μόνο πρόσωπο ποὺ σὲ ἀφορᾶ, τὸν ἑαυτό σου.",
                    "Ὅτι πραγματικὰ νοιάζεσαι γιὰ τοὺς ἄλλους."
                ],
                answerIndex: 2,
                explanation: "Ἡ κατάταξη εἶναι καθρέφτης, ὄχι ζυγαριὰ γιὰ τοὺς ἄλλους. Ἡ αὐτόματη στροφὴ στὸ «ποιοὶ εἶναι οἱ ἄλλοι» εἶναι ὁ πιὸ κομψὸς τρόπος νὰ ἀποφύγεις τὴ μόνη ἐρώτηση ποὺ μετράει, τὸ ποῦ εἶμαι ἐγώ. Ἡ διάκριση καὶ τὸ νοιάξιμο ἀκούγονται ὡραῖα, μὰ ἐδῶ εἶναι πρόσχημα."
            ),
            .match(
                id: "ex3",
                instruction: "Ταίριαξε κάθε καθημερινὴ στάση μὲ αὐτὸ ποὺ φανερώνει γιὰ τὸ ποῦ στέκεσαι.",
                pairs: [
                    MatchPair(left: "Κάνω τὸ καλὸ πιὸ πρόθυμα ὅταν μὲ βλέπουν", right: "Στηρίζομαι στὸ βλέμμα τῶν ἄλλων"),
                    MatchPair(left: "Λέω «εἶμαι πιστὸς» μὰ δὲν τὸ ζῶ", right: "Ἀναπαύομαι στὴν ταμπέλα"),
                    MatchPair(left: "Παλεύω, πέφτω, ξανασηκώνομαι", right: "Εἶμαι μέσα στὸν δρόμο, ὄχι ἔξω")
                ],
                explanation: "Καμία στάση δὲν σὲ κλειδώνει κάπου γιὰ πάντα. Οἱ δύο πρῶτες δείχνουν ποῦ γλιστρᾶς· ἡ τρίτη ὅτι, ὅσο κι ἂν πέφτεις, ὅσο παλεύεις εἶσαι ἀκόμη μέσα στὴν πορεία."
            ),
            .order(
                id: "ex4",
                prompt: "Βάλε σὲ σειρὰ πῶς γλιστράει κανεὶς σιγὰ σιγὰ ἀπ' τὸ νὰ ζεῖ τὴν πίστη στὸ νὰ κρατᾶ μόνο τὸ ὄνομά της.",
                items: [
                    "Ζῶ αὐτὸ ποὺ πιστεύω, μὲ κόπο",
                    "Κρατῶ τοὺς τύπους, χαλαρώνω τὴν οὐσία",
                    "Μοῦ ἀρκεῖ ποὺ λέγομαι πιστός",
                    "Ξεχνῶ ὅτι ὑπῆρχε καὶ οὐσία"
                ],
                explanation: "Ἡ πτώση σπάνια εἶναι ἀπότομη. Πρῶτα χαλαρώνει ἡ οὐσία πίσω ἀπ' τοὺς τύπους, μετὰ ἀρκεῖ τὸ ὄνομα, καὶ στὸ τέλος ξεχνιέται ὅτι ὑπῆρχε κάτι βαθύτερο. Ὅποιος τὸ ἀναγνωρίζει νωρὶς προλαβαίνει."
            ),
            .trueFalse(
                id: "ex5",
                statement: "Ἀφοῦ ὁ Θεὸς δέχεται καὶ τὸν φόβο καὶ τὴν ἐνοχὴ ὡς ἀφορμή, ὅλες οἱ ἀφορμὲς εἶναι τὸ ἴδιο καλές.",
                answer: false,
                explanation: "Καὶ οἱ τρεῖς ἀφορμὲς (φόβος, συναίσθηση λαθῶν, ἀγάπη) εἶναι ἀληθινὲς πόρτες, ἀλλὰ ὄχι ἰσάξιες. Ὅπως εἶδες στὸ πρῶτο μάθημα, ὁ φόβος εἶναι ἀρχή, ἡ ἀγάπη τέλος. Καλὸ νὰ ξεκινᾶς ἀπ' ὅπου εἶσαι, μὰ ὄχι νὰ μένεις ἐκεῖ."
            ),
            .fillBlank(
                id: "ex6",
                textBefore: "Ἡ θέση μου ἀπέναντι στὸν Θεὸ σήμερα εἶναι",
                textAfter: ", ὄχι ἡ μόνιμη ταυτότητά μου.",
                answer: "ἀφετηρία",
                options: ["ἀφετηρία", "ἐτικέτα", "καταδίκη", "ἀνταμοιβή"],
                explanation: "Ὅπου κι ἂν στέκεσαι, εἶναι σημεῖο ἐκκίνησης, ὄχι σφραγίδα. Ὁ ξένος γίνεται δοῦλος, ὁ δοῦλος φίλος. Γι' αὐτὸ ἡ τίμια εἰκόνα τοῦ σήμερα δὲν σὲ καταδικάζει, σὲ ξεκινᾶ."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Πάντων τῶν προαιρουμένων ὁ Θεὸς πάντων ἡ ζωή· πάντων ἡ σωτηρία.",
            gloss: "Ἡ πόρτα εἶναι ἀνοιχτὴ γιὰ κάθε τύπο ἀνθρώπου. Ἡ μόνη ἐρώτηση εἶναι ποῦ στέκεσαι ἐσὺ σήμερα, καὶ ὅτι αὐτὸ μπορεῖ ν' ἀλλάξει.",
            source: "Κλῖμαξ, Λόγος Α´"
        ),
        xp: 20
    )

    static let apotageLesson3 = LessonContent(
        id: "ladder-01-apotage-lesson-03",
        index: 3,
        title: "Ἡ φωτιὰ τῆς ἀρχῆς",
        teaching: LessonTeaching(
            title: "Ἡ φωτιὰ τῆς ἀρχῆς",
            body: "Ὁ ἅγιος Ἰωάννης δὲν κρύβει τὴ δυσκολία: ὅσοι προσπαθοῦν ν' ἀνέβουν στὸν οὐρανὸ «μετὰ σώματος» χρειάζονται **βία καὶ ἀπαύστους ὀδύνες**, μάλιστα στὰ πρῶτα βήματα τῆς ἀποταγῆς. Ἡ εἴσοδος στὸν καλὸ ἀγῶνα μοιάζει μὲ εἴσοδο σὲ **φωτιά**· ὅποιος θέλει τὴν ἄϋλη φωτιὰ μέσα του, ἂς δοκιμάσει πρῶτα τὸν ἑαυτό του.\n\nΓι' αὐτὸ προτείνει τὰ **νήπια** ὡς πρότυπο: δὲν ἔχουν πονηριά, δὲν χορταίνουν ἀσταμάτητα, δὲν καίγεται τὸ σῶμα τους ἀπὸ πάθος. Καὶ προειδοποιεῖ γιὰ κάτι πολὺ συγκεκριμένο: εἶναι **ἐπικίνδυνο νὰ χαλαρώσεις ἀκριβῶς στὴν ἀρχὴ** τῆς πάλης. Ὅποιος προδώσει τὴ θέρμη του, θὰ τὴ νιώσει σὰν κεντρὶ στὴ μνήμη του, καὶ δὲν θὰ βρεῖ ἄλλη πόρτα γιὰ νὰ γυρίσει πίσω παρὰ ἐκείνη ἀπ' ὅπου βγῆκε.",
            sources: ["Κλῖμαξ, Λόγος Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Ξεκινᾶς κάτι καλὸ καὶ οἱ πρῶτες μέρες εἶναι δύσκολες, γεμάτες ἀντίσταση. Τί σοῦ λέει ὁ ἅγιος γι' αὐτό;",
                options: [
                    "Ὅτι ἡ δυσκολία εἶναι σημάδι πὼς δὲν εἶσαι γι' αὐτό.",
                    "Ὅτι ἡ ἀρχὴ θέλει κόπο σχεδὸν πάντα, καὶ δὲν εἶναι ἀποτυχία.",
                    "Ὅτι ἂν εἶναι δύσκολο, κάτι κάνεις λάθος.",
                    "Ὅτι πρέπει νὰ περιμένεις μέχρι νὰ γίνει εὔκολο πρὶν ξεκινήσεις."
                ],
                answerIndex: 1,
                explanation: "Ὁ ἅγιος δὲν κρύβει ὅτι ἡ ἀρχὴ θέλει «βία καὶ ἀπαύστους ὀδύνες». Ἡ δυσκολία στὴν ἀρχὴ δὲν εἶναι ἔνδειξη ὅτι ἀπέτυχες, εἶναι τὸ κανονικὸ σχῆμα κάθε ἀληθινῆς ἀλλαγῆς."
            ),
            .readingPassage(
                id: "ex2",
                source: "Κλῖμαξ, Λόγος Α´",
                passage: "Δοκιμαζέτω δὲ ἕκαστος ἑαυτὸν, καὶ εἶθ' οὕτως ἐκ τοῦ ἄρτου αὐτῆς τοῦ μετὰ πικρίδων, καὶ ἐκ τοῦ ποτηρίου αὐτῆς τοῦ μετὰ δακρύων ἐσθιέτω, καὶ πινέτω, ἵνα μὴ εἰς κρῖμα ἑαυτῷ στρατεύηται.",
                gloss: "Ἂς δοκιμάζει ὁ καθένας τὸν ἑαυτό του, καὶ ὕστερα ἂς τρώει τὸ ψωμὶ τῆς ἀσκήσεως μὲ πικρὰ χόρτα καὶ ἂς πίνει τὸ ποτήρι της μὲ δάκρυα, γιὰ νὰ μὴν στρατεύεται πρὸς καταδίκη τοῦ ἑαυτοῦ του.",
                question: "Γιατί σοῦ ζητᾶ νὰ «δοκιμάσεις τὸν ἑαυτό σου» πρὶν μπεῖς σοβαρὰ σὲ κάτι;",
                options: [
                    "Γιὰ νὰ σὲ ἀποκλείσει ἂν ἔχεις παρελθόν.",
                    "Γιὰ νὰ μπεῖς μὲ ἀνοιχτὰ μάτια, ὄχι ἐπιπόλαια.",
                    "Γιατὶ μόνο οἱ τέλειοι ἐπιτρέπεται νὰ ξεκινήσουν.",
                    "Γιὰ νὰ σὲ τρομάξει."
                ],
                answerIndex: 1,
                explanation: "Ἡ αὐτοεξέταση δὲν ἀποκλείει κανέναν, προετοιμάζει. Μπαίνεις μὲ ἀνοιχτὰ μάτια, ξέροντας τί ἀναλαμβάνεις, γιὰ νὰ μὴν καταρρεύσεις στὴν πρώτη δυσκολία."
            ),
            .multipleChoice(
                id: "ex3",
                prompt: "Ὁ ἅγιος προειδοποιεῖ εἰδικὰ γιὰ ἕναν κίνδυνο στὴν ἀρχή. Ποιόν;",
                options: [
                    "Νὰ ξεκινήσεις πολὺ αὐστηρά.",
                    "Νὰ χαλαρώσεις ἀκριβῶς στὴν ἀρχή.",
                    "Νὰ ζητήσεις βοήθεια ἀπὸ ἄλλον.",
                    "Νὰ ξεκινήσεις χωρὶς νὰ τὸ ξέρουν οἱ ἄλλοι."
                ],
                answerIndex: 1,
                explanation: "Ἡ πρώτη χαλάρωση εἶναι ἡ πιὸ ὕπουλη: ἔρχεται ὅταν νιώθεις ὅτι «τὸ ἔχεις», καὶ σβήνει τὴ φωτιὰ πρὶν ριζώσει. Τὸ τέλος συχνὰ μοιάζει μὲ τὴν ἀρχή."
            ),
            .trueFalse(
                id: "ex4",
                statement: "Ὁ ἅγιος προτείνει τὰ νήπια ὡς πρότυπο ἐπειδὴ θεωρεῖ ὅτι ἡ ἄγνοια εἶναι καλύτερη ἀπ' τὴ γνώση.",
                answer: false,
                explanation: "Δὲν μιλᾶ γιὰ ἄγνοια. Τὰ νήπια εἶναι πρότυπο γιατὶ δὲν ἔχουν πονηριὰ καὶ δὲν εἶναι ἀχόρταγα, ὄχι γιατὶ δὲν ξέρουν. Πρότυπο ἁπλότητας, ὄχι ἀμάθειας."
            ),
            .readingPassage(
                id: "ex5",
                source: "Κλῖμαξ, Λόγος Α´",
                passage: "Ψυχὴ γὰρ ἀνδρισαμένη, καὶ ὑποχαλάσασα, ὑπὸ τῆς μνήμης τῆς ἀρχαίας σπουδῆς, ὡς ὑπὸ κέντρου πλήσσεται. Οὐκ ἔστι γὰρ δι' ἑτέρας πύλης αὐτὴν ἐπαναστρέψαι, εἰ μὴ δι' ἧς καὶ ἐξελήλυθεν.",
                gloss: "Ἡ ψυχὴ ποὺ ἀνδρειώθηκε καὶ ὕστερα χαλάρωσε, νιώθει σὰν κεντρὶ τὴ μνήμη τῆς παλιᾶς της προθυμίας. Δὲν μπορεῖ νὰ γυρίσει πίσω ἀπὸ ἄλλη πόρτα, παρὰ μόνο ἀπ' αὐτὴν ἀπ' ὅπου βγῆκε.",
                question: "Ἔχασες τὴ θέρμη ποὺ εἶχες στὴν ἀρχή. Πῶς λέει ὁ ἅγιος ὅτι τὴ βρίσκεις ξανά;",
                options: [
                    "Δὲν τὴ βρίσκεις ποτὲ ξανά, ἔφυγε.",
                    "Ψάχνοντας ἕνα καινούριο, πιὸ ἔξυπνο τρόπο ποὺ δὲν δοκίμασες.",
                    "Γυρίζοντας σ' αὐτὸ ποὺ τὴν ἄναψε τὴν πρώτη φορά, ὄχι σὲ κάτι ἄλλο.",
                    "Περιμένοντας νὰ ξανάρθει μόνη της."
                ],
                answerIndex: 2,
                explanation: "«Δὲν ὑπάρχει ἄλλη πόρτα, παρὰ ἐκείνη ἀπ' ὅπου βγῆκες.» Ἡ ἐπιστροφὴ δὲν εἶναι ἀδύνατη, ἀλλὰ γίνεται ἀπ' τὸν ἴδιο δρόμο ποὺ γέννησε τὸν πρῶτο ζῆλο, ὄχι μὲ κάποιο νέο τέχνασμα."
            ),
            .multipleChoice(
                id: "ex6",
                prompt: "Ἡ πιὸ σημαντικὴ προειδοποίηση αὐτοῦ τοῦ μαθήματος εἶναι:",
                options: [
                    "Μὴ χαλαρώσεις στὴν ἀρχή.",
                    "Μὴ ζητήσεις ποτὲ βοήθεια.",
                    "Ξεκίνα ὅσο πιὸ αὐστηρὰ γίνεται.",
                    "Περίμενε νὰ γίνει εὔκολο."
                ],
                answerIndex: 0,
                explanation: "Ἡ ἀρχὴ εἶναι δύσκολη ἐπίτηδες, καὶ ἀκριβῶς ἐκεῖ, ὅταν ὅλα εἶναι ἀκόμα νέα, ἡ χαλάρωση κοστίζει περισσότερο."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Οὐκ ἔστι γὰρ δι' ἑτέρας πύλης αὐτὴν ἐπαναστρέψαι, εἰ μὴ δι' ἧς καὶ ἐξελήλυθεν.",
            gloss: "Δὲν μπορεῖ ἡ ψυχὴ νὰ γυρίσει πίσω ἀπὸ ἄλλη πόρτα, παρὰ μόνο ἀπ' αὐτὴν ἀπ' ὅπου βγῆκε.",
            source: "Κλῖμαξ, Λόγος Α´"
        ),
        xp: 20
    )

    static let apotageLesson4 = LessonContent(
        id: "ladder-01-apotage-lesson-04",
        index: 4,
        title: "Φόβος ἢ ἀγάπη",
        teaching: LessonTeaching(
            title: "Φόβος ἢ ἀγάπη",
            body: "Ὁ ἅγιος Ἰωάννης δείχνει, μὲ καθημερινὲς εἰκόνες, πῶς κινούμαστε στ' ἀλήθεια. Συχνὰ φοβόμαστε τὶς ὁρατὲς συνέπειες πιὸ πολὺ ἀπ' τὸν ἴδιο τὸν Θεό. Ὁ στόχος δὲν εἶναι νὰ μείνουμε στὸν φόβο, ἀλλὰ νὰ περάσουμε σιγὰ σιγὰ στὴν ἀγάπη, μὲ τὴν ἴδια ἐπιμονὴ ποὺ βάζουμε γιὰ νὰ ξανακερδίσουμε ἕναν φίλο ποὺ πικράναμε.",
            sources: ["Κλῖμαξ, Λόγος Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Ἡ ἀρχή σου εἶναι ἀργὴ καὶ διστακτική. Στὴν εἰκόνα τῶν οἰκοδόμων, κάποιοι «περπάτησαν λίγο καὶ μετὰ ἔτρεξαν». Τί σοῦ λέει αὐτό;",
                options: [
                    "Ὅτι ἔχεις ἤδη ἀποτύχει, ἀφοῦ δὲν ξεκίνησες δυνατά.",
                    "Ὅτι εἶναι φυσικὸ νὰ ξεκινᾶς ἀργὰ καὶ νὰ ἐπιταχύνεις μετά.",
                    "Ὅτι πρέπει νὰ σταματήσεις καὶ νὰ ξαναρχίσεις σωστά.",
                    "Ὅτι μόνο ἡ ταχύτητα μετράει."
                ],
                answerIndex: 1,
                explanation: "Ἀργὴ ἀρχὴ δὲν σημαίνει ἀποτυχία. Σημασία ἔχει νὰ μὴ μείνεις ἐκεῖ, ἀλλὰ νὰ ζεσταθεῖς καὶ νὰ προχωρήσεις. Ὁ ἅγιος ἀφήνει σκόπιμα τὴν εἰκόνα ἀνοιχτή, «ὁ νοῶν νοείτω»."
            ),
            .readingPassage(
                id: "ex2",
                source: "Κλῖμαξ, Λόγος Α´",
                passage: "Φοβηθῶμεν τὸν Κύριον ὡς τὰ θηρία. Εἶδον γὰρ ἄνδρας συλῆσαι πορευθέντας, καὶ Θεὸν μὲν οὐκ ἐφοβήθησαν, κυνῶν δὲ φωνὴν ἐν τῷ τόπῳ ἀκούσαντες εὐθέως ὑπέστρεψαν. Καὶ ὅπερ φόβος Θεοῦ οὐκ ἐποίησε, τοῦτο φόβος θηρίων ἴσχυσεν.",
                gloss: "Εἶδα ἀνθρώπους ποὺ πῆγαν νὰ κλέψουν καὶ δὲν φοβήθηκαν τὸν Θεό, ἀλλὰ μόλις ἄκουσαν σκύλους νὰ γαβγίζουν κοντά, ἀμέσως γύρισαν πίσω. Κι αὐτὸ ποὺ δὲν κατάφερε ὁ φόβος τοῦ Θεοῦ, τὸ κατάφερε ὁ φόβος τῶν ζώων.",
                question: "Ὁ κλέφτης σταμάτησε ἀπ' τὸν φόβο τῶν σκύλων, ὄχι τοῦ Θεοῦ. Τί ἀλήθεια θέλει νὰ σοῦ δείξει;",
                options: [
                    "Ὅτι τὰ ζῶα εἶναι πιὸ ἐπικίνδυνα ἀπ' τὸν Θεό.",
                    "Ὅτι φοβόμαστε τὶς ὁρατὲς συνέπειες πιὸ πολὺ ἀπ' τὸν Θεό.",
                    "Ὅτι ὁ φόβος τοῦ Θεοῦ δὲν χρειάζεται.",
                    "Ὅτι μόνο ὁ φόβος τῆς τιμωρίας μᾶς κρατᾶ σωστούς."
                ],
                answerIndex: 1,
                explanation: "Εἶναι ἕνας πικρὸς καθρέφτης: κινούμαστε πιὸ εὔκολα ἀπ' αὐτὸ ποὺ βλέπουμε καὶ φοβόμαστε ἄμεσα. Ὁ ἅγιος τὸ λέει γιὰ νὰ ξυπνήσει, ὄχι γιὰ νὰ καταδικάσει."
            ),
            .multipleChoice(
                id: "ex3",
                prompt: "Ὁ ἅγιος λέει νὰ ἀγαπᾶμε τὸν Θεὸ ὅπως προσπαθοῦμε νὰ ξανακερδίσουμε ἕναν φίλο ποὺ πικράναμε. Τί προτείνει μ' αὐτό;",
                options: [
                    "Νὰ φοβόμαστε μὴν χάσουμε τὴν εὔνοιά Του.",
                    "Νὰ βάζουμε στὸν Θεὸ τὴ ζέση ποὺ βάζουμε γιὰ ἕναν φίλο.",
                    "Νὰ κρατᾶμε ἀποστάσεις, ὅπως μὲ ἕναν ἁπλὸ γνωστό.",
                    "Νὰ περιμένουμε ὁ Θεὸς νὰ κάνει τὸ πρῶτο βῆμα."
                ],
                answerIndex: 1,
                explanation: "Ξέρεις πόση ἐνέργεια βάζεις γιὰ νὰ τὰ ξαναβρεῖς μὲ κάποιον ποὺ ἀγαπᾶς. Ὁ ἅγιος λέει: τόση. Ἡ ἀγάπη κινεῖ διαφορετικὰ ἀπ' τὸν φόβο, ὄχι μὲ πίεση ἀλλὰ μὲ πόθο."
            ),
            .trueFalse(
                id: "ex4",
                statement: "Ὁ φόβος τοῦ Θεοῦ εἶναι κακὸς καὶ πρέπει νὰ τὸν ξεφορτωθοῦμε ἀμέσως.",
                answer: false,
                explanation: "Ὁ φόβος εἶναι μιὰ τίμια ἀρχή, ὅπως καὶ στὸ πρῶτο μάθημα. Δὲν τὸν πετᾶμε, τὸν ἀφήνουμε νὰ ὡριμάσει σὲ ἀγάπη. Ἡ τελεία ἀγάπη διώχνει τὸν φόβο, ἀλλὰ αὐτὸ εἶναι κατάληξη, ὄχι ἀφετηρία."
            ),
            .readingPassage(
                id: "ex5",
                source: "Κλῖμαξ, Λόγος Α´",
                passage: "Εἰ βασιλέως ἐπιγείου καλέσαντος, καὶ εἰς τὴν κατὰ πρόσωπον αὐτοῦ δουλείαν στρατεῦσαι θελήσαντος, οὐκ ἀναμένομεν, οὐ προφασιζόμεθα· ἀλλὰ πάντα καταλείψαντες προθύμως αὐτὸν καταφθάνομεν.",
                gloss: "Ἂν ἕνας ἐπίγειος βασιλιὰς μᾶς καλοῦσε νὰ ὑπηρετήσουμε δίπλα του, δὲν θὰ περιμέναμε, δὲν θὰ βρίσκαμε δικαιολογίες· θὰ ἀφήναμε τὰ πάντα καὶ θὰ τρέχαμε πρόθυμα κοντά του.",
                question: "Τί σοῦ ζητᾶ νὰ προσέξεις αὐτὴ ἡ σύγκριση;",
                options: [
                    "Ὅτι οἱ ἐπίγειοι βασιλιάδες ἀξίζουν μεγαλύτερη ἀφοσίωση.",
                    "Ὅτι ἀξίζει νὰ δεῖς μὲ πόση προθυμία ἀνταποκρίνεσαι στὸν Θεό.",
                    "Ὅτι δὲν ἔχει σημασία σὲ ποιὸν ἀφοσιώνεσαι.",
                    "Ὅτι πρέπει νὰ ἐγκαταλείψεις κάθε δουλειὰ στὸν κόσμο."
                ],
                answerIndex: 1,
                explanation: "Εἶναι σύγκριση ἀπ' τὸ μικρότερο στὸ μεγαλύτερο. Δὲς πόση ἐνέργεια βρίσκεις γιὰ μιὰ εὐκαιρία ποὺ σὲ συμφέρει, καὶ σύγκρινέ τη μὲ τὴν προθυμία σου γιὰ τὸν Θεό. Ἡ διαφορὰ σοῦ δείχνει ποῦ εἶναι στ' ἀλήθεια ἡ καρδιά σου."
            ),
            .multipleChoice(
                id: "ex6",
                prompt: "Ποῦ θέλει νὰ σὲ ὁδηγήσει τελικὰ ὁ ἅγιος μ' αὐτὲς τὶς εἰκόνες;",
                options: [
                    "Νὰ μένεις πάντα στὸν φόβο.",
                    "Νὰ περάσεις ἀπ' τὸν φόβο στὴν ἀγάπη.",
                    "Νὰ φοβᾶσαι περισσότερο.",
                    "Νὰ μὴν ἀφοσιωθεῖς ποτὲ σὲ τίποτα."
                ],
                answerIndex: 1,
                explanation: "Φόβος στὴν ἀρχή, ἀγάπη στὸ τέλος. Ἡ κατεύθυνση εἶναι πάντα πρὸς τὴν ἀγάπη."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Ὡς ὑπὸ Θεοῦ καὶ βασιλέως κληθέντες προθύμως δράμωμεν.",
            gloss: "Ἂς τρέξουμε πρόθυμα, σὰν νὰ μᾶς καλεῖ ὁ ἴδιος ὁ Θεὸς καὶ βασιλιάς.",
            source: "Κλῖμαξ, Λόγος Α´"
        ),
        xp: 20
    )

    static let apotageLesson5 = LessonContent(
        id: "ladder-01-apotage-lesson-05",
        index: 5,
        title: "Δὲν εἶσαι ἀνάξιος",
        teaching: LessonTeaching(
            title: "Δὲν εἶσαι ἀνάξιος",
            body: "Ὁ ἅγιος Ἰωάννης κλείνει τὸν πρῶτο Λόγο μὲ κάτι ποὺ σὲ ἀφορᾶ ἄμεσα: δὲν χρειάζεται νὰ εἶσαι καθαρὸς ἢ νὰ ξεκίνησες τέλεια γιὰ νὰ ἀνήκεις. Ὅσο πιὸ βαριὰ ἡ πληγή, τόσο μεγαλύτερος ὁ λόγος νὰ ζητήσεις θεραπεία, ὄχι νὰ μείνεις μακριά. Πρόσεξε ὅμως τὴ φωνὴ ποὺ σοῦ λέει «χαλάρωσε, μὴν τὸ παρακάνεις», καὶ διάλεξε τὸν δρόμο ποὺ σηκώνεις, ὄχι τὸν πιὸ ἐντυπωσιακό.",
            sources: ["Κλῖμαξ, Λόγος Α´"]
        ),
        exercises: [
            .readingPassage(
                id: "ex1",
                source: "Κλῖμαξ, Λόγος Α´",
                passage: "Μηδεὶς βάρος καὶ πλῆθος ἁμαρτιῶν προφασιζόμενος ἀνάξιον ἑαυτὸν τοῦ μοναχικοῦ ἐπαγγέλματος ἀποκαλοῖτο. Ὅπου γὰρ πολλὴ ἡ σηπεδὼν, ἐκεῖ καὶ μεγάλης ἰατρείας χρεία, ἵνα τὸν ῥύπον ἀπόθηται. Οἱ γὰρ ὑγιαίνοντες ἐν ἰατρείῳ οὐ παραγίνονται.",
                gloss: "Κανεὶς νὰ μὴν λέει ὅτι εἶναι ἀνάξιος ἐξαιτίας τοῦ πλήθους τῶν ἁμαρτιῶν του. Ὅπου ὑπάρχει πολλὴ σαπίλα, ἐκεῖ χρειάζεται καὶ μεγάλη θεραπεία. Γιατὶ οἱ ὑγιεῖς δὲν πηγαίνουν σὲ ἰατρεῖο.",
                question: "Νιώθεις ἀνάξιος νὰ πλησιάσεις τὸν Θεὸ ἐξαιτίας τῶν λαθῶν σου. Τί σοῦ ἀπαντᾶ ὁ ἅγιος;",
                options: [
                    "Ὅτι πρέπει πρῶτα νὰ διορθωθεῖς μόνος σου καὶ μετὰ νὰ ἔρθεις.",
                    "Ὅτι ὅσο πιὸ βαριὰ ἡ πληγή, τόσο πιὸ πολὺ χρειάζεσαι θεραπεία.",
                    "Ὅτι μόνο οἱ καθαροὶ ἀνήκουν ἐκεῖ.",
                    "Ὅτι οἱ ἁμαρτίες σου σὲ ἀποκλείουν."
                ],
                answerIndex: 1,
                explanation: "Ἀντιστρέφει τὴ λογική σου: ἡ ἐνοχὴ ποὺ σὲ κρατᾶ μακριὰ εἶναι ἀκριβῶς ὁ λόγος νὰ πλησιάσεις. Τὸ ἰατρεῖο εἶναι γιὰ τοὺς ἀρρώστους, ὄχι γιὰ τοὺς ὑγιεῖς."
            ),
            .multipleChoice(
                id: "ex2",
                prompt: "Βρέθηκες σὲ κάτι καλὸ ὄχι ἀπὸ δική σου τέλεια ἐπιλογή, ἀλλὰ ἀπὸ μιὰ περίσταση. Ἔχει λιγότερη ἀξία;",
                options: [
                    "Ναί, ἀφοῦ δὲν ἦταν συνειδητὴ ἀπόφαση.",
                    "Ὄχι, τὰ ἀκούσια συχνὰ ἀποδεικνύονται πιὸ σταθερά.",
                    "Πρέπει νὰ τὸ παρατήσεις καὶ νὰ ξαναρχίσεις σωστά.",
                    "Μόνο ἂν τὸ ξαναδιαλέξεις συνειδητά."
                ],
                answerIndex: 1,
                explanation: "Δὲν χρειάζεσαι τέλεια ἱστορία ἀφετηρίας. Ὁ Θεὸς χρησιμοποιεῖ καὶ αὐτὸ ποὺ ἦρθε ἄθελά σου. Σημασία ἔχει τί κάνεις μὲ αὐτὸ τώρα."
            ),
            .multipleChoice(
                id: "ex3",
                prompt: "Μιὰ φωνὴ μέσα σου λέει, μὲ πρόσχημα τὴ λογική, «μὴν τὸ παρακάνεις, χαλάρωσε λίγο» ἀκριβῶς ὅταν ξεκινᾶς. Πῶς τὴ διαβάζει ὁ ἅγιος;",
                options: [
                    "Ὡς σοφὴ συμβουλὴ ποὺ πρέπει πάντα ν' ἀκοῦς.",
                    "Ὡς πειρασμὸ ντυμένο σὰν λογικὴ φροντίδα.",
                    "Ὡς σημάδι ὅτι πρέπει νὰ σταματήσεις ἐντελῶς.",
                    "Ὡς φωνὴ χωρὶς καμία σημασία."
                ],
                answerIndex: 1,
                explanation: "Οἱ πιὸ ὕπουλες φωνὲς δὲν λένε «παράτα τα», λένε «μὴν κουράζεσαι τόσο». Δὲν σημαίνει ὅτι δὲν φροντίζεις τὸ σῶμα σου καὶ τὴν ξεκούρασή σου· σημαίνει νὰ ἀναγνωρίζεις πότε ἡ «λογικὴ» εἶναι πρόφαση γιὰ νὰ σβήσει ἡ ὁρμὴ πρὶν ριζώσει."
            ),
            .readingPassage(
                id: "ex4",
                source: "Κλῖμαξ, Λόγος Α´",
                passage: "Μὴ ἐκκλίνῃς, φησὶν ὁ Ἐκκλησιαστής, εἰς τὰ δεξιὰ, ἢ εἰς τὰ ἀριστερά· ἀλλ' ὁδῷ βασιλικῇ πορευθῇς· ἡ γὰρ μέση τῶν προειρημένων πολλοῖς ἁρμόδιος καθέστηκεν.",
                gloss: "Μὴν ξεκλίνεις, λέει ὁ Ἐκκλησιαστής, οὔτε δεξιὰ οὔτε ἀριστερά, ἀλλὰ βάδιζε στὴ βασιλικὴ ὁδό. Ὁ μέσος δρόμος ταιριάζει στοὺς περισσότερους.",
                question: "Ἡ «βασιλικὴ ὁδός», ὁ μέσος δρόμος, τί σοῦ συμβουλεύει στὴν πράξη;",
                options: [
                    "Νὰ διαλέξεις τὸ πιὸ ἀκραῖο καὶ ἐντυπωσιακό.",
                    "Νὰ διαλέξεις τὸν τρόπο ποὺ σοῦ ταιριάζει.",
                    "Νὰ κάνεις πάντα ὅ,τι κάνουν οἱ πολλοί.",
                    "Νὰ ἀποφεύγεις κάθε προσπάθεια."
                ],
                answerIndex: 1,
                explanation: "Ὁ μέσος δρόμος δὲν εἶναι συμβιβασμὸς πρὸς τὰ κάτω, εἶναι διάκριση. Ἡ ἀκρότητα ποὺ δὲν σοῦ ταιριάζει σὲ τσακίζει· ὁ δρόμος ποὺ σηκώνεις σὲ πάει μακριά. Καὶ αὐτὸ διαλέγεται μὲ ὁδηγὸ καὶ αὐτογνωσία."
            ),
            .trueFalse(
                id: "ex5",
                statement: "Ὅσο περισσότερα λάθη ἔχω κάνει, τόσο λιγότερο μοῦ ταιριάζει νὰ πλησιάσω τὸν Θεό.",
                answer: false,
                explanation: "Ἀκριβῶς τὸ ἀντίθετο. «Ὅπου πολλὴ ἡ σηπεδών, ἐκεῖ καὶ μεγάλης ἰατρείας χρεία.» Ἡ ἀνάγκη σου δὲν εἶναι ἐμπόδιο, εἶναι ἡ πρόσκληση."
            ),
            .multipleChoice(
                id: "ex6",
                prompt: "Ὁ ἅγιος κλείνει μὲ μιὰ ἐρώτηση ποὺ μένει ἀνοιχτὴ ἐπίτηδες. Ποιά;",
                options: [
                    "Ποιὸς εἶναι ὁ αὐστηρότερος ἀσκητής;",
                    "Ποιὸς κρατᾶ τὴ θέρμη του ὣς τὸ τέλος;",
                    "Πόσα χρόνια θέλει ἡ τελειότητα;",
                    "Ποιὰ εἶναι ἡ καλύτερη μονή;"
                ],
                answerIndex: 1,
                explanation: "Δὲν ρωτᾶ ποιὸς ξεκίνησε πιὸ δυνατά, ἀλλὰ ποιὸς κράτησε τὴ φωτιὰ ζωντανὴ ὣς τὸ τέλος. Ἡ ἐρώτηση μένει ἀνοιχτὴ γιὰ σένα."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Τίς ἄρα ἐστὶν ὁ πιστὸς καὶ φρόνιμος μοναχός, ὃς τὴν θέρμην τὴν ἑαυτοῦ ἐφύλαξεν ἄσβεστον;",
            gloss: "Ποιὸς ἄραγε εἶναι ὁ πιστὸς καὶ συνετὸς μοναχός, ποὺ κράτησε τὴ θέρμη του ἄσβεστη;",
            source: "Κλῖμαξ, Λόγος Α´"
        ),
        xp: 20
    )
}

// MARK: - Which lessons belong to which rung

extension LessonContent {
    /// Looks up the built lessons for a given Virtue.id (its rung number,
    /// 1...30). Only rung 1 (Ἀποταγή) has real lessons so far — everything
    /// else returns empty until it is built, same as the "SOON" virtues.
    static func forVirtue(id: Int) -> [LessonContent] {
        sections(forVirtue: id).flatMap(\.lessons)
    }
}

extension LessonContent {
    static let dorotheosLesson1 = LessonContent(
        id: "ladder-01-dorotheos-lesson-01",
        index: 6,
        title: "Ὁ ἄνθρωπος στὸν παράδεισο",
        teaching: LessonTeaching(
            title: "Ὁ ἄνθρωπος στὸν παράδεισο",
            body: "Ὁ Ἀββᾶς Δωρόθεος ξεκινᾶ τὴ διδαχή του γιὰ τὴν ἀποταγὴ ὄχι ἀπ' τὴ μοναχικὴ ζωή, ἀλλὰ ἀπ' τὴν ἴδια τὴ δημιουργία. Ὁ Θεὸς ἔπλασε τὸν ἄνθρωπο **κατ' εἰκόνα Του**: ἀθάνατο, αὐτεξούσιο, στολισμένο μὲ κάθε ἀρετή, μέσα στὸν παράδεισο, μὲ μία μόνη ἐντολή. Ὅταν ὁ ἄνθρωπος τὴν παρέβη, ἔπεσε ἀπ' τὸ «κατὰ φύσιν» στὸ «παρὰ φύσιν» καὶ ὑποδουλώθηκε στὰ πάθη.\n\nἩ συνέπεια δὲν ἦταν στιγμιαία: ὁ Δωρόθεος περιγράφει ἕναν κόσμο ὅπου ἡ κακία **αὐξήθηκε σταδιακά**, ὁ θάνατος βασίλεψε, καὶ ἡ γνώση τοῦ Θεοῦ σχεδὸν χάθηκε, μὲ ἐξαίρεση λίγους δικαίους σὰν τὸν Ἀβραάμ, τὸν Νῶε καὶ τὸν Ἰώβ, ποὺ κρατήθηκαν ἀπ' τὸν «φυσικὸ νόμο» μέσα τους.",
            sources: ["Ἀββᾶς Δωρόθεος, Διδαχὴ Α´ (Περὶ ἀποταγῆς)"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Πῶς περιγράφει ὁ Ἀββᾶς Δωρόθεος τὸν ἄνθρωπο ὅπως πλάστηκε ἀρχικά;",
                options: [
                    "Ὡς ὂν χωρὶς καμία δυνατότητα ἐπιλογῆς, καθοδηγούμενο ἀποκλειστικὰ ἀπ' τὸν Θεό.",
                    "Ὡς ἀθάνατο, αὐτεξούσιο, στολισμένο μὲ κάθε ἀρετή, κατ' εἰκόνα Θεοῦ.",
                    "Ὡς ὂν ἤδη ἀδύναμο καὶ μὲ ροπὴ πρὸς τὴν ἁμαρτία ἀπ' τὴν ἀρχή.",
                    "Ὡς ὂν ἴδιο μὲ τὰ ζῶα, χωρὶς ἰδιαίτερο προνόμιο."
                ],
                answerIndex: 1,
                explanation: "Ὁ Ἀββᾶς Δωρόθεος τονίζει τὸ «αὐτεξούσιο» ἀκριβῶς γιὰ νὰ δείξει ὅτι ἡ πτώση ἦταν ἐλεύθερη ἐπιλογή, ὄχι ἀναπόφευκτη μοίρα."
            ),
            .readingPassage(
                id: "ex2",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Κατ' εἰκόνα γὰρ Θεοῦ ἐποίησεν ὁ Θεὸς τὸν ἄνθρωπον, τοῦτ' ἔστιν ἀθάνατον, αὐτεξούσιον, κεκοσμημένον πάσῃ ἀρετῇ.",
                gloss: "Ὁ Θεὸς ἔπλασε τὸν ἄνθρωπο κατ' εἰκόνα Του, δηλαδὴ ἀθάνατο, ἐλεύθερο νὰ διαλέγει, καὶ στολισμένο μὲ κάθε ἀρετή.",
                question: "Γιατί ὁ Ἀββᾶς Δωρόθεος ξεκινᾶ ἀκριβῶς ἀπὸ ἐδῶ τὴ διδαχή του γιὰ τὴν ἀποταγή;",
                options: [
                    "Γιὰ νὰ ἀποδείξει ὅτι ὁ ἄνθρωπος ἦταν πάντα ἁμαρτωλός.",
                    "Γιὰ νὰ ὑπενθυμίσει ἁπλῶς μιὰ ἱστορικὴ λεπτομέρεια, χωρὶς ἄλλο σκοπό.",
                    "Γιὰ νὰ δικαιολογήσει τὴν ἀνάγκη τιμωρίας τοῦ ἀνθρώπου.",
                    "Γιὰ νὰ δείξει ὅτι ἡ ἀρετὴ δὲν εἶναι κάτι ξένο πρὸς τὸν ἄνθρωπο, ἀλλὰ ἡ ἀρχική, φυσική του κατάσταση ποὺ ἡ ἀποταγὴ ἔρχεται νὰ ἐπαναφέρει."
                ],
                answerIndex: 3,
                explanation: "Ἡ ἀποταγή, γιὰ τὸν Δωρόθεο, δὲν εἶναι ἐπινόηση, εἶναι ἐπιστροφὴ στὸ «κατὰ φύσιν» ποὺ χάθηκε μὲ τὴν πτώση."
            ),
            .trueFalse(
                id: "ex3",
                statement: "Κατὰ τὸν Ἀββᾶ Δωρόθεο, μετὰ τὴν πτώση, ἡ γνώση τοῦ Θεοῦ χάθηκε ἐντελῶς, χωρὶς καμία ἐξαίρεση.",
                answer: false,
                explanation: "Λάθος. Ὁ Δωρόθεος ἀναφέρει ρητὰ τὸν Ἀβραάμ, τὸν Νῶε καὶ τὸν Ἰὼβ ὡς ἐξαιρέσεις ποὺ γνώριζαν τὸν Θεὸ μέσα ἀπ' τὸν φυσικὸ νόμο."
            ),
            .fillBlank(
                id: "ex4",
                textBefore: "Κατ' εἰκόνα γὰρ Θεοῦ ἐποίησεν ὁ Θεὸς τὸν ἄνθρωπον, τοῦτ' ἔστιν ἀθάνατον,",
                textAfter: ", κεκοσμημένον πάσῃ ἀρετῇ.",
                answer: "αὐτεξούσιον",
                options: ["αὐτεξούσιον", "ἀναμάρτητον", "ἀπαθῆ", "τέλειον"],
                explanation: "Ἡ λέξη «αὐτεξούσιον» εἶναι κλειδί: ὁ ἄνθρωπος πλάστηκε ἐλεύθερος νὰ διαλέγει, κι αὐτὴ ἡ ἐλευθερία εἶναι ποὺ κάνει τὴν πτώση δική του εὐθύνη."
            ),
            .match(
                id: "ex5",
                instruction: "Ἀντιστοίχισε κάθε ἔννοια τοῦ Ἀββᾶ Δωροθέου μὲ τὸ νόημά της.",
                pairs: [
                    MatchPair(left: "Κατὰ φύσιν", right: "Ἡ ἀρχικὴ κατάσταση τοῦ ἀνθρώπου στὸν παράδεισο"),
                    MatchPair(left: "Παρὰ φύσιν", right: "Ἡ κατάσταση μετὰ τὴν πτώση, ὑποδουλωμένη στὰ πάθη"),
                    MatchPair(left: "Αὐτεξούσιον", right: "Ἡ ἐλευθερία ἐπιλογῆς ποὺ ἔκανε δυνατὴ τὴν πτώση")
                ],
                explanation: "Ὁ Δωρόθεος χτίζει τὴ διδαχή του πάνω σ' αὐτὲς τὶς τρεῖς ἔννοιες, γιατὶ ὅλη ἡ πνευματικὴ ζωὴ εἶναι, γι' αὐτόν, ἐπιστροφὴ ἀπ' τὸ παρὰ φύσιν στὸ κατὰ φύσιν."
            ),
            .order(
                id: "ex6",
                prompt: "Βάλε αὐτὰ τὰ στάδια μὲ τὴ σειρὰ ποὺ τὰ περιγράφει ὁ Ἀββᾶς Δωρόθεος.",
                items: ["Ὁ Θεὸς πλάθει τὸν ἄνθρωπο κατ' εἰκόνα Του", "Ὁ ἄνθρωπος παραβαίνει τὴν ἐντολή", "Ἡ κακία ἁπλώνεται σταδιακὰ στὸν κόσμο"],
                explanation: "Ὁ Δωρόθεος περιγράφει μιὰ σαφῆ πορεία: δημιουργία, πτώση, καὶ σταδιακὴ ἐξάπλωση τῆς κακίας, ὄχι ξαφνικὴ καταστροφή."
            ),
            .readingPassage(
                id: "ex7",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ὅτε δὲ παρέβη τὴν ἐντολὴν καὶ ἔφαγεν ἐκ τοῦ ξύλου, τότε ἐξεβλήθη τοῦ παραδείσου· ἐξέπεσε γὰρ ἐκ τοῦ κατὰ φύσιν καὶ ἦν ἐν τῷ παρὰ φύσιν.",
                gloss: "Ὅταν παρέβη τὴν ἐντολὴ καὶ ἔφαγε ἀπ' τὸ δέντρο, ἐκδιώχθηκε ἀπ' τὸν παράδεισο· ἔπεσε ἀπ' τὴ φυσική του κατάσταση καὶ βρέθηκε σὲ κατάσταση ἀντίθετη μὲ τὴ φύση του.",
                question: "Τί σημαίνει, κατὰ τὸν Δωρόθεο, ἡ φράση «ἐξέπεσε ἐκ τοῦ κατὰ φύσιν»;",
                options: [
                    "Ὅτι ἡ ἁμαρτία δὲν εἶναι ἡ φυσικὴ κατάσταση τοῦ ἀνθρώπου, ἀλλὰ παρέκκλιση ἀπ' αὐτήν.",
                    "Ὅτι ὁ ἄνθρωπος ἔγινε ἀπ' τὴ φύση του κάτι ἄλλο, ὄχι πιὰ ἄνθρωπος.",
                    "Ὅτι ἡ φύση τοῦ ἀνθρώπου ἦταν πάντα ἁμαρτωλή, ἁπλῶς τὸ φανέρωσε.",
                    "Ὅτι ὁ παράδεισος ἦταν ἕνας τόπος ἐντελῶς ξένος πρὸς τὴ φύση τοῦ ἀνθρώπου."
                ],
                answerIndex: 0,
                explanation: "Αὐτὴ ἡ διάκριση εἶναι θεμελιώδης γιὰ τὸν Δωρόθεο: ἡ ἁμαρτία εἶναι παρὰ φύσιν, ὄχι κατὰ φύσιν, ἄρα ἡ θεραπεία εἶναι δυνατή, ἀφοῦ δὲν ἀλλάζει τὴν ἴδια τὴ φύση τοῦ ἀνθρώπου."
            ),
            .multipleChoice(
                id: "ex8",
                prompt: "Ποιοὺς ἀναφέρει ὁ Ἀββᾶς Δωρόθεος ὡς ἐξαίρεση, ὅσους γνώριζαν τὸν Θεὸ ἀκόμα καὶ μέσα στὴ γενικευμένη ἀγνωσία;",
                options: [
                    "Τοὺς προφῆτες τῆς Παλαιᾶς Διαθήκης γενικά.",
                    "Τοὺς βασιλεῖς τοῦ Ἰσραήλ.",
                    "Τὸν Ἀβραάμ, τὸν Νῶε καὶ τὸν Ἰώβ.",
                    "Τοὺς ἱερεῖς τοῦ ναοῦ τῆς Ἱερουσαλήμ."
                ],
                answerIndex: 2,
                explanation: "Ὁ Δωρόθεος ὀνομάζει συγκεκριμένα τὸν Ἀβραάμ, τὸν Νῶε καὶ τὸν Ἰώβ, ὡς παραδείγματα ἀνθρώπων ποὺ κρατήθηκαν πιστοὶ μέσα ἀπ' τὸν φυσικὸ νόμο, πρὶν ἀκόμα δοθεῖ ὁ γραπτὸς νόμος."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Κατ' εἰκόνα γὰρ Θεοῦ ἐποίησεν ὁ Θεὸς τὸν ἄνθρωπον, τοῦτ' ἔστιν ἀθάνατον, αὐτεξούσιον, κεκοσμημένον πάσῃ ἀρετῇ.",
            gloss: "Ὁ Θεὸς ἔπλασε τὸν ἄνθρωπο κατ' εἰκόνα Του: ἀθάνατο, ἐλεύθερο, στολισμένο μὲ κάθε ἀρετή.",
            source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"
        ),
        xp: 20
    )

    static let dorotheosLesson2 = LessonContent(
        id: "ladder-01-dorotheos-lesson-02",
        index: 7,
        title: "Ὁ νόμος καὶ οἱ προφῆτες",
        teaching: LessonTeaching(
            title: "Ὁ νόμος καὶ οἱ προφῆτες",
            body: "Ὁ Θεός, βλέποντας τὴν κακία νὰ ἁπλώνεται, ἔδωσε τὸν γραπτὸ νόμο διὰ τοῦ Μωϋσέως: ἐντολὲς σαφεῖς, «τόδε ποιήσατε, τόδε μὴ ποιήσατε», ξεκινώντας ἀπ' τὸ «Κύριος ὁ Θεός σου Κύριος εἷς ἐστιν», γιὰ ν' ἀπομακρύνει τὸν νοῦ ἀπ' τὴν πολυθεΐα.\n\nΚαὶ ὅμως, λέει ὁ Ἀββᾶς Δωρόθεος, ὁ νόμος δὲν ἔφτασε. Ἔστειλε ὁ Θεὸς καὶ προφῆτες, μὰ οὔτε αὐτοὶ μπόρεσαν: ἡ κακία εἶχε γίνει τόσο βαθιά, λέει, χρησιμοποιώντας τὰ λόγια τοῦ Ἡσαΐα, ποὺ **δὲν ὑπῆρχε πληγὴ σὲ ἕνα σημεῖο νὰ τὴν περιδέσεις**· εἶχε ἁπλωθεῖ σ' ὅλο τὸ σῶμα. Ὁ Ἱερεμίας τὸ λέει ἀλλιῶς: «θεραπεύσαμε τὴ Βαβυλῶνα καὶ δὲν γιατρεύτηκε», ὅσα κι ἂν ἀκούστηκαν, δὲν ἔφεραν μετάνοια.",
            sources: ["Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Γιατί, κατὰ τὸν Ἀββᾶ Δωρόθεο, ὁ γραπτὸς νόμος τοῦ Μωϋσέως δὲν ἀρκοῦσε γιὰ νὰ διορθώσει τὴν κακία;",
                options: [
                    "Γιατί ἦταν πολὺ αὐστηρός, καὶ οἱ ἄνθρωποι δὲν μποροῦσαν νὰ τὸν ἀντέξουν.",
                    "Γιατί ἀπευθυνόταν μόνο σὲ λίγους ἐκλεκτούς.",
                    "Γιατί ἡ κακία εἶχε ἁπλωθεῖ τόσο βαθιά, ποὺ χρειαζόταν κάτι περισσότερο ἀπὸ ἐξωτερικὲς ἐντολές.",
                    "Γιατί δὲν εἶχε δοθεῖ ἀπευθείας ἀπ' τὸν Θεό."
                ],
                answerIndex: 2,
                explanation: "Ὁ Δωρόθεος χρησιμοποιεῖ τὴν εἰκόνα τοῦ Ἡσαΐα (πληγὴ σ' ὅλο τὸ σῶμα, ὄχι σ' ἕνα σημεῖο) γιὰ νὰ δείξει ὅτι ἡ ἀρρώστια ἦταν βαθύτερη ἀπ' ὅ,τι μποροῦσαν νὰ θεραπεύσουν ἐξωτερικὲς ἐντολές."
            ),
            .readingPassage(
                id: "ex2",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´ (κατὰ τὸν Ἡσαΐα)",
                passage: "Οὔτε τραῦμα οὔτε μώλωψ οὔτε πληγὴ φλεγμαίνουσα· οὐκ ἔστι μάλαγμα ἐπιθεῖναι οὔτε ἔλαιον οὔτε καταδέσμους.",
                gloss: "Δὲν εἶναι μόνο μία πληγή, οὔτε μελανιά, οὔτε ἕνα σημεῖο ποὺ φλέγεται· δὲν ὑπάρχει σημεῖο νὰ βάλεις ἐπίδεσμο, οὔτε λάδι, οὔτε ἐπιδέσεις.",
                question: "Τί θέλει νὰ δείξει ὁ Δωρόθεος μὲ αὐτὴ τὴν ἰατρικὴ εἰκόνα;",
                options: [
                    "Ὅτι ἡ ἀσθένεια τῆς ἁμαρτίας ἦταν ἐπιφανειακὴ καὶ εὔκολα θεραπεύσιμη.",
                    "Ὅτι ἡ κακία εἶχε καλύψει ὅλο τὸν ἄνθρωπο, ὄχι μόνο ἕνα σημεῖο, καὶ χρειαζόταν θεραπεία ἀπ' τὴ ρίζα.",
                    "Ὅτι ὁ Ἡσαΐας ἦταν γιατρὸς πρὶν γίνει προφήτης.",
                    "Ὅτι δὲν ὑπάρχει καμία θεραπεία γιὰ τὴν ἀνθρώπινη κατάσταση."
                ],
                answerIndex: 1,
                explanation: "Ἡ εἰκόνα προετοιμάζει τὸ ἑπόμενο βῆμα τῆς διδαχῆς: ἀφοῦ ἡ ἀρρώστια εἶναι ὁλική, μόνο ὁ ἴδιος ὁ Θεὸς μπορεῖ νὰ θεραπεύσει, ὄχι ὁ νόμος μόνος του."
            ),
            .trueFalse(
                id: "ex3",
                statement: "Ὁ Ἀββᾶς Δωρόθεος λέει ὅτι οἱ προφῆτες ποὺ ἔστειλε ὁ Θεὸς κατάφεραν νὰ διορθώσουν τελείως τὴν κακία τοῦ κόσμου.",
                answer: false,
                explanation: "Λάθος. Ὁ Δωρόθεος λέει ρητὰ ὅτι «οὐδ' αὐτοὶ ἠδυνήθησαν», οὔτε οἱ προφῆτες μπόρεσαν, γιατὶ ὑπερίσχυσε ἡ κακία."
            ),
            .fillBlank(
                id: "ex4",
                textBefore: "Ὁ Ἱερεμίας λέει: Ἰατρεύσαμεν τὴν Βαβυλῶνα καὶ οὐκ",
                textAfter: ", δηλαδὴ δὲν μετανόησε ὅσα κι ἂν ἀκούστηκαν.",
                answer: "ἰάθη",
                options: ["ἰάθη", "ἐσώθη", "ἐπίστευσεν", "ἤκουσεν"],
                explanation: "Ἡ φράση τοῦ Ἱερεμία δείχνει ὅτι ἡ γνώση μόνη της δὲν ἀρκεῖ γιὰ θεραπεία, ἂν δὲν ἀκολουθήσει μετάνοια."
            ),
            .match(
                id: "ex5",
                instruction: "Ἀντιστοίχισε κάθε προφήτη μὲ τὴν εἰκόνα ποὺ χρησιμοποιεῖ γιὰ τὴν κακία.",
                pairs: [
                    MatchPair(left: "Ἡσαΐας", right: "Πληγὴ ποὺ καλύπτει ὅλο τὸ σῶμα"),
                    MatchPair(left: "Ἱερεμίας", right: "Ἡ Βαβυλὼν ποὺ δὲν γιατρεύτηκε παρὰ τὴ θεραπεία"),
                    MatchPair(left: "Δαβίδ", right: "Ἡ ψυχὴ ποὺ ἔφτασε ὣς τὶς πύλες τοῦ θανάτου")
                ],
                explanation: "Κάθε προφήτης χρησιμοποιεῖ διαφορετικὴ εἰκόνα γιὰ τὸ ἴδιο πρᾶγμα: τὸ βάθος τῆς ἀνθρώπινης πτώσης πρὶν τὸν ἐρχομὸ τοῦ Χριστοῦ."
            ),
            .order(
                id: "ex6",
                prompt: "Βάλε αὐτὰ τὰ βήματα τῆς θείας οἰκονομίας μὲ τὴ σειρὰ ποὺ τὰ περιγράφει ὁ Δωρόθεος.",
                items: ["Ὁ Θεὸς δίνει τὸν γραπτὸ νόμο διὰ τοῦ Μωϋσέως", "Στέλνει προφῆτες γιὰ νὰ διορθώσουν τὴν κακία", "Ἡ κακία παραμένει ἀθεράπευτη"],
                explanation: "Ὁ Δωρόθεος δείχνει μιὰ κλιμάκωση προσπαθειῶν πρὶν ἀπ' τὸν ἐρχομὸ τοῦ Χριστοῦ, γιὰ νὰ δείξει πόσο μεγάλη ἦταν ἡ ἀνάγκη."
            ),
            .readingPassage(
                id: "ex7",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ἀγαπήσεις Κύριον τὸν Θεόν σου ἐν ὅλῃ τῇ ψυχῇ σου καὶ ἐν ὅλῃ τῇ διανοίᾳ σου.",
                gloss: "Θ' ἀγαπήσεις τὸν Κύριο τὸν Θεό σου μ' ὅλη τὴν ψυχή σου καὶ μ' ὅλη τὴ διάνοιά σου.",
                question: "Γιατί ὁ Δωρόθεος συνδέει αὐτὴ τὴν ἐντολὴ μὲ τὸ «Κύριος εἷς ἐστιν»;",
                options: [
                    "Γιατὶ θέλει νὰ πεῖ ὅτι ἡ ἀγάπη εἶναι πιὸ σημαντικὴ ἀπ' τὴν πίστη.",
                    "Γιατὶ οἱ δύο ἐντολὲς δὲν σχετίζονται μεταξύ τους.",
                    "Γιατὶ ἡ ἀγάπη πρὸς τὸν Θεὸ ἀφορᾶ μόνο τοὺς ἱερεῖς.",
                    "Γιατὶ τὸ νὰ ἀγαπήσεις τὸν Θεό σου δείχνει ὅτι ὑπάρχει ἕνας μόνο Θεός, πρὸς τὸν ὁποῖο νὰ στραφεῖ ἡ ἀγάπη σου."
                ],
                answerIndex: 3,
                explanation: "Ὁ Δωρόθεος βλέπει βαθιὰ λογικὴ σύνδεση: ἡ ἐντολὴ τῆς ἀγάπης προϋποθέτει καὶ ἐπιβεβαιώνει τὴν ἑνότητα τοῦ Θεοῦ, ἀφοῦ ἡ ἀγάπη δὲν μοιράζεται σὲ πολλοὺς θεούς."
            ),
            .multipleChoice(
                id: "ex8",
                prompt: "Ποιὸς ἦταν, κατὰ τὸν Δωρόθεο, ὁ σκοπὸς τοῦ γραπτοῦ νόμου;",
                options: [
                    "Βοήθεια, ἐπιστροφή, καὶ διόρθωση τῆς κακίας.",
                    "Τιμωρία τῶν ἁμαρτωλῶν χωρὶς δυνατότητα σωτηρίας.",
                    "Ἀντικατάσταση τῆς ἀνάγκης γιὰ τὸν ἐρχομὸ τοῦ Χριστοῦ.",
                    "Διαχωρισμὸς τῶν Ἑβραίων ἀπ' τοὺς ἄλλους λαούς, χωρὶς ἄλλο σκοπό."
                ],
                answerIndex: 0,
                explanation: "Ὁ Δωρόθεος λέει ρητὰ ὅτι ὁ νόμος δόθηκε πρὸς βοήθειαν, πρὸς ἐπιστροφήν, πρὸς διόρθωσιν τῆς κακίας, ὄχι ὡς τιμωρία ἢ διαχωρισμός."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Οὐκ ἔστι μάλαγμα ἐπιθεῖναι οὔτε ἔλαιον οὔτε καταδέσμους.",
            gloss: "Δὲν ὑπάρχει σημεῖο νὰ βάλεις ἐπίδεσμο, οὔτε λάδι, οὔτε ἐπιδέσεις.",
            source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´ (κατὰ τὸν Ἡσαΐα)"
        ),
        xp: 20
    )
}

extension LessonContent {
    static let dorotheosLesson3 = LessonContent(
        id: "ladder-01-dorotheos-lesson-03",
        index: 8,
        title: "Ὁ ἐρχομὸς τοῦ Χριστοῦ",
        teaching: LessonTeaching(
            title: "Ὁ ἐρχομὸς τοῦ Χριστοῦ",
            body: "Ὅταν ἡ κακία ξεπέρασε κάθε ἀνθρώπινη θεραπεία, ὁ Θεὸς ἔστειλε τὸν Υἱό Του: μόνο ὁ Θεὸς μποροῦσε νὰ γιατρέψει τέτοιο πάθος. Ὁ ἅγιος Γρηγόριος τὸ ἐξηγεῖ ἔτσι: «τῷ ὁμοίῳ τὸ ὅμοιον», μὲ τὴν ψυχή Του θεράπευσε τὴν ψυχή μας, μὲ τὴ σάρκα Του τὴ σάρκα μας.\n\nὉ Χριστὸς ἐλευθέρωσε τὸν ἄνθρωπο ἀπ' τὴν τυραννία τοῦ ἐχθροῦ, καὶ τὸ βάπτισμα συγχωρεῖ κάθε ἁμαρτία. Ἀλλὰ ὁ Θεός, γνωρίζοντας ὅτι θὰ ξανααμαρτήσουμε, ἔδωσε ἐντολὲς ποὺ καθαρίζουν ὄχι μόνο τὶς ἁμαρτίες ἀλλὰ καὶ **τὰ ἴδια τὰ πάθη**. Ὁ Δωρόθεος διακρίνει προσεκτικά: τὰ πάθη (θυμός, κενοδοξία, φιληδονία, μῖσος) εἶναι ἡ διάθεση μέσα μας· οἱ ἁμαρτίες εἶναι ὅταν τὰ ἐνεργοῦμε στὴν πράξη. Μπορεῖ κανεὶς νὰ ἔχει πάθη χωρὶς νὰ τὰ ἐνεργεῖ.",
            sources: ["Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Πῶς ἐξηγεῖ ὁ ἅγιος Γρηγόριος, κατὰ τὸν Δωρόθεο, τὸν τρόπο μὲ τὸν ὁποῖο ὁ Χριστὸς θεράπευσε τὸν ἄνθρωπο;",
                options: [
                    "Μὲ θεϊκὴ δύναμη ποὺ δὲν χρειάστηκε νὰ γίνει ἄνθρωπος.",
                    "«Τῷ ὁμοίῳ τὸ ὅμοιον»: μὲ τὴν ψυχή Του τὴν ψυχή μας, μὲ τὴ σάρκα Του τὴ σάρκα μας.",
                    "Μόνο μέσῳ διδασκαλίας καὶ παραδειγμάτων, χωρὶς σωματικὴ παρουσία.",
                    "Ἀντικαθιστώντας ἐντελῶς τὴν ἀνθρώπινη φύση μὲ θεϊκή."
                ],
                answerIndex: 1,
                explanation: "Ὁ Δωρόθεος παραθέτει τὸν ἅγιο Γρηγόριο γιὰ νὰ δείξει γιατί ἦταν ἀναγκαία ἡ Ἐνσάρκωση: ἡ θεραπεία ἔπρεπε νὰ γίνει ἀπὸ μέσα, μὲ τὴν ἴδια οὐσία ποὺ ἀρρώστησε."
            ),
            .readingPassage(
                id: "ex2",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ἄλλα γάρ εἰσι τὰ πάθη καὶ ἄλλαι εἰσὶν αἱ ἁμαρτίαι· τὰ πάθη εἰσὶ θυμός, κενοδοξία, φιληδονία, μῖσος, ἐπιθυμία κακή.",
                gloss: "Ἄλλο εἶναι τὰ πάθη κι ἄλλο οἱ ἁμαρτίες· τὰ πάθη εἶναι ὁ θυμός, ἡ κενοδοξία, ἡ φιληδονία, τὸ μῖσος, ἡ κακὴ ἐπιθυμία.",
                question: "Γιατί εἶναι σημαντικὴ αὐτὴ ἡ διάκριση γιὰ τὸν Δωρόθεο;",
                options: [
                    "Γιατὶ σημαίνει ὅτι τὰ πάθη δὲν εἶναι ποτὲ ἐπικίνδυνα.",
                    "Γιατὶ σημαίνει ὅτι μόνο ἡ ἐξωτερικὴ πράξη μετράει, ὄχι ἡ ἐσωτερικὴ διάθεση.",
                    "Γιατὶ δείχνει ὅτι ὁ ἀγῶνας δὲν σταματάει στὸ νὰ μὴν ἐνεργοῦμε τὰ πάθη, ἀλλὰ φτάνει ὣς τὴν ἴδια τὴ ρίζα τους.",
                    "Γιατὶ οἱ ἁμαρτίες εἶναι χειρότερες ἀπ' τὰ πάθη καὶ χρειάζονται μεγαλύτερη προσοχή."
                ],
                answerIndex: 2,
                explanation: "Ἡ διάκριση αὐτὴ θεμελιώνει ὅλη τὴν ἀσκητικὴ διδασκαλία: δὲν ἀρκεῖ ν' ἀποφεύγεις τὴν πράξη, ὁ στόχος εἶναι νὰ θεραπευτεῖ ἡ ἴδια ἡ διάθεση."
            ),
            .trueFalse(
                id: "ex3",
                statement: "Κατὰ τὸν Δωρόθεο, εἶναι δυνατὸν κάποιος νὰ ἔχει ἕνα πάθος μέσα του χωρὶς ποτὲ νὰ τὸ ἐνεργήσει σὲ πράξη.",
                answer: true,
                explanation: "Σωστό. Ὁ Δωρόθεος λέει ρητά: «ἐνδέχεται τινὰ ἔχειν μὲν τὰ πάθη, μὴ ἐνεργεῖν δὲ αὐτά», μπορεῖ κανεὶς νὰ ἔχει τὰ πάθη χωρὶς νὰ τὰ πράττει."
            ),
            .fillBlank(
                id: "ex4",
                textBefore: "Τὸ ἅγιο βάπτισμα, λέει ὁ Δωρόθεος, συγχωρεῖ πᾶσαν",
                textAfter: "καὶ τὴν ἐξαλείφει ἐντελῶς.",
                answer: "ἁμαρτίαν",
                options: ["ἁμαρτίαν", "μνησικακίαν", "ἀσθένειαν", "λύπην"],
                explanation: "Ὁ Δωρόθεος τονίζει τὴν πληρότητα τῆς συγχώρεσης τοῦ βαπτίσματος, θεμέλιο πάνω στὸ ὁποῖο χτίζεται ἡ ὑπόλοιπη πνευματικὴ ζωή."
            ),
            .match(
                id: "ex5",
                instruction: "Ἀντιστοίχισε κάθε πάθος ποὺ ἀναφέρει ὁ Δωρόθεος μὲ μιὰ σύγχρονη περιγραφή του.",
                pairs: [
                    MatchPair(left: "Κενοδοξία", right: "Ἡ δίψα γιὰ ἔπαινο καὶ ἀναγνώριση"),
                    MatchPair(left: "Φιληδονία", right: "Ἡ προσκόλληση στὴν ἄνεση καὶ τὴν ἀπόλαυση"),
                    MatchPair(left: "Θυμός", right: "Ἡ ἔνταση καὶ ἡ ὀργὴ ἀπέναντι στοὺς ἄλλους")
                ],
                explanation: "Ὁ Δωρόθεος ὀνομάζει συγκεκριμένα πάθη γιατὶ ἡ πνευματικὴ ζωὴ ξεκινᾶ ἀπ' τὴν ἀναγνώρισή τους μέσα μας."
            ),
            .order(
                id: "ex6",
                prompt: "Βάλε αὐτὰ τὰ γεγονότα μὲ τὴ σειρὰ ποὺ τὰ περιγράφει ὁ Δωρόθεος.",
                items: ["Ὁ Θεὸς στέλνει τὸν μονογενῆ Υἱό Του", "Ὁ Χριστὸς ἐλευθερώνει τὸν ἄνθρωπο ἀπ' τὸν ἐχθρό", "Τὸ ἅγιο βάπτισμα συγχωρεῖ πᾶσαν ἁμαρτία"],
                explanation: "Ἡ σειρὰ δείχνει τὴν πληρότητα τοῦ ἔργου τοῦ Χριστοῦ: ἐνσάρκωση, ἀπελευθέρωση, καὶ ἡ πρακτικὴ ἐφαρμογή της στὸ βάπτισμα."
            ),
            .readingPassage(
                id: "ex7",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´ (κατὰ τὸν Ἀπόστολο Παῦλο)",
                passage: "Οὐ γὰρ ὃ θέλω ἀγαθόν, τοῦτο ποιῶ· ἀλλ' ὃ οὐ θέλω κακόν, τοῦτο πράσσω.",
                gloss: "Δὲν κάνω τὸ καλὸ ποὺ θέλω, ἀλλὰ τὸ κακὸ ποὺ δὲν θέλω, αὐτὸ κάνω.",
                question: "Γιατί ὁ Δωρόθεος παραθέτει αὐτὸ τὸ χωρίο τοῦ Ἀποστόλου;",
                options: [
                    "Γιὰ νὰ δείξει πόσο βίαια ἦταν ἡ τυραννία τοῦ ἐχθροῦ πάνω στὸν ἄνθρωπο πρὶν ἀπ' τὴ λύτρωση τοῦ Χριστοῦ.",
                    "Γιὰ νὰ πεῖ ὅτι ὁ Ἀπόστολος Παῦλος ἦταν ἀδύναμος πνευματικά.",
                    "Γιὰ νὰ δικαιολογήσει τὴν ἁμαρτία ὡς ἀναπόφευκτη γιὰ πάντα.",
                    "Γιὰ νὰ δείξει ὅτι ἡ θέληση εἶναι ἄχρηστη ἔννοια."
                ],
                answerIndex: 0,
                explanation: "Ὁ Δωρόθεος χρησιμοποιεῖ τὸ χωρίο γιὰ νὰ δείξει τί ἀκριβῶς μᾶς ἐλευθέρωσε ὁ Χριστός: τὴν ἀναγκαστικὴ ὑποδούλωση στὴν ἁμαρτία, ὄχι τὴν ἴδια τὴ δυνατότητα ἐπιλογῆς."
            ),
            .multipleChoice(
                id: "ex8",
                prompt: "Τί ἔδωσε ὁ Θεός, κατὰ τὸν Δωρόθεο, ἐπιπλέον τῆς συγχώρεσης τοῦ βαπτίσματος, γνωρίζοντας ὅτι θὰ ξανααμαρτήσουμε;",
                options: [
                    "Τίποτα, θεωρώντας ὅτι τὸ βάπτισμα ἀρκεῖ γιὰ πάντα.",
                    "Μιὰ δεύτερη εὐκαιρία βαπτίσματος.",
                    "Ἀγγέλους νὰ μᾶς φυλάσσουν ἀπὸ κάθε πειρασμό.",
                    "Ἅγιες ἐντολὲς ποὺ καθαρίζουν ὄχι μόνο τὶς ἁμαρτίες ἀλλὰ καὶ τὰ ἴδια τὰ πάθη."
                ],
                answerIndex: 3,
                explanation: "Ὁ Δωρόθεος δείχνει τὴν πρόνοια τοῦ Θεοῦ: οἱ ἐντολὲς δὲν εἶναι μόνο κανόνες, εἶναι φάρμακο γιὰ τὴ ρίζα τῶν παθῶν."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Ἄλλα γάρ εἰσι τὰ πάθη καὶ ἄλλαι εἰσὶν αἱ ἁμαρτίαι.",
            gloss: "Ἄλλο εἶναι τὰ πάθη κι ἄλλο οἱ ἁμαρτίες.",
            source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"
        ),
        xp: 20
    )

    static let dorotheosLesson4 = LessonContent(
        id: "ladder-01-dorotheos-lesson-04",
        index: 9,
        title: "Ἡ ρίζα ὅλων τῶν κακῶν",
        teaching: LessonTeaching(
            title: "Ἡ ρίζα ὅλων τῶν κακῶν",
            body: "Ὁ Χριστὸς δὲν καταργεῖ τὸν νόμο, τὸν ἐμβαθύνει. «Ὁ νόμος εἶπε: μὴ μοιχεύσῃς· ἐγὼ δὲ λέγω: μηδὲ ἐπιθυμήσῃς». «Ὁ νόμος εἶπε: μὴ φονεύσῃς· ἐγὼ δὲ λέγω: μηδὲ ὀργισθῇς». Ὁ Δωρόθεος ἐξηγεῖ: ἂν ἔχεις τὴν ἐπιθυμία μέσα σου, ἀκόμα κι ἂν σήμερα δὲν τὴν πράξεις, αὐτὴ θὰ σὲ σπρώχνει μέχρι νὰ σὲ ρίξει τελικά.\n\nΚαὶ φτάνει στὸ κέντρο ὅλης τῆς διδαχῆς: ρωτάει «ἀπὸ ποῦ ἤρθαμε σ' ὅλες αὐτὲς τὶς ἁμαρτίες;» καὶ ἀπαντᾶ μ' ἕναν μόνο λόγο τοῦ Κυρίου: «Μάθετε ἀπ' ἐμοῦ ὅτι πρᾶός εἰμι καὶ ταπεινὸς τῇ καρδίᾳ». Ἡ **ρίζα ὅλων τῶν κακῶν εἶναι ἡ ὑπερηφάνεια**· τὸ φάρμακο εἶναι τὸ ἀκριβῶς ἀντίθετο, ἡ ταπεινοφροσύνη, ὄχι λόγια ἢ πόζα ταπεινότητας, ἀλλὰ διάθεση ταπεινὴ μέσα στὴν ἴδια τὴν καρδιά.",
            sources: ["Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Πῶς ἐμβαθύνει ὁ Χριστός, κατὰ τὸν Δωρόθεο, τὴν ἐντολὴ «μὴ φονεύσῃς»;",
                options: [
                    "Τὴν καταργεῖ ἐντελῶς, θεωρώντας την ξεπερασμένη.",
                    "Τὴν ἀφήνει ἀκριβῶς ὅπως ἦταν, χωρὶς καμία προσθήκη.",
                    "Προσθέτει «μηδὲ ὀργισθῇς», φτάνοντας στὴ ρίζα ἀπ' ὅπου ξεκινάει ὁ φόνος.",
                    "Τὴν περιορίζει μόνο στοὺς ἱερεῖς."
                ],
                answerIndex: 2,
                explanation: "Ὁ Δωρόθεος δείχνει πῶς ὁ Χριστὸς πηγαίνει πίσω ἀπ' τὴν πράξη, στὸ συναίσθημα ποὺ τὴν γεννάει· ἡ ὀργὴ ἀφημένη νὰ μεγαλώσει ὁδηγεῖ σταδιακὰ στὸ φονεῦσαι."
            ),
            .readingPassage(
                id: "ex2",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Μάθετε ἀπ' ἐμοῦ ὅτι πρᾶός εἰμι καὶ ταπεινὸς τῇ καρδίᾳ, καὶ εὑρήσετε ἀνάπαυσιν ταῖς ψυχαῖς ὑμῶν.",
                gloss: "Μάθετε ἀπὸ μένα ὅτι εἶμαι πράος καὶ ταπεινὸς στὴν καρδιά, καὶ θὰ βρεῖτε ἀνάπαυση στὶς ψυχές σας.",
                question: "Γιατί ὁ Δωρόθεος λέει ὅτι σ' αὐτὸ τὸ ἕνα χωρίο ὁ Χριστὸς ἔδειξε τὴ ρίζα καὶ αἰτία πάντων τῶν κακῶν;",
                options: [
                    "Γιατὶ ἡ ἡσυχία εἶναι σημαντικότερη ἀπ' τὴν ταπείνωση.",
                    "Γιατὶ συνδέει τὴν ὑπερηφάνεια μὲ τὴν πτώση, καὶ τὴν ταπείνωση μὲ τὴν ἀνάπαυση, σ' ἕνα μόνο λόγο.",
                    "Γιατὶ ἀναφέρεται ἀποκλειστικὰ στοὺς μοναχούς.",
                    "Γιατὶ εἶναι τὸ μοναδικὸ χωρίο ὅπου μιλάει ὁ Χριστός."
                ],
                answerIndex: 1,
                explanation: "Ὁ Δωρόθεος βλέπει σ' αὐτὸν τὸν σύντομο λόγο ὅλη τὴ διδασκαλία συμπυκνωμένη: ἡ ἔπαρση γεννᾶ τὴν καταφρόνηση, ἡ ταπείνωση γεννᾶ τὴν ὑπακοὴ καὶ τὴ σωτηρία."
            ),
            .trueFalse(
                id: "ex3",
                statement: "Κατὰ τὸν Δωρόθεο, ἡ ἀληθινὴ ταπεινοφροσύνη εἶναι κυρίως θέμα λόγων καὶ ἐξωτερικῆς στάσης.",
                answer: false,
                explanation: "Λάθος. Ὁ Δωρόθεος διευκρινίζει ρητά: ταπείνωση τῆς καρδιᾶς, ὄχι μόνο λόγων ἢ σχήματος."
            ),
            .fillBlank(
                id: "ex4",
                textBefore: "Ὁ νόμος εἶπε: μὴ μοιχεύσῃς· ἐγὼ δὲ λέγω: μηδὲ",
                textAfter: ".",
                answer: "ἐπιθυμήσῃς",
                options: ["ἐπιθυμήσῃς", "ὁμιλήσῃς", "πλησιάσῃς", "σκεφθῇς"],
                explanation: "Ὁ Χριστός, κατὰ τὸν Δωρόθεο, δὲν σταματάει στὴν ἐξωτερικὴ πράξη ἀλλὰ φτάνει στὴν ἐσωτερικὴ ἐπιθυμία, ἀπ' ὅπου ξεκινάει ἡ πτώση."
            ),
            .match(
                id: "ex5",
                instruction: "Ἀντιστοίχισε κάθε ἐντολὴ τοῦ νόμου μὲ τὴν ἐμβάθυνση τοῦ Χριστοῦ, κατὰ τὸν Δωρόθεο.",
                pairs: [
                    MatchPair(left: "Μὴ μοιχεύσῃς", right: "Μηδὲ ἐπιθυμήσῃς"),
                    MatchPair(left: "Μὴ φονεύσῃς", right: "Μηδὲ ὀργισθῇς"),
                    MatchPair(left: "Ὀφθαλμὸν ἀντὶ ὀφθαλμοῦ", right: "Στρέψε καὶ τὴν ἄλλη σιαγόνα")
                ],
                explanation: "Σὲ κάθε περίπτωση ὁ Χριστὸς μεταφέρει τὸ κέντρο τῆς προσοχῆς ἀπ' τὴν πράξη στὴ διάθεση τῆς καρδιᾶς."
            ),
            .order(
                id: "ex6",
                prompt: "Βάλε αὐτὰ τὰ στάδια μὲ τὴ σειρὰ ποὺ περιγράφει ὁ Δωρόθεος γιὰ τὴν ὀργή.",
                items: ["Θυμώνεις καὶ ἐρεθίζεσαι κατὰ τοῦ ἀδελφοῦ", "Πέφτεις στὸ νὰ τὸν κατακρίνεις", "Φτάνεις, μὲ τὸν καιρό, ὣς τὴν ἐπιβουλή"],
                explanation: "Ὁ Δωρόθεος δείχνει προσεκτικὰ πῶς ἕνα μικρὸ πάθος, ἀφημένο ἀφύλακτο, μεγαλώνει βῆμα βῆμα ὣς τὴν καταστροφή."
            ),
            .readingPassage(
                id: "ex7",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ἡ γὰρ ἔπαρσις γεννᾷ τὴν καταφρόνησιν καὶ τὴν παρακοὴν τὴν ὀλεθρίαν, ὥσπερ καὶ ἡ ταπεινοφροσύνη γεννᾷ τὴν ὑπακοὴν καὶ τὴν σωτηρίαν τῶν ψυχῶν.",
                gloss: "Ἡ ὑπερηφάνεια γεννάει τὴν καταφρόνηση καὶ τὴν ὀλέθρια ἀνυπακοή, ὅπως ἡ ταπεινοφροσύνη γεννάει τὴν ὑπακοὴ καὶ τὴ σωτηρία τῶν ψυχῶν.",
                question: "Ποιὰ εἶναι ἡ δομὴ τῆς σκέψης τοῦ Δωροθέου ἐδῶ;",
                options: [
                    "Ὅτι ἡ ὑπακοὴ εἶναι ἀνεξάρτητη ἀπ' τὴν ταπείνωση.",
                    "Ὅτι ἡ σωτηρία ἐξαρτᾶται ἀποκλειστικὰ ἀπ' τὶς ἐξωτερικὲς πράξεις.",
                    "Ὅτι ἡ ὑπερηφάνεια εἶναι ἀβλαβὴς ἂν δὲν ἐκφραστεῖ σὲ λόγια.",
                    "Μιὰ ἀντιστοιχία: κάθε ἀρετὴ ἢ πάθος γεννάει τὸν φυσικό του καρπό, ἡ ταπείνωση τὴν ὑπακοή, ἡ ὑπερηφάνεια τὴν ἀνυπακοή."
                ],
                answerIndex: 3,
                explanation: "Ὁ Δωρόθεος χτίζει μὲ συμμετρία: δύο ρίζες, δύο ἀντίθετοι καρποί, γιὰ νὰ μείνει καθαρὴ ἡ ἐπιλογὴ μπροστὰ στὸν ἀκροατή."
            ),
            .multipleChoice(
                id: "ex8",
                prompt: "Σύμφωνα μὲ τὸν Δωρόθεο, ποιὰ εἶναι ἡ ρίζα καὶ αἰτία πάντων τῶν κακῶν;",
                options: [
                    "Ἡ ὑπερηφάνεια.",
                    "Ἡ φτώχεια.",
                    "Ἡ ἄγνοια τοῦ νόμου.",
                    "Ἡ σωματικὴ ἀδυναμία."
                ],
                answerIndex: 0,
                explanation: "Ὅλη ἡ διδαχὴ τοῦ Δωροθέου συγκλίνει ἐδῶ: ἡ ὑπερηφάνεια εἶναι ἡ ρίζα, ἡ ταπεινοφροσύνη τὸ ἀντίδοτο."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Μάθετε ἀπ' ἐμοῦ ὅτι πρᾶός εἰμι καὶ ταπεινὸς τῇ καρδίᾳ, καὶ εὑρήσετε ἀνάπαυσιν ταῖς ψυχαῖς ὑμῶν.",
            gloss: "Μάθετε ἀπὸ μένα ὅτι εἶμαι πράος καὶ ταπεινὸς στὴν καρδιά, καὶ θὰ βρεῖτε ἀνάπαυση στὶς ψυχές σας.",
            source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"
        ),
        xp: 20
    )

    static let dorotheosLesson5 = LessonContent(
        id: "ladder-01-dorotheos-lesson-05",
        index: 10,
        title: "Ὁ Ἀδὰμ καὶ ἡ Εὔα",
        teaching: LessonTeaching(
            title: "Ὁ Ἀδὰμ καὶ ἡ Εὔα",
            body: "Ὁ Δωρόθεος σταματάει σὲ μιὰ σκηνὴ γνωστὴ σ' ὅλους, γιὰ νὰ δείξει πῶς ἀκριβῶς δουλεύει ἡ ὑπερηφάνεια. Ὁ Ἀδὰμ ζοῦσε μέσα σὲ κάθε τρυφή, χαρά, ἀνάπαυση καὶ δόξα. Μία μόνο ἐντολὴ εἶχε: «μὴ ποιήσῃς τόδε». Καὶ τὸ ἔκανε.\n\nὍταν ὁ Θεὸς τὸν καλεῖ («Ἀδάμ, ποῦ εἶ;», δηλαδή, «ἀπὸ ποιὰ δόξα σὲ ποιὰ ντροπὴ ἔφτασες;»), τοῦ δίνει ἀφορμὴ νὰ πεῖ ἁπλῶς «συγχώρησον». Κι ἐκεῖνος ἀπαντᾶ: «ἡ γυναῖκα ἣν δέδωκάς μοι», ρίχνοντας τὸ βάρος καὶ στὴ γυναίκα καὶ ἔμμεσα στὸν ἴδιο τὸν Θεό. Ἡ Εὔα, μὲ τὴ σειρά της, ρίχνει τὸ βάρος στὸ φίδι. Ὁ Δωρόθεος σχολιάζει, μὲ πόνο: **οὔτε ἕνας ἀπ' τοὺς δύο δὲν βρέθηκε ἄξιος νὰ κατηγορήσει τὸν ἑαυτό του**, οὔτε ἕνας δὲν βρέθηκε μὲ λίγη ταπείνωση.",
            sources: ["Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Τί θὰ μποροῦσε νὰ εἶχε κάνει διαφορετικὰ ὁ Ἀδάμ, κατὰ τὸν Δωρόθεο, ὅταν τὸν ρώτησε ὁ Θεός γιατί ἁμάρτησε;",
                options: [
                    "Νὰ ζητήσει ἀπ' τὸν Θεὸ ἄλλη μία εὐκαιρία χωρὶς ἐξήγηση.",
                    "Νὰ πεῖ ἁπλῶς «συγχώρησον», ἀναγνωρίζοντας τὸ σφάλμα του.",
                    "Νὰ ἐξηγήσει λεπτομερῶς τὴ φύση τοῦ φιδιοῦ.",
                    "Νὰ ζητήσει νὰ τιμωρηθεῖ ἡ γυναίκα ἀντ' αὐτοῦ."
                ],
                answerIndex: 1,
                explanation: "Ὁ Δωρόθεος τονίζει πόσο κοντὰ ἦταν ἡ σωτηρία: μία μόνο λέξη ταπείνωσης, «συγχώρησον», ἔλειψε ἐντελῶς."
            ),
            .readingPassage(
                id: "ex2",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ἡ γυνὴ ἣν δέδωκάς μοι, αὕτη μοι ἔδωκεν.",
                gloss: "Ἡ γυναίκα ποὺ μοῦ ἔδωσες, αὐτὴ μοῦ τὸ ἔδωσε.",
                question: "Γιατί ὁ Δωρόθεος δίνει τόση σημασία στὴ φράση «ἣν δέδωκάς μοι»;",
                options: [
                    "Γιατὶ δείχνει ὅτι ὁ Ἀδὰμ δὲν κατηγορεῖ μόνο τὴ γυναίκα, ἀλλὰ ἔμμεσα καὶ τὸν ἴδιο τὸν Θεὸ ποὺ τοῦ τὴν ἔδωσε.",
                    "Γιατὶ δείχνει ὅτι ὁ Ἀδὰμ ἀγαποῦσε πολὺ τὴ γυναίκα του.",
                    "Γιατὶ ἐξηγεῖ γιατί ὁ γάμος εἶναι ἱερὸ μυστήριο.",
                    "Γιατὶ δείχνει τὴν εὐγνωμοσύνη τοῦ Ἀδὰμ πρὸς τὸν Θεό."
                ],
                answerIndex: 0,
                explanation: "Ὁ Δωρόθεος ἐντοπίζει τὴν πιὸ λεπτὴ μορφὴ ὑπερηφάνειας: ἐκείνη ποὺ ρίχνει τὸ φταίξιμο ἀλλοῦ χωρὶς νὰ φαίνεται ἄμεσα ἐπιθετική."
            ),
            .trueFalse(
                id: "ex3",
                statement: "Κατὰ τὸν Δωρόθεο, ἡ Εὔα, σὲ ἀντίθεση μὲ τὸν Ἀδάμ, ἀνέλαβε τὴν εὐθύνη γιὰ τὸ σφάλμα της.",
                answer: false,
                explanation: "Λάθος. Ὁ Δωρόθεος λέει ὅτι κι ἐκείνη ἀπάντησε «ὁ ὄφις ἠπάτησέ με», ρίχνοντας τὸ βάρος στὸ φίδι, ἀκριβῶς ὅπως ὁ Ἀδὰμ στὴ γυναίκα."
            ),
            .fillBlank(
                id: "ex4",
                textBefore: "Ὁ Δωρόθεος σχολιάζει μὲ πόνο ὅτι οὔτε ἕνας ἀπ' τοὺς δύο δὲν βρέθηκε ἄξιος νὰ",
                textAfter: "τὸν ἑαυτό του.",
                answer: "μέμψασθαι",
                options: ["μέμψασθαι", "δικαιώσαι", "ἐγκωμιάσαι", "λυπηθῆναι"],
                explanation: "Ἡ λέξη μέμψασθαι (νὰ κατηγορήσει) εἶναι τὸ ἀντίθετο ἀκριβῶς ἀπ' αὐτὸ ποὺ ἔκαναν καὶ οἱ δύο: δικαίωσαν τὸν ἑαυτό τους."
            ),
            .match(
                id: "ex5",
                instruction: "Ἀντιστοίχισε ποιὸς κατηγόρησε ποιόν, κατὰ τὴ διήγηση τοῦ Δωροθέου.",
                pairs: [
                    MatchPair(left: "Ὁ Ἀδάμ", right: "Κατηγόρησε τὴ γυναίκα, καὶ ἔμμεσα τὸν Θεό"),
                    MatchPair(left: "Ἡ Εὔα", right: "Κατηγόρησε τὸ φίδι"),
                    MatchPair(left: "Κανένας ἀπ' τοὺς δύο", right: "Δὲν κατηγόρησε τὸν ἑαυτό του")
                ],
                explanation: "Ὁ Δωρόθεος στήνει τὴ διήγηση ἔτσι ὥστε νὰ φανεῖ καθαρὰ ὅτι κανεὶς δὲν ἔκανε τὸ ἁπλὸ βῆμα τῆς αὐτομεμψίας."
            ),
            .order(
                id: "ex6",
                prompt: "Βάλε αὐτὰ τὰ βήματα μὲ τὴ σειρὰ ποὺ τὰ διηγεῖται ὁ Δωρόθεος.",
                items: ["Ὁ Ἀδὰμ ζεῖ μέσα σὲ τρυφὴ καὶ δόξα στὸν παράδεισο", "Παραβαίνει τὴ μοναδικὴ ἐντολή", "Ὁ Θεὸς τὸν καλεῖ νὰ ζητήσει συγχώρεση, μὰ ἐκεῖνος κατηγορεῖ ἄλλους"],
                explanation: "Ἡ πτώση, κατὰ τὸν Δωρόθεο, δὲν εἶναι μόνο ἡ παράβαση, εἶναι καὶ ἡ ἄρνηση νὰ ταπεινωθεῖ κανεὶς μετά."
            ),
            .readingPassage(
                id: "ex7",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ἀδάμ, ποῦ εἶ; ἀντὶ τοῦ· ἀπὸ ποίας δόξης εἰς ποίαν ἦλθες αἰσχύνην;",
                gloss: "«Ἀδάμ, ποῦ εἶσαι;» δηλαδή: ἀπὸ ποιὰ δόξα σὲ ποιὰ ντροπὴ ἔφτασες;",
                question: "Γιατί ὁ Δωρόθεος ἑρμηνεύει ἔτσι αὐτὴ τὴν ἁπλὴ ἐρώτηση τοῦ Θεοῦ;",
                options: [
                    "Γιατὶ ὁ Θεὸς πραγματικὰ δὲν ἤξερε ποῦ βρισκόταν ὁ Ἀδάμ.",
                    "Γιατὶ θέλει νὰ δείξει τὴν ὀργὴ τοῦ Θεοῦ.",
                    "Γιὰ νὰ δείξει ὅτι ἡ ἐρώτηση ἦταν στὴν πραγματικότητα πρόσκληση γιὰ αὐτογνωσία καὶ μετάνοια, ὄχι ἀνάκριση.",
                    "Γιατὶ ὁ Ἀδὰμ εἶχε κρυφτεῖ τόσο καλά, ποὺ χρειαζόταν κυριολεκτικὴ ἀναζήτηση."
                ],
                answerIndex: 2,
                explanation: "Ὁ Δωρόθεος διαβάζει τὴν ἐρώτηση τοῦ Θεοῦ ὄχι ὡς ἄγνοια, ἀλλὰ ὡς εὐκαιρία ποὺ δίνεται στὸν Ἀδὰμ γιὰ νὰ συνειδητοποιήσει τὴν πτώση του."
            ),
            .multipleChoice(
                id: "ex8",
                prompt: "Ποιὸ εἶναι τὸ κεντρικὸ δίδαγμα ποὺ βγάζει ὁ Δωρόθεος ἀπ' αὐτὴ τὴ διήγηση;",
                options: [
                    "Ὅτι ἡ γυναίκα εὐθύνεται περισσότερο ἀπ' τὸν ἄνδρα γιὰ τὴν πτώση.",
                    "Ὅτι ὅταν κάποιος δὲν κρατάει τὴ συνήθεια τῆς αὐτοκριτικῆς, δὲν διστάζει νὰ κατηγορήσει ἀκόμα καὶ τὸν ἴδιο τὸν Θεό.",
                    "Ὅτι τὸ φίδι εἶναι ὁ μόνος πραγματικὰ ἔνοχος.",
                    "Ὅτι ἡ ἱστορία τοῦ Ἀδὰμ δὲν ἔχει καμία σχέση μὲ τὴ δική μας ζωή."
                ],
                answerIndex: 1,
                explanation: "Αὐτὸ εἶναι τὸ βασικὸ συμπέρασμα τοῦ Δωροθέου: ὅταν κάποιος δὲν κρατάει τὸ νὰ κατηγορεῖ τὸν ἑαυτό του, δὲν διστάζει νὰ κατηγορήσει ἀκόμα καὶ τὸν Θεό."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Οὐδὲ εἷς ἐξ αὐτῶν ἠξιώθη μέμψασθαι ἑαυτόν, οὐδὲ εἷς εὑρέθη ἔχων μικρὰν ταπείνωσιν.",
            gloss: "Κανένας ἀπ' τοὺς δύο δὲν βρέθηκε ἄξιος νὰ κατηγορήσει τὸν ἑαυτό του, κανένας δὲν εἶχε λίγη ταπείνωση.",
            source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"
        ),
        xp: 20
    )

    static let dorotheosLesson6 = LessonContent(
        id: "ladder-01-dorotheos-lesson-06",
        index: 11,
        title: "Οἱ καρποὶ τῆς ταπεινώσεως",
        teaching: LessonTeaching(
            title: "Οἱ καρποὶ τῆς ταπεινώσεως",
            body: "Ὁ Δωρόθεος ἀντιπαραθέτει καθαρὰ τοὺς δύο δρόμους. Παιδιὰ τῆς ὑπερηφάνειας εἶναι: τὸ νὰ δικαιώνεις τὸν ἑαυτό σου, τὸ νὰ ἐμπιστεύεσαι τὴ δική σου κρίση, τὸ νὰ κρατᾶς τὸ δικό σου θέλημα. Παιδιὰ τῆς ταπεινοφροσύνης εἶναι τὸ ἀντίθετο: τὸ νὰ κατηγορεῖς τὸν ἑαυτό σου, τὸ νὰ μὴν ἐμπιστεύεσαι τὴ δική σου σύνεση, τὸ νὰ μισεῖς τὸ δικό σου θέλημα.\n\nΠαραθέτει καὶ τὸν Ἀββᾶ Μάρκο: «χωρὶς συντριβὴ καρδιᾶς, ἀδύνατον ν' ἀπαλλαγεῖς ἀπ' τὴν κακία, ἀδύνατο ν' ἀποκτήσεις καθόλου ἀρετή». Γι' αὐτὸ οἱ ἅγιοι Πατέρες, ὅπως ὁ Ἀντώνιος καὶ ὁ Παχώμιος, δὲν ἀρκέστηκαν στὸ νὰ σταματήσουν τὶς πράξεις τῶν παθῶν· θέλησαν νὰ **νικήσουν τὰ ἴδια τὰ πάθη** καὶ νὰ γίνουν ἀπαθεῖς. Ἐπινόησαν γι' αὐτὸ ξένο τρόπο ζωῆς: ἔφυγαν στὴν ἔρημο, ἀφήνοντας πατρίδα, συγγενεῖς, χρήματα, κτήματα.",
            sources: ["Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Ποιὰ ἀπ' τὶς παρακάτω θεωρεῖ ὁ Δωρόθεος «τέκνο τῆς ταπεινοφροσύνης»;",
                options: [
                    "Τὸ νὰ δικαιώνεις πάντα τὸν ἑαυτό σου.",
                    "Τὸ νὰ ἐμπιστεύεσαι ἀπόλυτα τὴ δική σου κρίση.",
                    "Τὸ νὰ κρατᾶς σταθερὰ τὸ δικό σου θέλημα.",
                    "Τὸ νὰ κατηγορεῖς τὸν ἑαυτό σου καὶ νὰ μὴν ἐμπιστεύεσαι τὴ δική σου σύνεση."
                ],
                answerIndex: 3,
                explanation: "Ὁ Δωρόθεος ἀντιπαραθέτει σαφῶς τὰ τέκνα τῆς ὑπερηφάνειας μὲ τὰ τέκνα τῆς ταπεινοφροσύνης."
            ),
            .readingPassage(
                id: "ex2",
                source: "Ἀββᾶς Μάρκος (παρατιθέμενος ἀπ' τὸν Δωρόθεο)",
                passage: "Ἄνευ συντριβῆς καρδίας, ἀδύνατον ἀπαλλαγῆναι ἀπὸ κακίας, ἀδύνατον τὸ καθόλου κτήσασθαι ἀρετήν.",
                gloss: "Χωρὶς συντριβὴ τῆς καρδιᾶς, εἶναι ἀδύνατο ν' ἀπαλλαγεῖς ἀπ' τὴν κακία, ἀδύνατο ν' ἀποκτήσεις καθόλου ἀρετή.",
                question: "Γιατί ὁ Δωρόθεος παραθέτει αὐτὴ τὴ ρήση τοῦ Ἀββᾶ Μάρκου;",
                options: [
                    "Γιὰ νὰ ἐπιβεβαιώσει, μὲ τὴ φωνὴ ἄλλου Πατέρα, ὅτι ἡ ταπείνωση δὲν εἶναι προαιρετικὴ ἀλλὰ ἀπολύτως ἀναγκαία.",
                    "Γιὰ νὰ πεῖ ὅτι ἡ ἀρετὴ ἀποκτιέται μόνο μέσα ἀπ' τὴ θλίψη τοῦ σώματος.",
                    "Γιὰ νὰ ἀμφισβητήσει τὴ σημασία τῆς ἐξομολόγησης.",
                    "Γιὰ νὰ δείξει ὅτι ὁ Ἀββᾶς Μάρκος διαφωνοῦσε μὲ τὸν ἴδιο τὸν Δωρόθεο."
                ],
                answerIndex: 0,
                explanation: "Ὁ Δωρόθεος συχνὰ ἐνισχύει τὸ ἐπιχείρημά του παραθέτοντας ἄλλους Πατέρες, δείχνοντας ὅτι δὲν εἶναι δική του ἰδέα ἀλλὰ κοινὴ πατερικὴ πεῖρα."
            ),
            .trueFalse(
                id: "ex3",
                statement: "Κατὰ τὸν Δωρόθεο, ὁ ἅγιος Ἀντώνιος καὶ ὁ ἅγιος Παχώμιος ἀρκέστηκαν στὸ νὰ μὴν ἐνεργοῦν τὰ πάθη τους, χωρὶς νὰ ἐπιδιώκουν κάτι παραπάνω.",
                answer: false,
                explanation: "Λάθος. Ὁ Δωρόθεος λέει ρητὰ ὅτι θέλησαν νὰ νικήσουν καὶ τὰ ἴδια τὰ πάθη, νὰ γίνουν ἀπαθεῖς, ὄχι μόνο νὰ ἐλέγξουν τὶς πράξεις τους."
            ),
            .fillBlank(
                id: "ex4",
                textBefore: "Ὁ Ἀββᾶς Μάρκος λέει: ἄνευ συντριβῆς",
                textAfter: ", ἀδύνατον ἀπαλλαγῆναι ἀπὸ κακίας.",
                answer: "καρδίας",
                options: ["καρδίας", "σώματος", "χρημάτων", "φίλων"],
                explanation: "Ἡ συντριβὴ καρδίας εἶναι ἐσωτερικὴ κατάσταση, ὄχι σωματικὴ κάκωση· ἀφορᾶ τὴ διάθεση, ὄχι τὸ σῶμα."
            ),
            .match(
                id: "ex5",
                instruction: "Ἀντιστοίχισε κάθε τέκνο μὲ τὴ ρίζα ἀπ' τὴν ὁποία γεννιέται, κατὰ τὸν Δωρόθεο.",
                pairs: [
                    MatchPair(left: "Ἡ αὐτοδικαίωση", right: "Ἡ ὑπερηφάνεια"),
                    MatchPair(left: "Ἡ αὐτομεμψία", right: "Ἡ ταπεινοφροσύνη"),
                    MatchPair(left: "Τὸ νὰ κρατᾶς τὸ ἴδιο θέλημα", right: "Ἡ ὑπερηφάνεια")
                ],
                explanation: "Ὁ Δωρόθεος δείχνει ὅτι κάθε καθημερινὴ συνήθεια, ὅσο μικρὴ κι ἂν φαίνεται, ἔχει ρίζα σὲ μία ἀπ' τὶς δύο βασικὲς διαθέσεις."
            ),
            .order(
                id: "ex6",
                prompt: "Βάλε αὐτὰ τὰ βήματα μὲ τὴ σειρὰ ποὺ τὰ περιγράφει ὁ Δωρόθεος γιὰ τοὺς Πατέρες τῆς ἐρήμου.",
                items: ["Θέλησαν νὰ νικήσουν τὰ ἴδια τὰ πάθη, ὄχι μόνο τὶς πράξεις τους", "Κατάλαβαν ὅτι μέσα στὸν κόσμο δὲν μποροῦσαν εὔκολα νὰ κατορθώσουν τὴν ἀρετή", "Ἔφυγαν στὴν ἔρημο, ἀφήνοντας πατρίδα καὶ συγγενεῖς"],
                explanation: "Ἡ ἀναχώρηση στὴν ἔρημο, κατὰ τὸν Δωρόθεο, δὲν ἦταν ἡ ἀρχὴ ἀλλὰ ἡ συνέπεια μιᾶς βαθύτερης ἀπόφασης."
            ),
            .readingPassage(
                id: "ex7",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ἐγένοντο γάρ τινες φιλόθεοι οἵτινες μετὰ τὸ ἅγιον βάπτισμα οὐ μόνον τὰς ἐνεργείας τῶν παθῶν περιέκοψαν, ἀλλὰ καὶ αὐτὰ τὰ πάθη νικῆσαι ἠβουλήθησαν καὶ γενέσθαι ἀπαθεῖς.",
                gloss: "Ὑπῆρξαν κάποιοι φιλόθεοι ποὺ μετὰ τὸ ἅγιο βάπτισμα δὲν περιόρισαν μόνο τὶς ἐνέργειες τῶν παθῶν, ἀλλὰ θέλησαν νὰ νικήσουν καὶ τὰ ἴδια τὰ πάθη καὶ νὰ γίνουν ἀπαθεῖς.",
                question: "Ποιὸ εἶναι τὸ ὑψηλότερο ἐπίπεδο ἀγῶνα, κατὰ τὴ διάκριση τοῦ Δωροθέου ἐδῶ;",
                options: [
                    "Τὸ νὰ βαπτιστεῖ κανεὶς ξανά.",
                    "Τὸ νὰ νικήσει κανεὶς τὰ ἴδια τὰ πάθη, ὄχι μόνο τὶς ἐξωτερικές τους ἐκφράσεις.",
                    "Τὸ νὰ ἀποφεύγει κανεὶς τὸν κόσμο φυσικά, χωρὶς ἄλλη προσπάθεια.",
                    "Τὸ νὰ γνωρίζει κανεὶς τὴ Γραφὴ ἀπ' ἔξω."
                ],
                answerIndex: 1,
                explanation: "Ὁ Δωρόθεος θέτει τρία ἐπίπεδα: τήρηση ἐντολῶν, περιορισμὸς τῶν ἐνεργειῶν τῶν παθῶν, καὶ τέλος νίκη πάνω στὰ ἴδια τὰ πάθη."
            ),
            .multipleChoice(
                id: "ex8",
                prompt: "Τί ἄφησαν, κατὰ τὸν Δωρόθεο, οἱ Πατέρες ὅταν ἔφυγαν στὴν ἔρημο;",
                options: [
                    "Μόνο τὰ χρήματά τους, κρατώντας τὶς οἰκογενειακές τους σχέσεις.",
                    "Μόνο τὴν πατρίδα τους, κρατώντας τὴν περιουσία τους.",
                    "Πατρίδα, συγγενεῖς, χρήματα καὶ κτήματα, ὅλα μαζί.",
                    "Τίποτα συγκεκριμένο, ἀλλάζοντας μόνο τρόπο σκέψης."
                ],
                answerIndex: 2,
                explanation: "Ὁ Δωρόθεος περιγράφει πλήρη ἀποταγή, ὄχι μερικὲς παραιτήσεις: ἀποταξία πάσης πατρίδος καὶ συγγενῶν, χρημάτων, κτημάτων."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Ἄνευ συντριβῆς καρδίας, ἀδύνατον ἀπαλλαγῆναι ἀπὸ κακίας, ἀδύνατον τὸ καθόλου κτήσασθαι ἀρετήν.",
            gloss: "Χωρὶς συντριβὴ τῆς καρδιᾶς, εἶναι ἀδύνατο ν' ἀπαλλαγεῖς ἀπ' τὴν κακία, ἀδύνατο ν' ἀποκτήσεις καθόλου ἀρετή.",
            source: "Ἀββᾶς Μάρκος, παρατιθέμενος ἀπ' τὸν Ἀββᾶ Δωρόθεο"
        ),
        xp: 20
    )
}

extension LessonContent {
    static let dorotheosLesson7 = LessonContent(
        id: "ladder-01-dorotheos-lesson-07",
        index: 12,
        title: "Τὰ δῶρα πέρα ἀπ' τὶς ἐντολές",
        teaching: LessonTeaching(
            title: "Τὰ δῶρα πέρα ἀπ' τὶς ἐντολές",
            body: "Ὁ Δωρόθεος κάνει μιὰ λεπτὴ διάκριση: ἡ παρθενία καὶ ἡ ἀκτημοσύνη δὲν εἶναι ἐντολές, εἶναι **δῶρα**. Πουθενὰ δὲν εἶναι γραμμένο «μὴ λάβῃς γυναῖκα». Ὅταν ὁ πλούσιος νέος ρώτησε τὸν Χριστὸ τί νὰ κάνει, ὁ Χριστὸς πρῶτα τοῦ εἶπε τὶς ἐντολές· μόνο ὅταν ἐκεῖνος εἶπε ὅτι τὶς τηρεῖ ἤδη, ὁ Χριστὸς πρόσθεσε: «εἰ θέλεις τέλειος εἶναι, πώλησον». Ὄχι «πώλησον» ὡς ἐντολή, ἀλλὰ ὡς συμβουλή, «εἰ θέλεις».\n\nΚαὶ φτάνει στὸ πιὸ λεπτὸ σημεῖο ὅλης τῆς διδαχῆς: ὁ Ἀπόστολος Παῦλος λέει «ἐμοὶ κόσμος ἐσταύρωται, κἀγὼ τῷ κόσμῳ», δύο πράγματα, ὄχι ἕνα. **Ὁ κόσμος σταυρώνεται σ' ἐμᾶς** ὅταν ἀφήνουμε τὰ ἐξωτερικά του πράγματα, γονεῖς, χρήματα. Ἀλλὰ **ἐμεῖς σταυρωνόμαστε στὸν κόσμο** μόνο ὅταν παλεύουμε καὶ ἐνάντια στὶς ἴδιες τὶς ἡδονές, τὶς ἐπιθυμίες, τὰ θελήματά μας. Πολλοὶ κάνουν μόνο τὸ πρῶτο μισό.",
            sources: ["Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Γιατί ὁ Δωρόθεος λέει ὅτι ἡ παρθενία καὶ ἡ ἀκτημοσύνη εἶναι δῶρα καὶ ὄχι ἐντολές;",
                options: [
                    "Γιατὶ πουθενὰ δὲν εἶναι γραμμένη ρητὴ ἐντολὴ γιὰ αὐτές, σὲ ἀντίθεση μὲ τὶς δέκα ἐντολές.",
                    "Γιατὶ εἶναι λιγότερο σημαντικὲς ἀπ' τὶς ἐντολές.",
                    "Γιατὶ ἀφοροῦν μόνο τοὺς ἐπισκόπους.",
                    "Γιατὶ ὁ Χριστὸς δὲν τὶς ἀνέφερε ποτέ."
                ],
                answerIndex: 0,
                explanation: "Ἡ διάκριση ἐντολῆς καὶ δώρου εἶναι σημαντικὴ γιὰ τὸν Δωρόθεο: ἡ ἐντολὴ εἶναι ὑποχρέωση γιὰ ὅλους, τὸ δῶρο εἶναι κάτι παραπάνω, προσφορὰ ἐλεύθερη."
            ),
            .readingPassage(
                id: "ex2",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´ (κατὰ τὸ Εὐαγγέλιο)",
                passage: "Εἰ θέλεις τέλειος εἶναι, πώλησόν σου τὰ ὑπάρχοντα καὶ δὸς πτωχοῖς.",
                gloss: "Ἂν θέλεις νὰ εἶσαι τέλειος, πούλησε ὅ,τι ἔχεις καὶ δῶσε το σὲ φτωχούς.",
                question: "Γιατί ὁ Δωρόθεος ἐπιμένει ὅτι αὐτὸ εἶναι συμβουλὴ κι ὄχι ἐντολή;",
                options: [
                    "Γιατὶ ὁ Χριστὸς δὲν ἐνδιαφερόταν πραγματικὰ ἂν ὁ νέος τὸ ἔκανε.",
                    "Γιατὶ ἡ φτώχεια δὲν εἶναι ἀρετή.",
                    "Γιατὶ ὁ νέος ἦταν ἤδη ἀρκετὰ ἐνάρετος καὶ δὲν χρειαζόταν τίποτα ἄλλο.",
                    "Γιατὶ τὸ «εἰ θέλεις» δηλώνει ἐλεύθερη ἐπιλογή, ὄχι ὑποχρέωση, ὅπως τονίζει ὁ Δωρόθεος."
                ],
                answerIndex: 3,
                explanation: "Ὁ Δωρόθεος ἑστιάζει στὴ γραμματικὴ διατύπωση τοῦ Εὐαγγελίου γιὰ νὰ δείξει τὸ ὕφος τῆς πρότασης: συμβουλή, ὄχι ἐπιταγή."
            ),
            .trueFalse(
                id: "ex3",
                statement: "Κατὰ τὸν Δωρόθεο, ὅποιος ἄφησε ἐξωτερικὰ τὸν κόσμο ἔχει αὐτόματα σταυρωθεῖ κι αὐτὸς στὸν κόσμο, ὄχι μόνο ὁ κόσμος σ' ἐκεῖνον.",
                answer: false,
                explanation: "Λάθος. Ὁ Δωρόθεος διακρίνει καθαρά: τὸ νὰ ἀφήσεις τὸν κόσμο σταυρώνει τὸν κόσμο σ' ἐσένα· τὸ νὰ σταυρωθεῖς κι ἐσὺ στὸν κόσμο χρειάζεται ἐπιπλέον ἀγῶνα ἐνάντια στὶς ἴδιες τὶς ἡδονές."
            ),
            .fillBlank(
                id: "ex4",
                textBefore: "Ὁ Ἀπόστολος Παῦλος λέει: Ἐμοὶ κόσμος ἐσταύρωται,",
                textAfter: ".",
                answer: "κἀγὼ τῷ κόσμῳ",
                options: ["κἀγὼ τῷ κόσμῳ", "καὶ πάλιν ζῶ", "καὶ οὐκέτι ζῶ", "καὶ χαίρω πάντοτε"],
                explanation: "Ἡ πλήρης φράση ἔχει δύο μέρη, καὶ ὁ Δωρόθεος ἐπιμένει ὅτι χρειάζονται καὶ τὰ δύο: ὁ κόσμος νεκρὸς γιὰ μένα, κι ἐγὼ νεκρὸς γιὰ τὸν κόσμο."
            ),
            .match(
                id: "ex5",
                instruction: "Ἀντιστοίχισε κάθε φράση τοῦ Ἀποστόλου μὲ τὴ σημασία της, κατὰ τὸν Δωρόθεο.",
                pairs: [
                    MatchPair(left: "Ἐμοὶ κόσμος ἐσταύρωται", right: "Ἄφησα τὰ ἐξωτερικὰ πράγματα τοῦ κόσμου"),
                    MatchPair(left: "Κἀγὼ τῷ κόσμῳ", right: "Παλεύω καὶ ἐνάντια στὶς ἴδιες τὶς ἐπιθυμίες μου"),
                    MatchPair(left: "Δῶρα στὸν Θεό", right: "Παρθενία καὶ ἀκτημοσύνη, πέρα ἀπ' τὶς ἐντολές")
                ],
                explanation: "Τρία ξεχωριστὰ βήματα ποὺ ὁ Δωρόθεος θέλει νὰ κρατήσει διακριτά, γιὰ νὰ μὴν σταματήσουμε στὸ πρῶτο."
            ),
            .order(
                id: "ex6",
                prompt: "Βάλε αὐτὰ τὰ βήματα μὲ τὴ σειρὰ ποὺ τὰ περιγράφει ὁ Δωρόθεος γιὰ τὸν πλούσιο νέο.",
                items: ["Ρωτάει τὸν Χριστὸ τί νὰ κάνει γιὰ τὴν αἰώνια ζωή", "Λέει ὅτι τηρεῖ ἤδη τὶς ἐντολές", "Ὁ Χριστὸς τοῦ προτείνει, ὡς συμβουλή, νὰ πουλήσει τὰ ὑπάρχοντά του"],
                explanation: "Ἡ σειρὰ δείχνει, κατὰ τὸν Δωρόθεο, ὅτι ἡ συμβουλὴ ἔρχεται μετὰ τὴν τήρηση τῶν ἐντολῶν, ὡς προσθήκη, ὄχι ὡς ὑποκατάστατο."
            ),
            .readingPassage(
                id: "ex7",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ἡμεῖς μὲν ἐδόξαμεν σταυροῦν ἑαυτοῖς τὸν κόσμον, ὅτι ἀφήκαμεν αὐτὸν καὶ ἤλθομεν εἰς τὸ μοναστήριον, ἑαυτοὺς δ' οὐ θέλομεν σταυρῶσαι τῷ κόσμῳ.",
                gloss: "Ἐμεῖς νομίσαμε ὅτι σταυρώσαμε τὸν κόσμο σ' ἐμᾶς, ἐπειδὴ τὸν ἀφήσαμε καὶ ἤρθαμε στὸ μοναστήρι, ἀλλὰ δὲν θέλουμε νὰ σταυρώσουμε κι ἐμεῖς τὸν ἑαυτό μας στὸν κόσμο.",
                question: "Ποιὰ αὐτοκριτικὴ κάνει ἐδῶ ὁ Δωρόθεος πρὸς τὸν ἑαυτό του καὶ τοὺς ἀδελφούς του;",
                options: [
                    "Ὅτι δὲν ἔπρεπε νὰ εἶχαν φύγει καθόλου ἀπ' τὸν κόσμο.",
                    "Ὅτι τὸ μοναστήρι εἶναι χειρότερο ἀπ' τὸν κόσμο.",
                    "Ὅτι ἀρκέστηκαν στὸ πρῶτο, εὐκολότερο βῆμα, χωρὶς νὰ κάνουν τὸ δεύτερο, δυσκολότερο βῆμα.",
                    "Ὅτι δὲν πρέπει κανεὶς ποτὲ νὰ μπεῖ σὲ μοναστήρι."
                ],
                answerIndex: 2,
                explanation: "Εἶναι μιὰ σπάνια στιγμὴ εἰλικρινοῦς αὐτοκριτικῆς: ὁ Δωρόθεος ὁμολογεῖ πὼς ἡ ἐξωτερικὴ ἀλλαγὴ τόπου εἶναι εὔκολη σὲ σύγκριση μὲ τὴν ἐσωτερικὴ ἀλλαγή."
            ),
            .multipleChoice(
                id: "ex8",
                prompt: "Τί παράδειγμα δίνει ὁ Δωρόθεος γιὰ τὸ πῶς οἱ μοναχοὶ συνεχίζουν νὰ προσκολλῶνται σὲ μικρὰ πράγματα;",
                options: [
                    "Τὴν προσκόλληση σὲ μεγάλα κτήματα ποὺ κράτησαν κρυφά.",
                    "Τὴν προσκόλληση σ' ἕνα καλὸ ἐργαλεῖο, ἀφήνοντάς το νὰ πάρει θέση θησαυροῦ στὴν καρδιά.",
                    "Τὴν ἐπιθυμία γιὰ ἐκκλησιαστικὰ ἀξιώματα.",
                    "Τὴν ἐπιθυμία γιὰ ταξίδια στὸν κόσμο."
                ],
                answerIndex: 1,
                explanation: "Τὸ παράδειγμα τοῦ Δωροθέου, μὲ ἀναφορὰ στὸν Ἀββᾶ Ζωσιμᾶ, εἶναι σκόπιμα μικρό: δείχνει πὼς ἡ προσπάθεια στὰ πράγματα ἐπιβιώνει ἀκόμα καὶ σὲ ἀσήμαντα ἀντικείμενα."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Ὥσπερ ἀπεταξάμεθα τῷ κόσμῳ καὶ τοῖς πράγμασιν αὐτοῦ, οὕτως ὀφείλομεν καὶ αὐτῇ τῇ προσπαθείᾳ τῇ περὶ τὰς ὕλας ἀποτάξασθαι.",
            gloss: "Ὅπως ἀποταχθήκαμε στὸν κόσμο καὶ τὰ πράγματά του, ἔτσι πρέπει ν' ἀποταχθοῦμε καὶ στὴν προσκόλληση στὰ ὑλικὰ πράγματα.",
            source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"
        ),
        xp: 20
    )

    static let dorotheosLesson8 = LessonContent(
        id: "ladder-01-dorotheos-lesson-08",
        index: 13,
        title: "Τὰ σύμβολα τοῦ σχήματος",
        teaching: LessonTeaching(
            title: "Τὰ σύμβολα τοῦ σχήματος",
            body: "Ὁ Δωρόθεος ἐξηγεῖ κάτι ποὺ οἱ μοναχοὶ φοροῦν κάθε μέρα χωρὶς πάντα νὰ τὸ σκέφτονται: τί σημαίνει τὸ ἴδιο τὸ ἔνδυμά τους. Τὸ κολόβιο χωρὶς μανίκια θυμίζει ὅτι τὰ χέρια, σύμβολο τῆς πράξης, δὲν πρέπει νὰ ἐνεργοῦν τίποτα τοῦ παλαιοῦ ἀνθρώπου. Τὸ πορφυρὸ σημάδι πάνω του εἶναι σὰν τὸ πορφυρὸ σημάδι ποὺ φορᾶ κάθε στρατιώτης ἑνὸς βασιλιά, δηλώνοντας σὲ ποιὸν ἀνήκει καὶ τί εἶναι ἕτοιμος ν' ἀντέξει γι' αὐτόν.\n\nἩ ζώνη δείχνει ἑτοιμότητα γιὰ ἐργασία, καὶ ταυτόχρονα νέκρωση τῆς ἐπιθυμίας. Ὁ ἀνάλαβος, σταυρωτὰ πάνω στοὺς ὤμους, εἶναι ὁ ἴδιος ὁ σταυρός, ἡ τέλεια νέκρωση. Καὶ τὸ κουκούλλιο, σὰν σκοῦφος βρέφους, εἶναι σύμβολο τῆς ἀκακίας, «νηπιάζετε τῇ κακίᾳ», καὶ τῆς χάριτος τοῦ Θεοῦ ποὺ σκεπάζει τὸν νοῦ μας.",
            sources: ["Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Γιατί, κατὰ τὸν Δωρόθεο, τὸ μοναχικὸ κολόβιο δὲν ἔχει μανίκια;",
                options: [
                    "Γιὰ πρακτικοὺς λόγους, ἐπειδὴ εἶναι πιὸ φθηνὸ ἔτσι.",
                    "Γιατὶ τὰ μανίκια θεωροῦνταν πολυτέλεια στὴν ἐποχή του.",
                    "Γιατὶ τὰ χέρια συμβολίζουν τὴν πράξη, καὶ ἡ ἀπουσία μανικιῶν θυμίζει ὅτι δὲν ἔχουμε χέρια γιὰ νὰ ἐνεργοῦμε τὸν παλαιὸ ἄνθρωπο.",
                    "Γιατὶ οἱ πρῶτοι μοναχοὶ δὲν εἶχαν ὕφασμα ἀρκετὸ γιὰ μανίκια."
                ],
                answerIndex: 2,
                explanation: "Ὁ Δωρόθεος δίνει σὲ κάθε λεπτομέρεια τοῦ ἐνδύματος πνευματικὴ σημασία, ὥστε τὸ ἴδιο τὸ ροῦχο νὰ γίνεται καθημερινὴ ὑπενθύμιση."
            ),
            .readingPassage(
                id: "ex2",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ἕκαστος στρατευόμενος τῷ βασιλεῖ πορφύραν ἔχει εἰς τὸ χλανίδιον αὐτοῦ, ἵνα διὰ τούτου δείξωσιν ὅτι τοῦ βασιλέως εἰσὶ καὶ ὅτι αὐτῷ στρατεύονται.",
                gloss: "Κάθε στρατιώτης τοῦ βασιλιὰ ἔχει πορφυρὸ σημάδι στὴ στολή του, γιὰ νὰ δείξει μ' αὐτὸ ὅτι ἀνήκει στὸν βασιλιὰ καὶ ὑπηρετεῖ σ' αὐτόν.",
                question: "Τί σημαίνει, κατὰ τὸν Δωρόθεο, τὸ ἀντίστοιχο πορφυρὸ σημάδι στὸ μοναχικὸ κολόβιο;",
                options: [
                    "Ὅτι οἱ μοναχοὶ εἶχαν αὐτοκρατορικὴ καταγωγή.",
                    "Ὅτι ὁ μοναχὸς ἀνήκει στὸν Χριστό, τὸν Βασιλέα, καὶ ὀφείλει νὰ ὑπομείνει ὅ,τι Ἐκεῖνος ὑπέμεινε.",
                    "Ὅτι ὁ μοναχὸς ἔχει ξεχωριστὸ κοινωνικὸ κύρος.",
                    "Ὅτι τὸ χρῶμα αὐτὸ ἦταν ἁπλῶς τὸ πιὸ διαθέσιμο τῆς ἐποχῆς."
                ],
                answerIndex: 1,
                explanation: "Ὁ Δωρόθεος συνδέει τὸ πορφυρὸ ἔνδυμα μὲ τὸ πορφυρὸ ἱμάτιο ποὺ φόρεσε ὁ ἴδιος ὁ Χριστὸς στὸ Πάθος Του, ὡς βασιλιὰς καὶ ὡς ἐμπαιζόμενος."
            ),
            .trueFalse(
                id: "ex3",
                statement: "Κατὰ τὸν Δωρόθεο, ἡ μοναχικὴ ζώνη φοριέται μόνο γιὰ πρακτικοὺς λόγους ἐργασίας, χωρὶς ἄλλη πνευματικὴ σημασία.",
                answer: false,
                explanation: "Λάθος. Ὁ Δωρόθεος τῆς δίνει καὶ δεύτερο νόημα: νέκρωση τῆς ἐπιθυμίας, ἀφοῦ φοριέται ἐκεῖ ὅπου λέγεται ὅτι βρίσκεται τὸ ἐπιθυμητικὸ τῆς ψυχῆς."
            ),
            .fillBlank(
                id: "ex4",
                textBefore: "Ὁ ἀνάλαβος τίθεται σταυροειδῶς ἐπὶ τοὺς ὤμους ἡμῶν, τοῦτ' ἔστι, τοῦ",
                textAfter: "τὸ σύμβολον βαστάζομεν εἰς τοὺς ὤμους ἡμῶν.",
                answer: "σταυροῦ",
                options: ["σταυροῦ", "βασιλέως", "ἀγγέλου", "ναοῦ"],
                explanation: "Ὁ ἀνάλαβος, μὲ τὸ σχῆμα του, θυμίζει καθημερινὰ τὴν ἐντολὴ «ἆρον τὸν σταυρόν σου καὶ ἀκολούθει μοι»."
            ),
            .match(
                id: "ex5",
                instruction: "Ἀντιστοίχισε κάθε κομμάτι τοῦ μοναχικοῦ σχήματος μὲ τὸ σύμβολό του, κατὰ τὸν Δωρόθεο.",
                pairs: [
                    MatchPair(left: "Κολόβιο χωρὶς μανίκια", right: "Χέρια χωρὶς δύναμη γιὰ τὸν παλαιὸ ἄνθρωπο"),
                    MatchPair(left: "Ζώνη", right: "Ἑτοιμότητα γιὰ ἐργασία καὶ νέκρωση τῆς ἐπιθυμίας"),
                    MatchPair(left: "Κουκούλλιο", right: "Ἀκακία σὰν βρέφος, καὶ χάρη Θεοῦ ποὺ σκεπάζει τὸν νοῦ")
                ],
                explanation: "Κάθε κομμάτι τοῦ σχήματος, γιὰ τὸν Δωρόθεο, εἶναι διδασκαλία ντυμένη σὲ ὕφασμα, ὄχι ἁπλῶς ἔνδυμα."
            ),
            .order(
                id: "ex6",
                prompt: "Βάλε αὐτὰ τὰ κομμάτια τοῦ σχήματος μὲ τὴ σειρὰ ποὺ τὰ ἐξηγεῖ ὁ Δωρόθεος.",
                items: ["Τὸ κολόβιο χωρὶς μανίκια", "Ἡ ζώνη", "Τὸ κουκούλλιο"],
                explanation: "Ὁ Δωρόθεος περιγράφει τὸ σχῆμα κομμάτι κομμάτι, ἀπ' τὸ ἐξωτερικότερο πρὸς τὸ πιὸ σύνθετο συμβολικά."
            ),
            .readingPassage(
                id: "ex7",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´ (κατὰ τὸν Ἀπόστολο Παῦλο)",
                passage: "Μὴ παιδία γίνεσθε ταῖς φρεσίν, ἀλλὰ τῇ κακίᾳ νηπιάζετε.",
                gloss: "Μὴν εἶστε παιδιὰ στὸ μυαλό, ἀλλὰ νὰ εἶστε σὰν νήπια στὴν κακία.",
                question: "Πῶς ἑρμηνεύει ὁ Δωρόθεος τὸ νηπιάζειν τῇ κακίᾳ;",
                options: [
                    "Ὡς κλήση γιὰ ἀφέλεια καὶ ἔλλειψη κρίσης σὲ κάθε θέμα.",
                    "Ὡς προτροπὴ νὰ μὴ μαθαίνει κανεὶς γράμματα.",
                    "Ὡς ἀπόρριψη κάθε εἴδους σκέψης καὶ προβληματισμοῦ.",
                    "Ὡς τὸ νὰ μὴν ὀργίζεσαι ὅταν σὲ ἀτιμάζουν, νὰ μὴν κενοδοξεῖς ὅταν σὲ τιμοῦν, ὅπως ἀκριβῶς τὸ νήπιο ποὺ δὲν ἔχει κακία."
                ],
                answerIndex: 3,
                explanation: "Ὁ Δωρόθεος δίνει συγκεκριμένο περιεχόμενο στὴ φράση: ἀπάθεια ἀπέναντι σὲ τιμὴ καὶ ἀτιμία, ὄχι ἀφέλεια τοῦ νοῦ."
            ),
            .multipleChoice(
                id: "ex8",
                prompt: "Τί συμβολίζει τὸ κουκούλλιο, ἐκτὸς ἀπ' τὴν ἀκακία, κατὰ τὸ Γεροντικὸ ποὺ παραθέτει ὁ Δωρόθεος;",
                options: [
                    "Τὴ χάρη τοῦ Σωτῆρος ποὺ σκεπάζει τὸν νοῦ μας ἀπ' ὅσους προσπαθοῦν νὰ τὸν πληγώσουν.",
                    "Τὴν κοινωνικὴ θέση τοῦ μοναχοῦ μέσα στὸ μοναστήρι.",
                    "Τὴν προστασία ἀπ' τὸ κρύο τὸν χειμώνα, χωρὶς ἄλλο νόημα.",
                    "Τὴ διαφορὰ ἀνάμεσα σὲ μοναχοὺς καὶ λαϊκούς, χωρὶς πνευματικὸ περιεχόμενο."
                ],
                answerIndex: 0,
                explanation: "Ὁ Δωρόθεος παραθέτει τὸ Γεροντικὸ γιὰ νὰ δώσει στὸ κουκούλλιο διπλὸ νόημα: ταπείνωση ἀπὸ τὴ μιά, προστασία τῆς χάριτος ἀπὸ τὴν ἄλλη."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Ἆρον τὸν σταυρόν σου καὶ ἀκολούθει μοι.",
            gloss: "Σήκωσε τὸν σταυρό σου καὶ ἀκολούθησέ με.",
            source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"
        ),
        xp: 20
    )

    static let dorotheosLesson9 = LessonContent(
        id: "ladder-01-dorotheos-lesson-09",
        index: 14,
        title: "Ἡ κοπὴ τοῦ θελήματος",
        teaching: LessonTeaching(
            title: "Ἡ κοπὴ τοῦ θελήματος",
            body: "Ὁ Δωρόθεος δίνει τὴν πιὸ πρακτικὴ συμβουλή του: τίποτα δὲν ὠφελεῖ τόσο ὅσο **τὸ νὰ κόβεις τὸ ἴδιο σου τὸ θέλημα**. Δίνει παραδείγματα ἀπὸ τὴν καθημερινότητα: περπατᾶς καὶ βλέπεις κάτι, ὁ λογισμὸς λέει «κοίτα ἐκεῖ», καὶ δὲν κοιτᾶς. Ἀκοῦς κάποιους νὰ μιλᾶνε, ὁ λογισμὸς λέει «πὲς κι ἐσὺ αὐτὴ τὴ λέξη», καὶ δὲν τὴ λές. Ρωτᾶς τί μαγειρεύει ὁ μάγειρας, καὶ δὲν ρωτᾶς. Μικρά, καθημερινά, σχεδὸν ἀσήμαντα. Ἀλλὰ ὅποιος τὸ συνηθίσει σὲ μικρά, φτάνει μὲ ἄνεση νὰ τὸ κάνει καὶ σὲ μεγάλα, μέχρι νὰ μὴν ἔχει πιὰ δικό του θέλημα, ὅ,τι κι ἂν συμβεῖ, τὸν ἀναπαύει, γιατὶ δὲν ἔχει τίποτα δικό του νὰ ὑπερασπιστεῖ.\n\nΚαὶ διηγεῖται τὴν ἱστορία τοῦ μακαρίου Δοσιθέου: ἄνθρωπος ποὺ δὲν εἶχε ἀκούσει ποτὲ λόγο Θεοῦ, σχεδὸν ἀφελής, μὰ μέσα σὲ λίγο χρόνο, κρατώντας ὑπακοὴ καὶ κόβοντας τὸ θέλημά του, ἔφτασε τόσο ψηλά, ποὺ ὁ Θεὸς τὸν δόξασε καὶ τὸν φανέρωσε σ' ἕναν ἅγιο γέροντα ἀνάμεσα στοὺς μακάριους.",
            sources: ["Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Ποιὸ παράδειγμα δίνει ὁ Δωρόθεος γιὰ τὸ κόπτειν τὸ θέλημα στὴν καθημερινότητα;",
                options: [
                    "Τὸ νὰ νηστεύεις αὐστηρὰ ὅλη τὴν ἑβδομάδα.",
                    "Τὸ νὰ μὴν κοιτάξεις κάτι ποὺ σὲ τραβάει ἡ περιέργεια, ἢ νὰ μὴν ρωτήσεις τί μαγειρεύεται.",
                    "Τὸ νὰ κάνεις χιλιάδες μετάνοιες κάθε μέρα.",
                    "Τὸ νὰ μιλᾶς μόνο σὲ ξένη γλῶσσα."
                ],
                answerIndex: 1,
                explanation: "Ὁ Δωρόθεος ἐπίτηδες διαλέγει μικρὰ παραδείγματα, γιὰ νὰ δείξει ὅτι ἡ ἄσκηση ξεκινάει ἀπ' τὴν πιὸ ἁπλὴ καθημερινότητα."
            ),
            .readingPassage(
                id: "ex2",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Οὐδὲν γὰρ οὕτως ὠφελεῖ τοὺς ἀνθρώπους, ὡς τὸ κόπτειν τὸ ἴδιον θέλημα.",
                gloss: "Τίποτα δὲν ὠφελεῖ τόσο τοὺς ἀνθρώπους ὅσο τὸ νὰ κόβεις τὸ ἴδιο σου τὸ θέλημα.",
                question: "Γιατί δίνει ὁ Δωρόθεος τόση βαρύτητα σ' αὐτὴ τὴν ἄσκηση, πάνω ἀπ' ὅλες τὶς ἄλλες;",
                options: [
                    "Γιατὶ τὸ ἴδιο θέλημα εἶναι ἡ πηγὴ ἀπ' ὅπου ξεκινοῦν ὅλα τὰ ἄλλα πάθη, καὶ ἡ κοπή του χτυπάει τὴν ἴδια τὴ ρίζα.",
                    "Γιατὶ εἶναι ἡ εὐκολότερη ἄσκηση ἀπ' ὅλες.",
                    "Γιατὶ ἀντικαθιστᾶ τελείως τὴν ἀνάγκη γιὰ προσευχή.",
                    "Γιατὶ ἀφορᾶ μόνο τοὺς νέους μοναχούς, ὄχι τοὺς ἔμπειρους."
                ],
                answerIndex: 0,
                explanation: "Ἡ κοπὴ τοῦ θελήματος συνδέεται εὐθέως μὲ τὴν ταπείνωση καὶ τὴν ὑπακοή, ποὺ εἶναι τὸ κέντρο ὅλης τῆς διδαχῆς τοῦ Δωροθέου."
            ),
            .trueFalse(
                id: "ex3",
                statement: "Κατὰ τὸν Δωρόθεο, ὁ μακάριος Δοσίθεος εἶχε λάβει ἐξαιρετικὴ πνευματικὴ μόρφωση πρὶν μπεῖ στὸ μοναστήρι.",
                answer: false,
                explanation: "Λάθος. Ὁ Δωρόθεος τὸν περιγράφει ὡς ἄνθρωπο ποὺ δὲν εἶχε ἀκούσει ποτὲ λόγο Θεοῦ, σχεδὸν ἀφελῆ, πρὶν φτάσει σὲ μεγάλα πνευματικὰ μέτρα μέσω τῆς ὑπακοῆς."
            ),
            .fillBlank(
                id: "ex4",
                textBefore: "Ἐκ τοῦ γὰρ κόπτειν τινὰ τὸ θέλημα αὐτοῦ, κτᾶται τὴν",
                textAfter: ", καὶ ἐκ ταύτης ἔρχεται σὺν Θεῷ εἰς τελείαν ἀπάθειαν.",
                answer: "ἀπροσπάθειαν",
                options: ["ἀπροσπάθειαν", "εὐγλωττίαν", "εὐπορίαν", "εὐτολμίαν"],
                explanation: "Ὁ Δωρόθεος περιγράφει διαδοχικὰ στάδια: κοπὴ θελήματος, ἀπροσπάθεια, καὶ τέλος ἀπάθεια."
            ),
            .match(
                id: "ex5",
                instruction: "Ἀντιστοίχισε κάθε στάδιο τῆς πορείας ποὺ περιγράφει ὁ Δωρόθεος μὲ τὴ θέση του.",
                pairs: [
                    MatchPair(left: "Κοπὴ τοῦ ἰδίου θελήματος", right: "Πρῶτο βῆμα, στὰ μικρὰ τῆς καθημερινότητας"),
                    MatchPair(left: "Ἀπροσπάθεια", right: "Δεύτερο στάδιο, ἀπελευθέρωση ἀπ' τὴν προσκόλληση"),
                    MatchPair(left: "Ἀπάθεια", right: "Τελικὸς σκοπός, μὲ τὴ βοήθεια τοῦ Θεοῦ")
                ],
                explanation: "Ὁ Δωρόθεος περιγράφει σαφῆ, βηματικὴ πορεία, ὄχι ξαφνικὸ ἅλμα."
            ),
            .order(
                id: "ex6",
                prompt: "Βάλε αὐτὰ τὰ βήματα μὲ τὴ σειρὰ ποὺ περιγράφει ὁ Δωρόθεος γιὰ τὴ συνήθεια τῆς κοπῆς θελήματος.",
                items: ["Κόβεις τὸ θέλημα στὰ μικρά, καθημερινά", "Ἡ συνήθεια σὲ φέρνει νὰ κόβεις μὲ ἄνεση καὶ τὰ μεγάλα", "Δὲν ἔχεις πιὰ δικό σου θέλημα, ὅ,τι γίνεται σὲ ἀναπαύει"],
                explanation: "Ὁ Δωρόθεος δείχνει πῶς ἡ ἐπανάληψη σὲ μικρὰ πράγματα χτίζει σταδιακὰ μιὰ ἐντελῶς νέα διάθεση."
            ),
            .readingPassage(
                id: "ex7",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Πῶς ἐδόξασεν αὐτὸν ὁ Θεὸς καὶ οὐκ ἀφῆκεν εἰς λήθην ἐλθεῖν τὴν τοιαύτην αὐτοῦ ἀρετήν, ἀλλὰ ἀπεκάλυψε τῷ ἁγίῳ γέροντι.",
                gloss: "Πῶς τὸν δόξασε ὁ Θεὸς καὶ δὲν ἄφησε τέτοια ἀρετὴ νὰ ξεχαστεῖ, ἀλλὰ τὴν ἀποκάλυψε στὸν ἅγιο γέροντα.",
                question: "Γιατί ὁ Δωρόθεος διηγεῖται αὐτὴ τὴν ἀποκάλυψη γιὰ τὸν Δοσίθεο;",
                options: [
                    "Γιὰ νὰ δείξει ὅτι μόνο οἱ γνωστοὶ ἀσκητὲς σώζονται.",
                    "Γιὰ νὰ ἀμφισβητήσει τὴν ἀξία τῆς ὑπακοῆς.",
                    "Γιὰ νὰ δείξει, μὲ συγκεκριμένο παράδειγμα, ὅτι σύντομος χρόνος μὲ γνήσια ὑπακοὴ φτάνει σὲ μέτρα ποὺ χρόνια ἄσκησης χωρὶς αὐτὴν δὲν φτάνουν.",
                    "Γιὰ νὰ ἐξηγήσει τὴ διαδικασία τῆς ἁγιοκατάταξης."
                ],
                answerIndex: 2,
                explanation: "Ἡ ἱστορία τοῦ Δοσιθέου εἶναι, γιὰ τὸν Δωρόθεο, ἡ πιὸ πειστικὴ ἀπόδειξη ὅτι ἡ ὑπακοὴ καὶ ἡ κοπὴ θελήματος ἔχουν δύναμη πάνω ἀπ' τὸν χρόνο."
            ),
            .multipleChoice(
                id: "ex8",
                prompt: "Τί συμβαίνει, κατὰ τὸν Δωρόθεο, σ' ὅποιον φτάσει νὰ μὴν ἔχει πιὰ δικό του θέλημα;",
                options: [
                    "Χάνει τὴν ἱκανότητα νὰ σκέφτεται μόνος του.",
                    "Ὅ,τι κι ἂν συμβεῖ, τὸν ἀναπαύει, γιατὶ δὲν ἔχει τίποτα δικό του νὰ ὑπερασπιστεῖ.",
                    "Γίνεται ἀδιάφορος πρὸς τοὺς ἀδελφούς του.",
                    "Χρειάζεται πλέον λιγότερη προσευχή."
                ],
                answerIndex: 1,
                explanation: "Αὐτὸ εἶναι, γιὰ τὸν Δωρόθεο, ἡ οὐσία τῆς ἐλευθερίας ποὺ φέρνει ἡ κοπὴ θελήματος: ὄχι ἀπάθεια πρὸς τοὺς ἄλλους, ἀλλὰ ἐσωτερικὴ εἰρήνη."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Ἐκ τοῦ γὰρ κόπτειν τινὰ τὸ θέλημα αὐτοῦ, κτᾶται τὴν ἀπροσπάθειαν, καὶ ἐκ τῆς ἀπροσπαθείας ἔρχεται σὺν Θεῷ εἰς τελείαν ἀπάθειαν.",
            gloss: "Ὅποιος κόβει τὸ θέλημά του, ἀποκτᾶ τὴν ἀπροσπάθεια, κι ἀπ' αὐτὴν φτάνει, μὲ τὴ βοήθεια τοῦ Θεοῦ, στὴν τέλεια ἀπάθεια.",
            source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"
        ),
        xp: 20
    )

    static let dorotheosLesson10 = LessonContent(
        id: "ladder-01-dorotheos-lesson-10",
        index: 15,
        title: "Ἡ ἀνάπαυση τῆς ὑπακοῆς",
        teaching: LessonTeaching(
            title: "Ἡ ἀνάπαυση τῆς ὑπακοῆς",
            body: "Ὁ Δωρόθεος κλείνει τὴ διδαχή του μὲ ζωντανὲς ἱστορίες ὑπακοῆς. Ἕνας νεαρὸς μοναχός, ἔχοντας ἐντολὴ ἀπ' τὸν γέροντά του νὰ γυρίσει τὸ βράδυ, βρέθηκε μπροστὰ σ' ἕνα ποτάμι φουσκωμένο ἀπὸ σφοδρὴ καταιγίδα. Παρὰ τὶς παρακλήσεις τῶν ἄλλων νὰ μείνει, μπῆκε στὸ ρεῦμα γιὰ χάρη τῆς ὑπακοῆς καὶ βγῆκε ἀβλαβὴς ἀπ' τὴν ἄλλη ὄχθη. Ἄλλος ἀδελφός, βρεθεῖς μπροστὰ σὲ πειρασμό, εἶπε μόνο «διὰ τῶν εὐχῶν τοῦ Πατρός μου, ἐξελοῦ με», καὶ βρέθηκε ἀμέσως ἐκτὸς κινδύνου.\n\nΔιηγεῖται καὶ τὴ δοκιμασία τοῦ ἁγίου Βασιλείου: ζήτησε ἀπὸ ἕναν ἀδελφὸ νὰ τὸν βοηθήσει νὰ νιφτεῖ, μετὰ νὰ δεχτεῖ ἀντίστροφα τὴ βοήθεια, μετὰ νὰ τὸν ὑπενθυμίσει νὰ τὸν χειροτονήσει, καὶ ὁ ἀδελφὸς ὑπάκουσε σὲ ὅλα, χωρὶς νὰ κρίνει. Κι ὁ ἴδιος ὁ Δωρόθεος ὁμολογεῖ κάτι προσωπικό: ρώτησε κάποτε τὸν γέροντα Ἰωάννη γιατί δὲν ἔνιωθε καμιὰ θλίψη, ἀφοῦ ἡ Γραφὴ λέει ὅτι μέσα ἀπὸ πολλὲς θλίψεις μποῦμε στὴ βασιλεία. Ἡ ἀπάντηση: ἡ ὑπακοὴ στοὺς Πατέρες, ἀπὸ μόνη της, χαρίζει αὐτὴ τὴν ἀμεριμνία καὶ τὴν ἀνάπαυση.",
            sources: ["Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"]
        ),
        exercises: [
            .multipleChoice(
                id: "ex1",
                prompt: "Γιατί ὁ νεαρὸς μοναχὸς μπῆκε στὸ φουσκωμένο ποτάμι, παρὰ τὶς παρακλήσεις τῶν ἄλλων νὰ μείνει;",
                options: [
                    "Γιατί ἤθελε νὰ δείξει τὴ δύναμή του στοὺς ἄλλους.",
                    "Γιατί δὲν πίστευε ὅτι ὑπῆρχε πραγματικὸς κίνδυνος.",
                    "Γιατί βιαζόταν γιὰ προσωπικοὺς λόγους.",
                    "Γιατί εἶχε ρητὴ ἐντολὴ ἀπ' τὸν γέροντά του νὰ γυρίσει τὸ βράδυ, καὶ κράτησε τὴν ὑπακοή."
                ],
                answerIndex: 3,
                explanation: "Ὁ Δωρόθεος τονίζει ὅτι δὲν ἦταν παράτολμη πράξη, ἦταν ἀκριβὴς ὑπακοὴ σὲ ἐντολὴ ποὺ εἶχε ἤδη δοθεῖ."
            ),
            .readingPassage(
                id: "ex2",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ὁ Θεός, διὰ τῶν εὐχῶν τοῦ Πατρός μου, ἐξελοῦ με· καὶ εὐθέως εὑρέθη εἰς τὴν ὁδὸν τῆς Σκήτεως.",
                gloss: "Θεέ μου, μὲ τὶς εὐχὲς τοῦ Πατέρα μου, γλίτωσέ με· καὶ ἀμέσως βρέθηκε στὸν δρόμο τῆς Σκήτεως.",
                question: "Τί τονίζει ὁ Δωρόθεος μ' αὐτὴ τὴ σύντομη διήγηση;",
                options: [
                    "Τὴ δύναμη ποὺ ἔχει ἡ ταπεινὴ ἐπίκληση, μέσα ἀπ' τὶς εὐχὲς τοῦ πνευματικοῦ πατέρα, νὰ σώσει ἀμέσως ἀπὸ κίνδυνο.",
                    "Ὅτι ἡ Σκήτη ἦταν πολὺ κοντὰ στὸν τόπο τοῦ πειρασμοῦ.",
                    "Ὅτι ὁ ἀδελφὸς δὲν κινδύνευε πραγματικά.",
                    "Ὅτι ἡ προσευχὴ χρειάζεται πολλὲς λέξεις γιὰ νὰ εἰσακουστεῖ."
                ],
                answerIndex: 0,
                explanation: "Ὁ Δωρόθεος δείχνει τὴ σχέση ἐμπιστοσύνης ἀνάμεσα σὲ ὑποτακτικὸ καὶ πνευματικὸ πατέρα, ποὺ γίνεται ἀσπίδα στὸν πειρασμό."
            ),
            .trueFalse(
                id: "ex3",
                statement: "Στὴ δοκιμασία τοῦ ἁγίου Βασιλείου, ὁ ἀδελφὸς ἀμφισβήτησε γιατί τοῦ ζητοῦσε ν' ἀλλάξουν ρόλους στὸ νίψιμο τῶν χεριῶν.",
                answer: false,
                explanation: "Λάθος. Ὁ Δωρόθεος λέει ρητὰ ὅτι ὁ ἀδελφὸς δέχτηκε τὸ νίμμα ἀδιακρίτως, χωρὶς καμία ἀμφισβήτηση, γι' αὐτὸ καὶ κρίθηκε ἄξιος."
            ),
            .fillBlank(
                id: "ex4",
                textBefore: "Ὁ γέρων Ἰωάννης ἀπάντησε στὸν Δωρόθεο: μηδὲν θλιβῇς· ἕκαστος βάλλων ἑαυτὸν εἰς",
                textAfter: "Πατέρων, ταύτην τὴν ἀμεριμνίαν καὶ τὴν ἀνάπαυσιν ἔχει.",
                answer: "ὑπακοὴν",
                options: ["ὑπακοὴν", "σιωπὴν", "νηστείαν", "μελέτην"],
                explanation: "Ἡ ἀπάντηση τοῦ γέροντα εἶναι ἁπλή: ἡ ὑπακοὴ στοὺς Πατέρες, ἀπὸ μόνη της, χαρίζει τὴν ἀμεριμνία ποὺ ζητοῦσε ὁ Δωρόθεος."
            ),
            .match(
                id: "ex5",
                instruction: "Ἀντιστοίχισε κάθε πρόσωπο τῆς διήγησης μὲ τὸ δίδαγμα ποὺ δίνει.",
                pairs: [
                    MatchPair(left: "Ὁ νεαρὸς στὸ ποτάμι", right: "Ἡ ὑπακοὴ κρατάει ἀβλαβῆ ἀκόμα καὶ σὲ κίνδυνο"),
                    MatchPair(left: "Ὁ ἀδελφὸς στὸν πειρασμό", right: "Ἡ ἐπίκληση τοῦ πνευματικοῦ πατέρα σώζει ἀμέσως"),
                    MatchPair(left: "Ὁ Δωρόθεος μὲ τὸν γέροντα Ἰωάννη", right: "Ἡ ὑπακοὴ ἀπὸ μόνη της χαρίζει ἀνάπαυση")
                ],
                explanation: "Τρεῖς διαφορετικὲς ἱστορίες, ἕνα κοινὸ συμπέρασμα: ἡ ὑπακοὴ δὲν εἶναι βάρος, εἶναι ἀπελευθέρωση."
            ),
            .order(
                id: "ex6",
                prompt: "Βάλε αὐτὰ τὰ βήματα τῆς δοκιμασίας τοῦ ἁγίου Βασιλείου μὲ τὴ σειρά τους.",
                items: ["Ζητάει ἀπ' τὸν ἀδελφὸ νὰ τὸν βοηθήσει νὰ νιφτεῖ", "Τοῦ δίνει τὸ νίμμα νὰ νιφτεῖ κι ἐκεῖνος", "Τὸν χειροτονεῖ, ἀφοῦ τὸν βρῆκε ἄξιο"],
                explanation: "Ὁ ἅγιος Βασίλειος δοκιμάζει σταδιακά, μὲ ὅλο καὶ πιὸ ἀπρόσμενα αἰτήματα, τὴν ἀδιάκριτη ὑπακοὴ τοῦ ἀδελφοῦ."
            ),
            .readingPassage(
                id: "ex7",
                source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                passage: "Ἕκαστος βάλλων ἑαυτὸν εἰς ὑπακοὴν Πατέρων, ταύτην τὴν ἀμεριμνίαν καὶ τὴν ἀνάπαυσιν ἔχει.",
                gloss: "Ὅποιος βάζει τὸν ἑαυτό του σὲ ὑπακοὴ Πατέρων, ἔχει αὐτὴ τὴν ἀμεριμνία καὶ τὴν ἀνάπαυση.",
                question: "Γιατί ὁ Δωρόθεος κλείνει ὁλόκληρη τὴ διδαχή του γιὰ τὴν ἀποταγὴ μ' αὐτὴ τὴ φράση;",
                options: [
                    "Γιὰ νὰ πεῖ ὅτι ἡ ὑπακοὴ ἀντικαθιστᾶ τὴν ἀνάγκη γιὰ ἐντολές.",
                    "Γιατὶ δείχνει, στὴν πράξη, ποῦ ὁδηγεῖ τελικὰ ὅλη ἡ πορεία τῆς ἀποταγῆς: ἀπὸ τὴν πτώση τοῦ Ἀδάμ, μέσ' ἀπ' τὴν ταπείνωση, στὴν ἀνάπαυση τῆς ὑπακοῆς.",
                    "Γιὰ νὰ πεῖ ὅτι ἡ θλίψη δὲν ἔχει καμία θέση στὴν πνευματικὴ ζωή.",
                    "Γιὰ νὰ κλείσει ἁπλῶς μὲ μιὰ γενικὴ συμβουλή, χωρὶς ἰδιαίτερη σύνδεση μὲ τὰ προηγούμενα."
                ],
                answerIndex: 1,
                explanation: "Ὅλη ἡ διδαχὴ τοῦ Δωροθέου εἶναι ἕνας κύκλος: ξεκίνησε ἀπ' τὴν ὑπερηφάνεια τοῦ Ἀδὰμ ποὺ ἔφερε τὴν πτώση, καὶ κλείνει μὲ τὴν ταπεινὴ ὑπακοὴ ποὺ φέρνει τὴν ἀνάπαυση."
            ),
            .multipleChoice(
                id: "ex8",
                prompt: "Τί ρώτησε ὁ Δωρόθεος τὸν γέροντα Ἰωάννη, ἀνήσυχος γιὰ τὸν ἑαυτό του;",
                options: [
                    "Ἂν ἔπρεπε νὰ νηστεύει περισσότερο.",
                    "Ἂν ἔπρεπε ν' ἀλλάξει μοναστήρι.",
                    "Γιατί δὲν εἶχε καμία θλίψη, ἀφοῦ ἡ Γραφὴ λέει ὅτι μέσα ἀπὸ πολλὲς θλίψεις μπαίνουμε στὴ βασιλεία τῶν οὐρανῶν.",
                    "Ἂν ἔπρεπε νὰ γίνει ἱερέας."
                ],
                answerIndex: 2,
                explanation: "Ἡ ἐρώτηση τοῦ Δωροθέου εἶναι εἰλικρινὴς ἀνησυχία: φοβόταν μήπως ἡ ἔλλειψη θλίψεων σήμαινε ὅτι κάτι ἔλειπε ἀπ' τὸν πνευματικό του ἀγῶνα."
            )
        ],
        closing: Closing(
            type: "apophthegm",
            text: "Ἕκαστος βάλλων ἑαυτὸν εἰς ὑπακοὴν Πατέρων, ταύτην τὴν ἀμεριμνίαν καὶ τὴν ἀνάπαυσιν ἔχει.",
            gloss: "Ὅποιος βάζει τὸν ἑαυτό του σὲ ὑπακοὴ Πατέρων, ἔχει αὐτὴ τὴν ἀμεριμνία καὶ τὴν ἀνάπαυση.",
            source: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´"
        ),
        xp: 20
    )
}

/// A named group of lessons drawn from one source — "Ἑνότητα Α´" is the
/// Ladder's own Λόγος Α´, "Ἑνότητα Β´" will be Abba Dorotheos, and so on.
/// Sections make it visible that later lessons are a different voice, not
/// the same material repeated.
struct LessonSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let lessons: [LessonContent]
}

extension LessonContent {
    static func sections(forVirtue id: Int) -> [LessonSection] {
        switch id {
        case 1:
            return [
                LessonSection(
                    id: "apotage-A",
                    title: "ΕΝΟΤΗΤΑ Α´",
                    subtitle: "Κλῖμαξ, Λόγος Α´",
                    lessons: [.sampleApotage, .apotageLesson2, .apotageLesson3, .apotageLesson4, .apotageLesson5]
                ),
                LessonSection(
                    id: "apotage-B",
                    title: "ΕΝΟΤΗΤΑ Β´",
                    subtitle: "Ἀββᾶς Δωρόθεος, Διδαχὴ Α´",
                    lessons: [.dorotheosLesson1, .dorotheosLesson2, .dorotheosLesson3, .dorotheosLesson4, .dorotheosLesson5,
                              .dorotheosLesson6, .dorotheosLesson7, .dorotheosLesson8, .dorotheosLesson9, .dorotheosLesson10]
                )
            ]
        default:
            return []
        }
    }
}

/// Tracks which lessons have been completed, locally on the device. This is
/// what makes "locked until you finish the previous one" actually work,
/// both within a section and across sections — a lesson is locked unless
/// the lesson immediately before it (in the flattened, ordered list) has
/// been completed.
final class LessonProgressStore: ObservableObject {
    static let shared = LessonProgressStore()

    @Published private(set) var completedLessonIDs: Set<String>

    private let storageKey = "klimax.completedLessonIDs"

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        completedLessonIDs = Set(saved)
    }

    func isCompleted(_ lessonID: String) -> Bool {
        completedLessonIDs.contains(lessonID)
    }

    func markCompleted(_ lessonID: String) {
        guard !completedLessonIDs.contains(lessonID) else { return }
        completedLessonIDs.insert(lessonID)
        UserDefaults.standard.set(Array(completedLessonIDs), forKey: storageKey)
    }
}
