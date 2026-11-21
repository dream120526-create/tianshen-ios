import SwiftUI

/// 首次启动的使用须知（纯本地，无登录、无卡密）。
struct NoticeView: View {
    var onAccept: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.03, blue: 0.06),
                                    Color(red: 0.05, green: 0.05, blue: 0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("天神辅助")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(6)
                        .foregroundStyle(.white.opacity(0.92))
                    Text("使用须知")
                        .font(.system(size: 12))
                        .tracking(4)
                        .foregroundStyle(Theme.cyan)
                }
                .padding(.top, 34)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        paragraph("一、软件功能",
                                  "本软件是纯本地的摄像头视觉识别工具，对画面中的人、常见动物与车辆做实时识别标注。全部运算在你的设备上完成，不需要联网，也没有服务器。")
                        paragraph("二、相机权限",
                                  "需要相机权限才能取景识别。画面不会被拍照、录制、上传或保存，退出软件后摄像头立即关闭。")
                        paragraph("三、数据与隐私",
                                  "识别过程完全在本地运行，不采集、不上传、不存储任何个人信息与画面内容。模型文件只存在你的设备里。")
                        paragraph("四、结果说明",
                                  "识别结果受光线、距离、角度、遮挡影响，可能有误差或漏检，仅供参考，不能作为专业判断、安全决策或法律依据。")
                        paragraph("五、合规使用",
                                  "请在法律允许的范围内使用本软件，不得用于侵犯他人隐私或妨碍他人合法权益。因违规使用造成的后果由使用者自行承担。")
                        paragraph("六、免责声明",
                                  "本软件按现状提供，不对识别准确性、完整性及使用后果作任何担保。因使用或无法使用本软件导致的直接或间接损失，由使用者自行承担。")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
                }

                Button(action: onAccept) {
                    Text("我已知晓")
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [Color(red: 0.08, green: 0.40, blue: 0.75),
                                                    Color(red: 0.05, green: 0.28, blue: 0.63)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 0)
        }
    }

    private func paragraph(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Theme.cyan)
            Text(body)
                .font(.system(size: 12.5))
                .lineSpacing(4)
                .foregroundStyle(Color.white.opacity(0.62))
        }
    }
}
