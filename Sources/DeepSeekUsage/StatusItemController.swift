import AppKit
import SwiftUI
import Combine

/// 弹窗宿主：每次出现时重新计算内容尺寸，避免顶部/底部裁剪
private final class PopoverHostViewController: NSViewController {
    var onViewDidAppear: (() -> Void)?
    override func viewDidAppear() {
        super.viewDidAppear()
        onViewDidAppear?()
    }
}

/// 菜单栏状态项 + 点击弹出的悬浮窗（NSPopover）
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private weak var model: AppModel?
    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.toolTip = "DeepSeekUsage"
        }

        let hosting = NSHostingView(rootView: PopoverView(model: model))
        let width: CGFloat = 340
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 620)
        let contentVC = PopoverHostViewController()
        contentVC.view = hosting
        contentVC.onViewDidAppear = { [weak self] in
            Task { @MainActor [weak self] in self?.resizePopoverToFitContent() }
        }
        popover.contentViewController = contentVC
        popover.contentSize = NSSize(width: width, height: 620)
        popover.behavior = .transient // 点击外部自动关闭
        popover.animates = true

        // 状态变化时刷新菜单栏文字/图标，并自适应弹窗尺寸
        model.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.render()
                    self?.resizePopoverToFitContent()
                }
            }
            .store(in: &cancellables)

        // 时间维度小弹窗展开/收起会改变内容高度：延迟再对齐两次，避开布局时序差
        model.$isDimensionPickerOpen
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    self?.resizePopoverToFitContent()
                    try? await Task.sleep(nanoseconds: 160_000_000)
                    self?.resizePopoverToFitContent()
                }
            }
            .store(in: &cancellables)

        installOutsideClickWatcher()
        render()
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    /// 统一关闭弹窗：复位「时间维度」小弹窗状态，避免下次打开时残留展开
    private func closePopover() {
        model?.isDimensionPickerOpen = false
        popover.performClose(nil)
    }

    /// 根据内容重新计算弹窗尺寸（不超屏幕，超出部分由 ScrollView 滚动）
    /// 尺寸随内容变化：主界面 340；时间维度小弹窗展开时高度自适应
    private func resizePopoverToFitContent() {
        guard let hosting = popover.contentViewController?.view as? NSHostingView<PopoverView> else { return }
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        let maxHeight = max(screenHeight - 80, 300)
        let width = min(max(fitting.width, 340), 780)
        let target = min(max(fitting.height, 200), maxHeight)
        hosting.setFrameSize(NSSize(width: width, height: target))
        popover.contentSize = NSSize(width: width, height: target)
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        model?.isDimensionPickerOpen = false   // 每次打开：小弹窗默认收起，不复用上次状态
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate() // 让输入框可编辑
    }

    // MARK: - 点击弹窗外部自动关闭（核心交互）

    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var isClosingPopover = false

    /// 安装全局/本地鼠标监听：点击落在悬浮窗之外（且不在菜单栏图标上）时主动关闭。
    /// 说明：NSPopover.behavior = .transient 在 macOS 27 实测不生效，这里主动补齐该交互。
    private func installOutsideClickWatcher() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            DispatchQueue.main.async { self?.closePopoverIfClickOutside() }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.closePopoverIfClickOutside()
            return event
        }
        // 失活兜底：切到其他 App（⌘Tab 等）时收回悬浮窗
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.closePopover()
        }
    }

    /// 点击若落在 Popover 之外，主动关闭（状态栏图标上的点击除外，交给 toggle）
    private func closePopoverIfClickOutside() {
        guard popover.isShown, !isClosingPopover else { return }
        guard let pw = popover.contentViewController?.view.window, pw.isVisible else { return }
        let point = NSEvent.mouseLocation   // 屏幕坐标（左下原点），与 window.frame 同一坐标系
        if NSPointInRect(point, pw.frame) { return }
        if Self.pointIsOnStatusItem(point) { return }
        isClosingPopover = true
        closePopover()
        DispatchQueue.main.async { [weak self] in self?.isClosingPopover = false }
    }

    /// 点击点是否落在菜单栏状态项窗口上（其类名含 StatusBar）
    private static func pointIsOnStatusItem(_ point: NSPoint) -> Bool {
        for window in NSApp.windows where window.isVisible {
            let cls = NSStringFromClass(type(of: window))
            if cls.contains("StatusBar") && NSPointInRect(point, window.frame) {
                return true
            }
        }
        return false
    }

    // MARK: - 菜单栏渲染

    func render() {
        guard let button = statusItem.button else { return }
        let model = self.model
        button.attributedTitle = Self.attributedTitle(for: model)
        button.image = Self.icon(for: model)
        button.toolTip = Self.tooltip(for: model)
    }

    private static func attributedTitle(for model: AppModel?) -> NSAttributedString {
        let text: String
        if let balance = model?.lastBalance {
            text = "\(currencySymbol(balance.currency))\(format(balance.total))"
        } else {
            text = "—"
        }
        return NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: titleColor(for: model),
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            ]
        )
    }

    private static func titleColor(for model: AppModel?) -> NSColor {
        guard let model else { return .labelColor }
        switch model.status {
        case .fresh:
            if let balance = model.lastBalance {
                if balance.total < 1 { return .systemRed }
                if balance.total < 10 { return .systemOrange }
            }
            return .labelColor
        case .stale:
            return .systemOrange
        case .error, .tokenExpired:
            return .systemRed
        default:
            return .labelColor
        }
    }

    private static func icon(for model: AppModel?) -> NSImage? {
        // 鲸鱼娘托盘图标（与 Windows 版一致）；未随包分发时回退 SF Symbol
        if let path = Bundle.main.path(forResource: "whale-girl-tray", ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        let name = model?.isFetching == true ? "arrow.triangle.2.circlepath" : "sparkles"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "DeepSeekUsage")
        image?.isTemplate = true
        return image
    }

    private static func tooltip(for model: AppModel?) -> String {
        guard let model else { return "DeepSeekUsage" }
        switch model.status {
        case .tokenExpired:
            return "登录已过期，点击重新登录"
        case .error:
            return model.lastError ?? "获取失败"
        case .stale:
            var stale = model.lastError ?? "数据可能已过期"
            if let lastUpdate = model.lastUpdate {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                stale += " · 最后成功 \(formatter.string(from: lastUpdate))"
            }
            return stale
        default:
            break
        }
        guard let lastUpdate = model.lastUpdate else {
            return model.lastError ?? "DeepSeekUsage"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "DeepSeekUsage · 最后更新 \(formatter.string(from: lastUpdate))"
    }
}
