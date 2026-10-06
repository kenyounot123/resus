import SwiftUI
import ResusCore

struct CourseForm: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    let create: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New course").font(.title2.weight(.semibold))
            TextField("Course name", text: $title).textFieldStyle(.roundedBorder).accessibilityLabel("Course name")
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Create course") { create(title); dismiss() }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(28).frame(width: 400).tint(Theme.teal).background(Theme.paper)
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) var dismiss
    @State private var key = ""
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings").font(.title2.weight(.semibold))
            Text("Bring your own API key").font(.headline)
            Text("Creating cards sends the selected note and your clarified meanings to the provider. Writing and studying stay offline.").foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            Picker("Provider", selection: $store.provider) { ForEach(Provider.allCases) { Text($0.title).tag($0) } }
            TextField("Model", text: $store.model).textFieldStyle(.roundedBorder).accessibilityLabel("Model")
            SecureField("API key", text: $key).textFieldStyle(.roundedBorder).accessibilityLabel("API key")
            Text("Keys stay in macOS Keychain. API usage is billed separately from chat subscriptions.").font(.callout).foregroundStyle(Theme.secondary)
            HStack {
                Link("Get an API key", destination: URL(string: store.provider == .openAI ? "https://platform.openai.com/api-keys" : "https://platform.claude.com/settings/keys")!)
                Spacer()
                Button("Save key") {
                    saveKey(remove: false)
                }.buttonStyle(PrimaryButtonStyle()).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Remove key") { saveKey(remove: true) }
            }
            if !message.isEmpty { Text(message).font(.callout).foregroundStyle(Theme.teal) }
            Divider()
            Text("Your library").font(.headline)
            HStack { Button("Export backup") { store.exportBackup() }; Button("Restore backup") { store.importBackup() } }
            Text("Backups include notes and cards. They do not include API keys.").font(.callout).foregroundStyle(Theme.secondary)
            Divider()
            Text("Resus 0.1.0 · Open source · MIT License").font(.caption).foregroundStyle(Theme.secondary)
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
        }.padding(30).frame(width: 480).background(Theme.paper).tint(Theme.teal)
        .onChange(of: store.provider) { _, _ in store.model = store.provider.defaultModel; message = ""; key = "" }
    }
    private func saveKey(remove: Bool) {
        let value = remove ? "" : key.trimmingCharacters(in: .whitespacesAndNewlines)
        let vault = store.keychain, provider = store.provider
        message = "Updating Keychain…"
        Task {
            do {
                try await Task.detached { try vault.save(value, provider: provider) }.value
                message = remove ? "Key removed" : "Key saved in Keychain"
                key = ""
            } catch { message = error.localizedDescription }
        }
    }
}

struct CardForm: View {
    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) var dismiss
    let note: Note
    let card: Card?
    @State private var question = ""
    @State private var answer = ""
    @State private var excerpt = ""
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(card == nil ? "New card" : "Review card").font(.title2.weight(.semibold))
            if let card, !card.isCurrent(in: store.library.notes) {
                Text("The note changed. Compare the source, then approve this answer again.").foregroundStyle(Theme.secondary)
                DisclosureGroup("Previous source") { Text(card.source.excerpt).textSelection(.enabled).padding(.vertical, 8) }
            }
            Text("Question").font(.headline)
            TextField("What do you want to remember?", text: $question, axis: .vertical).textFieldStyle(.roundedBorder).accessibilityLabel("Card question").lineLimit(2...4)
            Text("Answer").font(.headline)
            TextEditor(text: $answer).frame(height: 90).scrollContentBackground(.hidden).padding(6).background(.white).clipShape(RoundedRectangle(cornerRadius: 5)).accessibilityLabel("Card answer")
            Text("Source excerpt").font(.headline)
            Text("Use an exact excerpt from the current note.").font(.caption).foregroundStyle(Theme.secondary)
            TextEditor(text: $excerpt).frame(height: 70).scrollContentBackground(.hidden).padding(6).background(.white).clipShape(RoundedRectangle(cornerRadius: 5)).accessibilityLabel("Source excerpt")
            DisclosureGroup("Current note") { ScrollView { Text(note.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 130) }
            if !message.isEmpty { Text(message).foregroundStyle(.red).font(.callout) }
            Text("Approval confirms what you want to study. It does not verify the facts.").font(.caption).foregroundStyle(Theme.secondary)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save draft") { save(approve: false) }
                Button("Approve card") { save(approve: true) }.buttonStyle(PrimaryButtonStyle())
            }
        }.padding(28).frame(width: 570).background(Theme.paper).tint(Theme.teal)
        .onAppear {
            question = card?.question ?? ""; answer = card?.answer ?? ""
            excerpt = card?.source.excerpt ?? String(note.text.prefix(500))
        }
    }
    private func save(approve: Bool) {
        do { try store.saveCard(card?.id, note: note, question: question, answer: answer, excerpt: excerpt, approve: approve); dismiss() }
        catch { message = error.localizedDescription }
    }
}

