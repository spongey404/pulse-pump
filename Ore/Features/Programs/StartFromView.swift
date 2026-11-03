import SwiftUI

/// Start from (Ore Programs 02): a full-screen page, not a sheet. Blank, or a template that fills the form.
struct StartFromView: View {
    let onBack: () -> Void
    let onPick: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProgramPageHeader(kicker: "NEW PROGRAM", title: "START FROM", onBack: onBack)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(ProgramTemplates.all) { choice in
                        Button { onPick(choice.id) } label: {
                            HStack(spacing: 14) {
                                tile(choice)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(choice.name).font(.archivo(16, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                                    Text(choice.blurb).font(.archivo(13)).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
                                    if choice.id != "blank" { Text(choice.meta).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).padding(.top, 5) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text("›").font(.spaceMono(16, weight: .bold)).foregroundStyle(Color.inkGhost)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
                            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                        }
                        .buttonStyle(OreRowPressStyle())
                        .accessibilityIdentifier(AX.programs.template(choice.id))
                    }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func tile(_ c: ProgramTemplates.Choice) -> some View {
        let blank = c.id == "blank"
        return Text(c.tag).font(.spaceMono(14, weight: .bold)).foregroundStyle(blank ? Color.inkMuted : Color.inkPrimary)
            .frame(width: 48, height: 48)
            .background(blank ? Color.clear : Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay { if blank { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])) } }
    }
}
