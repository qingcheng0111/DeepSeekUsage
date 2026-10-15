import SwiftUI

/// 时间维度小弹窗（主面板内浮层，尺寸与位置对齐需求红框：宽 150 × 高约 178）
///
/// 交互：
/// - 点选项 → 立即应用该维度并收起小弹窗（主页面始终可见、尺寸不变）
/// - 再点「时间维度」按钮、或点主面板内其他区域 → 收起小弹窗
/// - 点面板外部 → 由 StatusItemController 的监听关闭整个面板（核心行为不变）
struct DimensionMenuView: View {
    @ObservedObject var model: AppModel
    @State private var hovered: TimeDimension?

    private static let rowHeight: CGFloat = 27

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(TimeDimension.presets, id: \.self) { d in
                row(d)
            }
        }
        .padding(5)
        .frame(width: 150, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
    }

    private func row(_ d: TimeDimension) -> some View {
        let selected = d == model.dimension
        return Button {
            model.applyDimension(d)
        } label: {
            ZStack {
                // 选项文字水平居中
                Text(d.pickerLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity)
                // 选中勾选：靠右显示
                if selected {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.trailing, 8)
                }
            }
            .frame(height: Self.rowHeight)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovered == d ? Color.secondary.opacity(0.14) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            if h { hovered = d }
            else if hovered == d { hovered = nil }
        }
    }
}
