import SwiftUI
import ResusCore

struct StudyView: View {
    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) var dismiss
    let request: SessionRequest
    @State private var index = 0
    @State private var revealed = false
    @State private var practice = false
    @State private var writtenAnswer = ""
    @State private var sourceOpen = false
    @State private var remembered = 0
    private var cards: [Card] { request.cardIDs.compactMap { id in store.library.cards.first { $0.id == id } } }
    private var card: Card? { index < cards.count ? cards[index] : nil }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("resus").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.teal)
                Text("Study").foregroundStyle(Theme.secondary)
                Spacer()
                Picker("Study mode", selection: $practice) { Text("Flashcards").tag(false); Text("Practice").tag(true) }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
                Spacer()
                Button("Source", systemImage: "sidebar.right") { sourceOpen.toggle() }.disabled(card == nil)
                Button("Finish") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20).background(Theme.panel)
            Divider()
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 22) {
                    if let card, card.isCurrent(in: store.library.notes), card.approval == .approved {
                        HStack { Text("Card \(index + 1) of \(cards.count)"); Spacer(); Text("\(index) reviewed") }.font(.callout).foregroundStyle(Theme.secondary)
                        ProgressView(value: Double(index), total: Double(max(cards.count, 1)))
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                Text("QUESTION").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                                Text(card.question).font(.system(size: 28, weight: .semibold)).textSelection(.enabled).accessibilityIdentifier("studyQuestion")
                                if practice && !revealed {
                                    TextEditor(text: $writtenAnswer).frame(height: 150).scrollContentBackground(.hidden).padding(10).background(Theme.panel).clipShape(RoundedRectangle(cornerRadius: 6)).accessibilityLabel("Your answer")
                                }
                                if revealed {
                                    Divider()
                                    if practice {
                                        Text("YOUR ANSWER").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                                        Text(writtenAnswer).foregroundStyle(Theme.secondary).textSelection(.enabled)
                                    }
                                    Text("APPROVED ANSWER").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                                    Text(card.answer).font(.system(size: 24)).textSelection(.enabled).accessibilityIdentifier("approvedAnswer")
                                }
                            }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
                        }.background(Theme.paper).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.secondary.opacity(0.18))).frame(maxHeight: .infinity)
                        HStack { Spacer(); if revealed {
                            VStack(spacing: 12) {
                                Text(practice ? "Compare your answer, then rate it yourself." : "Did you remember the answer?").foregroundStyle(Theme.secondary)
                                HStack(spacing: 14) {
                                    Button("Review again") { rate(card, .again) }.keyboardShortcut("1", modifiers: [])
                                    Button("Remembered") { rate(card, .remembered) }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut("2", modifiers: [])
                                }
                            }
                        } else {
                            Button(practice ? "Compare answer" : "Reveal answer") { revealed = true }.buttonStyle(PrimaryButtonStyle())
                                .keyboardShortcut(.space, modifiers: []).disabled(practice && writtenAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }; Spacer() }
                        Text(practice ? "Practice uses your approved answers. No AI grading." : "Try recalling the answer before opening its source.").font(.caption).foregroundStyle(Theme.secondary)
                    } else if card != nil {
                        Spacer()
                        Text("This card needs review").font(.title2)
                        Text("Its source changed. Review it in your library before studying.").foregroundStyle(Theme.secondary)
                        Button("Next card") { advance() }.buttonStyle(PrimaryButtonStyle())
                        Spacer()
                    } else {
                        Spacer()
                        Image(systemName: "checkmark.circle").font(.system(size: 42, weight: .light)).foregroundStyle(Theme.teal)
                        Text("Session complete").font(.system(size: 28, weight: .semibold))
                        Text("You reviewed \(cardCount(index)) and remembered \(remembered).").foregroundStyle(Theme.secondary)
                        Text("Remembered cards return later. Cards to review again return in 10 minutes.").font(.callout).foregroundStyle(Theme.secondary)
                        Button("Back to notes") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                        Spacer()
                    }
                }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
                if sourceOpen, let card {
                    Divider()
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Card source").font(.headline)
                        Text(card.source.excerpt).textSelection(.enabled).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Theme.selection)
                        ScrollView { Text(card.source.noteText).font(.callout).foregroundStyle(Theme.secondary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        Text("Saved when this card was created.").font(.caption).foregroundStyle(Theme.secondary)
                    }.padding(24).frame(width: 280, height: 550).background(Theme.panel)
                }
            }
        }.frame(width: 1020, height: 700).background(Theme.paper).foregroundStyle(Theme.ink).tint(Theme.teal)
        .onAppear { practice = request.practice }
        .onChange(of: practice) { _, _ in revealed = false; writtenAnswer = ""; sourceOpen = false }
    }
    private func rate(_ card: Card, _ rating: Rating) {
        store.rate(card.id, rating)
        if rating == .remembered { remembered += 1 }
        advance()
    }
    private func advance() { index += 1; revealed = false; writtenAnswer = ""; sourceOpen = false }
}