struct ClarifyView: View {
    @EnvironmentObject var store: StudyStore
    let note: Note
    @State private var meaning = ""
    private var clarifications: [Clarification] { store.library.notes.first(where: { $0.id == note.id })?.preparation?.clarifications ?? [] }
    private var current: Clarification? { clarifications.first { !$0.response.isAnswered } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("Clarify shorthand").font(.headline); Spacer(); Text("\(clarifications.filter { $0.response.isAnswered }.count) of \(clarifications.count)").font(.caption).foregroundStyle(Theme.secondary) }
            ProgressView(value: Double(clarifications.filter { $0.response.isAnswered }.count), total: Double(max(clarifications.count, 1)))
            if let current {
                Text(current.question).font(.system(size: 21, weight: .semibold))
                Text("Confirm what you meant before creating cards.").foregroundStyle(Theme.secondary)
                Text(current.excerpt).textSelection(.enabled).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Theme.paper).clipShape(RoundedRectangle(cornerRadius: 6))
                Text("Meaning").font(.headline)
                TextField("Write the full meaning", text: $meaning, axis: .vertical).textFieldStyle(.roundedBorder).accessibilityLabel("Clarified meaning").lineLimit(2...5)
                Button("Save and next") { store.clarify(note.id, id: current.id, response: .meaning(meaning)); meaning = "" }.buttonStyle(PrimaryButtonStyle()).disabled(meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Exclude this line") { store.clarify(note.id, id: current.id, response: .omit); meaning = "" }.buttonStyle(.plain).foregroundStyle(Theme.teal)
            } else {
                Text("Your meanings are ready").font(.title3.weight(.semibold))
                ForEach(clarifications) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.excerpt).fontWeight(.medium)
                        switch item.response { case .meaning(let text): Text(text).foregroundStyle(Theme.secondary); case .omit: Text("Excluded").foregroundStyle(Theme.secondary); case .unanswered: EmptyView() }
                    }
                }
                Button("Create drafts") { store.createCards(for: note.id) }.buttonStyle(PrimaryButtonStyle()).disabled(store.generating)
            }
            Spacer()
            Text("Clarifications do not rewrite your notes or verify the facts.").font(.caption).foregroundStyle(Theme.secondary)
        }.padding(24).frame(maxHeight: .infinity).background(Theme.panel)
    }
}

struct SourceView: View {
    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) var dismiss
    let card: Card
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Card source").font(.title2.weight(.semibold)); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
            Text("Source saved when this card was created.").font(.callout).foregroundStyle(Theme.secondary)
            Text(card.source.excerpt).textSelection(.enabled).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Theme.selection).clipShape(RoundedRectangle(cornerRadius: 6))
            Text("Original note").font(.headline)
            ScrollView { Text(card.source.noteText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(minHeight: 200, maxHeight: 350)
            if !card.isCurrent(in: store.library.notes) { Text("The current note differs from this saved source.").foregroundStyle(Theme.teal) }
        }.padding(28).frame(width: 600).background(Theme.paper)
    }
}
