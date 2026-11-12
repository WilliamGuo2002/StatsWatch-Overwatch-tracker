import CoreImage.CIFilterBuiltins
import SwiftUI

struct FriendLinkSheet: View {
    let playerId: String
    let avatar: String?
    @Environment(\.dismiss) private var dismiss

    private var link: URL? { FriendLink.url(for: playerId) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                AsyncImage(url: URL(string: avatar ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.15))
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())

                Text(verbatim: formatBattleTag(from: playerId))
                    .font(.system(size: 18, weight: .bold))

                if let link, let qr = Self.qrImage(for: link.absoluteString) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text("Scan with the iPhone Camera to add this player to Favorites in StatsWatch.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                if let link {
                    ShareLink(item: link) {
                        Label("Share Link", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 30)
                }
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Add Me as a Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private static func qrImage(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
