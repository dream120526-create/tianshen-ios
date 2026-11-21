import SwiftUI

/// 顶部状态胶囊（点开是控制面板）
struct HUDView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var pipeline: DetectionPipeline
    @ObservedObject var compass: Compass
    var targetCount: Int
    var onSwitchCamera: () -> Void
    var onSelectTier: (ModelTier) -> Void
    var onShowFilter: () -> Void
    var onShowDiag: () -> Void

    @State private var expanded = false

    private var statusColor: Color {
        if !pipeline.modelReady { return Theme.amber }
        return Theme.green
    }

    var body: some View {
        VStack(spacing: 10) {
            pill
            if expanded { panel }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }

    // MARK: - 胶囊

    private var pill: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { expanded.toggle() }
        } label: {
            HStack(spacing: 9) {
                Circle().fill(statusColor).frame(width: 7, height: 7)
                    .shadow(color: statusColor.opacity(0.8), radius: 4)

                Text(settings.tier.network)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))

                separator

                Text("\(targetCount) 目标")
                    .font(Theme.mono)
                    .foregroundStyle(Theme.green)

                separator

                Text("\(Int(pipeline.fps.rounded())) FPS")
                    .font(Theme.mono)
                    .foregroundStyle(Theme.cyan)

                separator

                Text("\(Int(compass.heading.rounded()))°")
                    .font(Theme.mono)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private var separator: some View {
        Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 11)
    }

    // MARK: - 展开面板

    private var panel: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("绘制")

            HStack(spacing: 8) {
                toggleChip("方框", isOn: $settings.drawBox)
                toggleChip("骨骼", isOn: $settings.drawSkeleton)
                toggleChip("雷达", isOn: $settings.drawRadar)
                toggleChip("射线", isOn: $settings.drawAntenna)
            }

            sectionTitle("绘制模式")

            HStack(spacing: 8) {
                ForEach(DrawMode.allCases) { mode in
                    Button {
                        settings.drawMode = mode
                    } label: {
                        Text(mode.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(settings.drawMode == mode ? Color.black : Color.white.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(settings.drawMode == mode ? Theme.green : Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            sectionTitle("探测灵敏度  \(Int(settings.threshold * 100))%")

            Slider(value: $settings.threshold, in: 0.05...0.75, step: 0.01)
                .tint(Theme.green)

            sectionTitle("识别模型（本地）")

            HStack(spacing: 8) {
                ForEach(ModelTier.allCases) { tier in
                    tierButton(tier)
                }
            }

            Text(pipeline.statusText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .lineLimit(2)

            Divider().overlay(Color.white.opacity(0.08))

            HStack(spacing: 8) {
                smallButton("类别过滤", icon: "line.3.horizontal.decrease.circle", action: onShowFilter)
                smallButton("切换镜头", icon: "arrow.triangle.2.circlepath.camera", action: onSwitchCamera)
                smallButton("诊断", icon: "waveform.path.ecg", action: onShowDiag)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.dim)
            .tracking(1)
    }

    private func toggleChip(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn.wrappedValue ? "checkmark" : "minus")
                    .font(.system(size: 8, weight: .bold))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isOn.wrappedValue ? Color.black : Color.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isOn.wrappedValue ? Theme.green : Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private func tierButton(_ tier: ModelTier) -> some View {
        let available = ModelStore.isAvailable(tier)
        let selected = settings.tier == tier
        return Button {
            onSelectTier(tier)
        } label: {
            VStack(spacing: 3) {
                Text(tier.title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(tier.network)
                    .font(.system(size: 9, design: .monospaced))
                    .opacity(0.7)
                if !available {
                    Text("未装")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.amber)
                }
            }
            .foregroundStyle(selected ? Color.black : Color.white.opacity(available ? 0.85 : 0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Theme.green : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(available ? Color.clear : Theme.amber.opacity(0.35), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func smallButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(Color.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}
