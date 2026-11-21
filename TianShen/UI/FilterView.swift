import SwiftUI

/// 识别类别过滤（人 / 动物 / 车辆三组开关）
struct FilterView: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Catalog.filterGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.dim)
                                .tracking(1)

                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(group.classes, id: \.self) { cls in
                                    chip(for: cls)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.panelBG.ignoresSafeArea())
            .navigationTitle("识别类别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("全部开启") { settings.setAll(true) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("全部关闭") { settings.setAll(false) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.green)
                .padding(16)
                .background(.ultraThinMaterial)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func chip(for cls: String) -> some View {
        let on = settings.classFilter[cls] ?? true
        return Button {
            settings.classFilter[cls] = !on
        } label: {
            Text(Catalog.label(for: cls))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(on ? .black : Color.white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(on ? Theme.green : Color.white.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
    }
}
