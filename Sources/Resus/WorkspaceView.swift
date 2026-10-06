import SwiftUI
import ResusCore

struct SessionRequest: Identifiable { let id = UUID(); let cardIDs: [UUID]; var practice = false }
struct CardSelection: Identifiable { let id: UUID }
enum NoteTab: String, CaseIterable { case notes = "Notes", cards = "Cards" }

struct WorkspaceView: View {
    @EnvironmentObject var store: StudyStore
    @State private var search = ""
    @State private var tab: NoteTab = .notes
    @State private var settings = false
    @State private var newCourse = false
    @State private var manualCard = false
    @State private var editingCard: CardSelection?
    @State private var sourceCard: CardSelection?
    @State private var session: SessionRequest?
    @State private var unclearOnly = false
    private var showsClarification: Bool {
        guard let note = store.note, let preparation = note.preparation else { return false }
        return preparation.clarifications.contains(where: { !$0.response.isAnswered }) || store.cards(for: note.id).isEmpty
    }
    private var visibleNotes: [Note] {
        store.library.notes.filter { note in
            (store.selectedCourse == nil || note.courseID == store.selectedCourse) &&
            (!unclearOnly || note.preparation?.clarifications.contains(where: { !$0.response.isAnswered }) == true || store.changedCount(for: note.id) > 0) &&
            (search.isEmpty || note.title.localizedCaseInsensitiveContains(search) || note.text.localizedCaseInsensitiveContains(search))
        }.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 205)
            Divider()
            if !showsClarification {
                noteList.frame(width: 250)
                Divider()
            }
            if store.loadFailed {
                VStack(spacing: 18) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 40)).foregroundStyle(Theme.teal)
                    Text("Your library needs recovery").font(.title2)
                    Text("Resus preserved the original file. Try the previous saved backup.").foregroundStyle(Theme.secondary)
                    Button("Recover previous backup") { Task { await store.recoverBackup() } }.buttonStyle(PrimaryButtonStyle())
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
            } else if let note = store.note {
                noteDetail(note)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "square.and.pencil").font(.system(size: 44, weight: .light)).foregroundStyle(Theme.teal)
                    Text("Start with your notes").font(.system(size: 26, weight: .semibold))
                    Text("Write here, then turn your notes into cards you can study.").foregroundStyle(Theme.secondary)
                    Button("New note") { store.addNote() }.buttonStyle(PrimaryButtonStyle())
                    Text("Your library stays on this Mac.").font(.callout).foregroundStyle(Theme.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.paper).foregroundStyle(Theme.ink).tint(Theme.teal)
        .frame(minWidth: 1100, minHeight: 700)
        .toolbar {
            ToolbarItem(placement: .navigation) { Text("resus").font(.system(size: 20, weight: .semibold)).tracking(-0.8).foregroundStyle(Theme.teal) }
            ToolbarItem { Button("Import", systemImage: "square.and.arrow.down") { store.importNote() }.disabled(store.loadFailed) }
            ToolbarItem { Button("New note", systemImage: "plus") { store.addNote() }.keyboardShortcut("n").disabled(store.loadFailed) }
        }
        .sheet(isPresented: $settings) { SettingsView().environmentObject(store) }
        .sheet(isPresented: $newCourse) { CourseForm { store.addCourse($0) } }
        .sheet(isPresented: $manualCard) {
            if let note = store.note { CardForm(note: note, card: nil).environmentObject(store) }
        }
        .sheet(item: $editingCard) { selection in
            if let card = store.library.cards.first(where: { $0.id == selection.id }), let note = store.library.notes.first(where: { $0.id == card.source.noteID }) {
                CardForm(note: note, card: card).environmentObject(store)
            }
        }
        .sheet(item: $sourceCard) { selection in
            if let card = store.library.cards.first(where: { $0.id == selection.id }) { SourceView(card: card).environmentObject(store) }
        }
        .sheet(item: $session) { request in StudyView(request: request).environmentObject(store) }
        .alert("Resus", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .onChange(of: store.selectedNote) { _, _ in tab = .notes }
        .onChange(of: store.generating) { old, new in
            if old && !new, let note = store.note, note.preparation?.clarifications.contains(where: { !$0.response.isAnswered }) != true, store.cards(for: note.id).contains(where: { $0.approval == .draft }) { tab = .cards }
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("LIBRARY").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary).padding(.horizontal, 12).padding(.bottom, 12)
            navButton("Study today", icon: "sun.max", count: store.readyCards.filter { $0.dueAt <= Date() }.count) {
                session = SessionRequest(cardIDs: store.readyCards.filter { $0.dueAt <= Date() }.map(\.id))
            }.disabled(store.readyCards.filter { $0.dueAt <= Date() }.isEmpty)
            navButton("All notes", icon: "rectangle.stack", count: store.library.notes.count, selected: store.selectedCourse == nil && !unclearOnly) {
                unclearOnly = false; store.selectedCourse = nil
            }
            navButton("Needs review", icon: "exclamationmark.bubble", count: store.library.notes.filter { $0.preparation?.clarifications.contains(where: { !$0.response.isAnswered }) == true || store.changedCount(for: $0.id) > 0 }.count, selected: unclearOnly) {
                unclearOnly = true; store.selectedCourse = nil
            }
            HStack {
                Text("COURSES").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                Spacer()
                Button { newCourse = true } label: { Image(systemName: "plus") }.buttonStyle(.plain).help("New course").accessibilityLabel("New course")
            }.padding(.horizontal, 12).padding(.top, 24).padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(store.library.courses) { course in
                        navButton(course.title, icon: "book", selected: store.selectedCourse == course.id && !unclearOnly) {
                            unclearOnly = false; store.selectedCourse = course.id
                            store.selectedNote = store.library.notes.first(where: { $0.courseID == course.id })?.id
                        }
                    }
                }
            }
            Spacer()
            navButton("Settings", icon: "gearshape") { settings = true }
            Text(store.saveStatus).font(.caption).foregroundStyle(Theme.secondary).padding(.horizontal, 12).fixedSize(horizontal: false, vertical: true)
            if store.saveStatus.hasPrefix("Could not") { Button("Retry save") { Task { _ = await store.flush() } }.padding(.horizontal, 12) }
        }.padding(.horizontal, 12).padding(.vertical, 24).background(Theme.sidebar)
    }
    private func navButton(_ title: String, icon: String, count: Int? = nil, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 18).foregroundStyle(Theme.secondary)
                Text(title).lineLimit(2)
                Spacer(minLength: 3)
                if let count { Text("\(count)").foregroundStyle(Theme.secondary).font(.callout).monospacedDigit() }
            }.padding(.horizontal, 12).padding(.vertical, 11).contentShape(Rectangle())
        }.buttonStyle(.plain).background(selected ? Theme.selection : .clear).clipShape(RoundedRectangle(cornerRadius: 6))
    }
    private var noteList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Notes").font(.headline); Text("\(visibleNotes.count)").foregroundStyle(Theme.secondary); Spacer() }
            TextField("Search notes", text: $search).textFieldStyle(.roundedBorder).accessibilityLabel("Search notes")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleNotes) { note in
                        Button { store.selectedNote = note.id } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(note.title.isEmpty ? "Untitled note" : note.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                                Text(note.text.isEmpty ? "Start writing" : note.text.replacingOccurrences(of: "\n", with: " ")).lineLimit(2).font(.caption).foregroundStyle(Theme.secondary)
                                Text(status(note)).font(.caption).foregroundStyle(store.changedCount(for: note.id) > 0 ? Theme.teal : Theme.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(13).contentShape(Rectangle())
                        }.buttonStyle(.plain).background(store.selectedNote == note.id ? Theme.selection : .clear).clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    if visibleNotes.isEmpty { Text("No notes here yet.").foregroundStyle(Theme.secondary).padding(.vertical, 16) }
                }
            }
        }.padding(16).background(Theme.panel)
    }
    private func status(_ note: Note) -> String {
        if note.preparation?.clarifications.contains(where: { !$0.response.isAnswered }) == true { return "Clarify your shorthand" }
        let changed = store.changedCount(for: note.id)
        if changed > 0 { return "\(cardCount(changed)) \(changed == 1 ? "needs" : "need") review" }
        let cards = store.cards(for: note.id)
        let drafts = cards.filter { $0.approval == .draft }.count
        return drafts > 0 ? "\(drafts) draft \(drafts == 1 ? "card" : "cards")" : cardCount(cards.count)
    }
    private func noteDetail(_ note: Note) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text(store.library.courses.first(where: { $0.id == note.courseID })?.title ?? "Notes").font(.callout).foregroundStyle(Theme.secondary); Spacer(); Text(store.saveStatus).font(.caption).foregroundStyle(Theme.secondary) }
                TextField("Note title", text: Binding(get: { store.library.notes.first(where: { $0.id == note.id })?.title ?? "" }, set: { store.updateTitle(note.id, title: $0) }))
                    .font(.system(size: 26, weight: .semibold)).textFieldStyle(.plain).accessibilityLabel("Note title")
                HStack(spacing: 20) {
                    ForEach(NoteTab.allCases, id: \.self) { item in
                        Button { tab = item } label: {
                            Text(item == .cards ? "Cards · \(store.cards(for: note.id).count)" : item.rawValue)
                                .fontWeight(tab == item ? .semibold : .regular).foregroundStyle(tab == item ? Theme.teal : Theme.secondary)
                                .padding(.bottom, 10).overlay(alignment: .bottom) { if tab == item { Rectangle().fill(Theme.teal).frame(height: 2) } }
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                    Button("Practice") { session = SessionRequest(cardIDs: store.cards(for: note.id).filter { $0.approval == .approved && $0.isCurrent(in: store.library.notes) }.map(\.id), practice: true) }
                        .buttonStyle(.plain).foregroundStyle(Theme.secondary).disabled(studyCards(note).isEmpty)
                }
                Divider()
                if store.changedCount(for: note.id) > 0 {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes changed · \(cardCount(store.changedCount(for: note.id))) \(store.changedCount(for: note.id) == 1 ? "needs" : "need") review").fontWeight(.semibold)
                            Text("Approved answers stay unchanged until you review.").font(.caption).foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        Button("Review cards") { tab = .cards }
                    }.padding(12).background(Theme.selection).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                if tab == .notes {
                    RichEditor(noteID: note.id, rtf: note.rtf, text: note.text) { store.updateBody(note.id, rtf: $0, text: $1) }.id(note.id.uuidString + store.editorEpoch.uuidString)
                        .frame(maxHeight: .infinity)
                } else { cardsView(note) }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Autosaves on this Mac").font(.caption)
                        Text(store.generating ? "Creating drafts with \(store.provider.title)…" : "AI runs when you create cards.").font(.caption).foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    if store.generating { ProgressView().controlSize(.small); Button("Cancel") { store.cancelGeneration() } }
                    else {
                        Button("Add card") { manualCard = true }.disabled(note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Create cards") { store.createCards(for: note.id) }.buttonStyle(PrimaryButtonStyle())
                            .disabled(note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || note.preparation?.clarifications.contains(where: { !$0.response.isAnswered }) == true)
                    }
                }
            }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            if showsClarification { Divider(); ClarifyView(note: note).environmentObject(store).frame(width: 340) }
        }
    }
    private func studyCards(_ note: Note) -> [Card] { store.cards(for: note.id).filter { $0.approval == .approved && $0.isCurrent(in: store.library.notes) } }
    private func cardsView(_ note: Note) -> some View {
        let cards = store.cards(for: note.id)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Review drafts before you study.").foregroundStyle(Theme.secondary)
                Spacer()
                if cards.contains(where: { $0.approval == .draft && $0.isCurrent(in: store.library.notes) }) {
                    Button("Approve drafts") { store.approveDrafts(for: note.id) }
                }
                Button("Study \(cardCount(studyCards(note).count))") { session = SessionRequest(cardIDs: studyCards(note).map(\.id)) }.buttonStyle(PrimaryButtonStyle()).disabled(studyCards(note).isEmpty)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if cards.isEmpty { Text("Create cards from this note, or add one yourself.").foregroundStyle(Theme.secondary).padding(.vertical, 40) }
                    ForEach(cards) { card in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(card.isCurrent(in: store.library.notes) ? (card.approval == .draft ? "Draft" : "Approved") : "Source changed · Paused").font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                                Spacer()
                                Button("Source") { sourceCard = CardSelection(id: card.id) }.buttonStyle(.plain).foregroundStyle(Theme.teal)
                            }
                            Text(card.question).font(.headline).textSelection(.enabled)
                            Text(card.answer).textSelection(.enabled)
                            HStack {
                                Button(card.isCurrent(in: store.library.notes) ? "Edit" : "Review changes") { editingCard = CardSelection(id: card.id) }
                                if card.approval == .draft && card.isCurrent(in: store.library.notes) { Button("Approve") { store.approve(card.id) }.buttonStyle(PrimaryButtonStyle()) }
                                Spacer()
                                Button("Remove", role: .destructive) { store.removeCard(card.id) }
                            }
                        }.padding(.vertical, 20)
                        Divider()
                    }
                }
            }
        }.frame(maxHeight: .infinity)
    }
}
