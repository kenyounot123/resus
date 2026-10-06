import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ResusCore

@MainActor final class StudyStore: ObservableObject {
    @Published private(set) var library: Library = Library()
    @Published var selectedCourse: UUID?
    @Published var selectedNote: UUID?
    @Published var error: String?
    @Published private(set) var saveStatus = "Saved on this Mac"
    @Published private(set) var loadFailed = false
    @Published private(set) var generating = false
    @Published private(set) var editorEpoch = UUID()
    @Published var provider: Provider { didSet { preferences.set(provider.rawValue, forKey: "provider") } }
    @Published var model: String { didSet { preferences.set(model, forKey: "model") } }
    let archive: Archive
    let keychain: Keychain
    let preferences: UserDefaults
    private var revision: UInt64 = 0
    private var pendingSave: Task<Void, Never>?
    private var generationTask: Task<Void, Never>?
    private var generationID: UUID?

    init(url: URL, isolated: Bool) {
        archive = Archive(url: url)
        let suffix = isolated ? url.deletingLastPathComponent().lastPathComponent : "default"
        keychain = Keychain(service: "com.kenyounot123.resus.\(suffix)")
        preferences = UserDefaults(suiteName: "com.kenyounot123.resus.\(suffix)") ?? .standard
        let chosenProvider = Provider(rawValue: preferences.string(forKey: "provider") ?? "") ?? .openAI
        provider = chosenProvider
        model = preferences.string(forKey: "model") ?? chosenProvider.defaultModel
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                library = try Archive.read(url)
                try Self.validateRichText(library)
            } else { library = Library() }
        } catch {
            library = Library(); loadFailed = true
            self.error = "Your library could not be opened. The original file has been preserved. \(error.localizedDescription)"
        }
        selectedCourse = library.courses.first?.id
        selectedNote = library.notes.sorted { $0.modifiedAt > $1.modifiedAt }.first?.id
    }
    var note: Note? { library.notes.first { $0.id == selectedNote } }
    var readyCards: [Card] { library.cards.filter { $0.approval == .approved && $0.isCurrent(in: library.notes) } }
    func cards(for id: UUID) -> [Card] { library.cards.filter { $0.source.noteID == id } }
    func changedCount(for id: UUID) -> Int { cards(for: id).filter { !$0.isCurrent(in: library.notes) }.count }
    func addCourse(_ title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !loadFailed else { return }
        let course = Course(title: title)
        library.courses.append(course); selectedCourse = course.id; selectedNote = nil; changed()
    }
    func addNote() {
        guard !loadFailed else { return }
        if library.courses.isEmpty { addCourse("My studies") }
        guard let courseID = selectedCourse ?? library.courses.first?.id else { return }
        let note = Note(courseID: courseID, title: "Untitled note")
        library.notes.insert(note, at: 0); selectedNote = note.id; selectedCourse = courseID; changed()
    }
    func updateTitle(_ id: UUID, title: String) {
        guard let index = library.notes.firstIndex(where: { $0.id == id }) else { return }
        library.notes[index].title = title; library.notes[index].modifiedAt = Date(); changed()
    }
    func updateBody(_ id: UUID, rtf: Data, text: String) {
        guard let index = library.notes.firstIndex(where: { $0.id == id }), !loadFailed else { return }
        guard text.utf8.count <= 2_000_000, rtf.count <= 10_000_000 else {
            saveStatus = "This note is too large. Shorten it to save."
            error = "Keep a note under 2 MB of text and 10 MB of formatting."
            return
        }
        if library.notes[index].text != text { library.notes[index].preparation = nil }
        library.notes[index].rtf = rtf; library.notes[index].text = text
        library.notes[index].modifiedAt = Date(); changed()
    }
    func saveCard(_ cardID: UUID?, note: Note, question: String, answer: String, excerpt: String, approve: Bool) throws {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !answer.isEmpty, !excerpt.isEmpty, note.text.contains(excerpt),
              library.notes.first(where: { $0.id == note.id })?.text == note.text else {
            throw ResusError.invalid("Add a question, an answer, and an exact excerpt from the current note.")
        }
        let source = Source(noteID: note.id, noteText: note.text, excerpt: excerpt)
        if let id = cardID, let index = library.cards.firstIndex(where: { $0.id == id }) {
            library.cards[index].question = question; library.cards[index].answer = answer
            library.cards[index].source = source; library.cards[index].approval = approve ? .approved : .draft
            library.cards[index].intervalDays = 0; library.cards[index].dueAt = Date()
        } else { library.cards.append(Card(source: source, question: question, answer: answer, approval: approve ? .approved : .draft)) }
        changed()
    }
    func approve(_ id: UUID) {
        guard let index = library.cards.firstIndex(where: { $0.id == id }), library.cards[index].isCurrent(in: library.notes) else { return }
        library.cards[index].approval = .approved; changed()
    }
    func approveDrafts(for id: UUID) {
        for index in library.cards.indices where library.cards[index].source.noteID == id && library.cards[index].isCurrent(in: library.notes) {
            library.cards[index].approval = .approved
        }
        changed()
    }
    func removeCard(_ id: UUID) { library.cards.removeAll { $0.id == id }; changed() }
    func rate(_ id: UUID, _ rating: Rating) {
        guard let index = library.cards.firstIndex(where: { $0.id == id }), library.cards[index].approval == .approved,
              library.cards[index].isCurrent(in: library.notes) else { return }
        library.cards[index].rate(rating); changed()
    }
    func clarify(_ noteID: UUID, id: UUID, response: ClarificationResponse) {
        guard let n = library.notes.firstIndex(where: { $0.id == noteID }),
              let c = library.notes[n].preparation?.clarifications.firstIndex(where: { $0.id == id }) else { return }
        library.notes[n].preparation?.clarifications[c].response = response; changed()
    }
    func createCards(for noteID: UUID) {
        guard !generating, !loadFailed, let note = library.notes.first(where: { $0.id == noteID }) else { return }
        let requestID = UUID(); generationID = requestID; generating = true
        let provider = provider, model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        generationTask = Task { [weak self] in
            guard let self else { return }
            defer { if self.generationID == requestID { self.generating = false; self.generationTask = nil } }
            do {
                let vault = self.keychain
                let key = try await Task.detached { try vault.read(provider) }.value
                guard !key.isEmpty else { throw ResusError.invalid("Add your API key in Settings, or create a card manually.") }
                guard !model.isEmpty else { throw ResusError.invalid("Choose a model in Settings.") }
                let clarifications = note.preparation?.noteText == note.text ? note.preparation?.clarifications ?? [] : []
                var generator = Generator()
                #if DEBUG
                if let endpoint = ProcessInfo.processInfo.environment["RESUS_TEST_ENDPOINT"], let url = URL(string: endpoint), url.host == "127.0.0.1" {
                    generator = Generator(endpoint: url)
                }
                #endif
                let result = try await generator.generate(note: note, clarifications: clarifications, provider: provider, model: model, key: key)
                try Task.checkCancellation()
                guard self.generationID == requestID, let index = self.library.notes.firstIndex(where: { $0.id == noteID }),
                      self.library.notes[index].text == note.text else { throw ResusError.invalid("The note changed during generation. Create cards again from the updated note.") }
                if !result.clarifications.isEmpty {
                    let questions = result.clarifications.map { Clarification(excerpt: $0.excerpt, question: $0.question) }
                    self.library.notes[index].preparation = try Preparation(noteText: note.text, clarifications: clarifications).adding(questions)
                } else {
                    self.library.notes[index].preparation = clarifications.isEmpty ? nil : Preparation(noteText: note.text, clarifications: clarifications)
                    self.library.cards.append(contentsOf: result.cards.map { Card(source: Source(noteID: note.id, noteText: note.text, excerpt: $0.excerpt), question: $0.question, answer: $0.answer) })
                }
                self.changed()
            } catch is CancellationError { } catch { if self.generationID == requestID { self.error = error.localizedDescription } }
        }
    }
    func cancelGeneration() {
        generationTask?.cancel(); generationTask = nil; generationID = nil; generating = false
    }
    private func changed() {
        guard !loadFailed else { return }
        revision += 1; saveStatus = "Saving…"
        pendingSave?.cancel()
        let snapshot = library, revision = revision
        pendingSave = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(200))
                guard let self else { return }
                try await self.archive.save(snapshot, revision: revision)
                if self.revision == revision { self.saveStatus = "Saved on this Mac" }
            } catch is CancellationError { } catch {
                guard let self else { return }
                self.saveStatus = "Could not save. Export a backup or retry."
                self.error = error.localizedDescription
            }
        }
    }
    func flush() async -> Bool {
        guard !loadFailed else { return false }
        pendingSave?.cancel()
        do {
            try await archive.save(library, revision: revision)
            saveStatus = "Saved on this Mac"; return true
        } catch { saveStatus = "Could not save. Export a backup or retry."; self.error = error.localizedDescription; return false }
    }
    func recoverBackup() async {
        do {
            let recovered = try await archive.previous()
            try Self.validateRichText(recovered)
            try await archive.restore(recovered)
            library = recovered; editorEpoch = UUID(); loadFailed = false; selectedCourse = library.courses.first?.id
            selectedNote = library.notes.first?.id; error = nil; saveStatus = "Backup recovered"
        } catch { self.error = "The previous backup could not be opened. \(error.localizedDescription)" }
    }
    func exportBackup() {
        let panel = NSSavePanel()
        panel.title = "Export your library"; panel.nameFieldStringValue = "Resus-backup.resus"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try Archive.encode(library).write(to: url, options: .atomic) } catch { self.error = error.localizedDescription }
    }
    func importBackup() {
        let panel = NSOpenPanel(); panel.title = "Restore a Resus backup"; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let imported = try Archive.read(url); try Self.validateRichText(imported)
            let alert = NSAlert(); alert.messageText = "Replace this library?"
            alert.informativeText = "This replaces your notes and cards with the backup. Export your current library first if you want to keep it."
            alert.addButton(withTitle: "Replace library"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            cancelGeneration(); pendingSave?.cancel()
            Task {
                if !loadFailed { guard await flush() else { return } }
                do { try await archive.restore(imported) }
                catch { self.error = error.localizedDescription; return }
                loadFailed = false
                library = imported; editorEpoch = UUID(); selectedCourse = library.courses.first?.id; selectedNote = library.notes.first?.id; changed()
            }
        } catch { self.error = error.localizedDescription }
    }
    func importNote() {
        let panel = NSOpenPanel(); panel.title = "Import a note"; panel.allowedContentTypes = [.plainText, .rtf]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < 10_000_000 else { throw ResusError.invalid("Choose a note smaller than 10 MB.") }
            let attributed: NSAttributedString
            if url.pathExtension.lowercased() == "rtf" {
                attributed = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            } else {
                guard let text = String(data: data, encoding: .utf8) else { throw ResusError.invalid("Choose a UTF-8 text file or an RTF document.") }
                attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 16)])
            }
            let rtf = try attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            let canonical = RichTextCodec.text(try RichTextCodec.decode(rtf))
            guard canonical.utf8.count <= 2_000_000, rtf.count <= 10_000_000 else { throw ResusError.invalid("Keep a note under 2 MB of text and 10 MB of formatting.") }
            addNote()
            guard let id = selectedNote else { return }
            updateTitle(id, title: url.deletingPathExtension().lastPathComponent)
            updateBody(id, rtf: rtf, text: canonical)
        } catch { self.error = error.localizedDescription }
    }
    static func validateRichText(_ library: Library) throws {
        for note in library.notes where !note.rtf.isEmpty {
            let text = RichTextCodec.text(try RichTextCodec.decode(note.rtf))
            guard text == note.text else { throw ResusError.invalid("A note's formatted text does not match its saved text.") }
        }
    }
}
