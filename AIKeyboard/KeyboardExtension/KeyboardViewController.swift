import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum Layout {
        static let tint = UIColor(red: 0.78, green: 0.86, blue: 0.82, alpha: 1.0)
        static let tintSoft = UIColor(red: 0.21, green: 0.29, blue: 0.25, alpha: 1.0)
        static let surface = UIColor(red: 0.06, green: 0.07, blue: 0.07, alpha: 1.0)
        static let panel = UIColor(red: 0.12, green: 0.13, blue: 0.13, alpha: 0.98)
        static let panelBorder = UIColor(red: 0.24, green: 0.26, blue: 0.25, alpha: 1.0)
        static let key = UIColor(red: 0.23, green: 0.24, blue: 0.24, alpha: 1.0)
        static let keyAccent = UIColor(red: 0.17, green: 0.18, blue: 0.18, alpha: 1.0)
        static let keyForeground = UIColor(red: 0.94, green: 0.95, blue: 0.94, alpha: 1.0)
        static let mutedForeground = UIColor(red: 0.66, green: 0.69, blue: 0.67, alpha: 1.0)
        static let shadow = UIColor.black.withAlphaComponent(0.16)

        struct Metrics {
            let preferredCollapsedHeight: CGFloat
            let preferredExpandedHeight: CGFloat
            let expandedPanelHeight: CGFloat
            let keyHeight: CGFloat
            let rootSpacing: CGFloat
            let keyboardSurfaceSpacing: CGFloat
            let keySpacing: CGFloat
            let rowSpacing: CGFloat
            let previewHeight: CGFloat
        }
    }

    private let rootStack = UIStackView()
    private let previewContainer = UIView()
    private let previewScrollView = UIScrollView()
    private let previewLabel = UILabel()
    private let previewCaptionLabel = UILabel()
    private let previewMetaLabel = UILabel()
    private let expandButton = UIButton(type: .system)
    private let quickApplyButton = UIButton(type: .system)

    private let expandedPanel = UIView()
    private let expandedHandle = UIView()
    private let expandedTitleLabel = UILabel()
    private let expandedBodyLabel = UILabel()
    private let expandedScrollView = UIScrollView()
    private let expandedScrollableStack = UIStackView()
    private let diffStackView = UIStackView()
    private let dismissButton = UIButton(type: .system)
    private let rejectButton = UIButton(type: .system)
    private let applyButton = UIButton(type: .system)

    private let keyboardSurface = UIStackView()
    private let keyboardRowsStack = UIStackView()

    private var preferredHeightConstraint: NSLayoutConstraint?
    private var expandedHeightConstraint: NSLayoutConstraint?
    private var keyHeightConstraints: [NSLayoutConstraint] = []
    private var previewHeightConstraint: NSLayoutConstraint?
    private var latestAnalysis: CorrectionAnalysis?
    private var latestViewState = KeyboardPreviewViewState.make(from: nil)
    private var latestRuntimeSource: CorrectionRuntimeResult.Source = .localOnly
    private var isExpanded = false
    private var keyboardState = KeyboardState()
    private let sessionMemory = KeyboardSessionMemory()
    private let layoutModel = KeyboardLayout.qwertyPrototype
    private var refreshWorkItem: DispatchWorkItem?
    private var previewTask: Task<Void, Never>?
    private var previewRevision = 0
    private var proxyAdapter: KeyboardTextDocumentProxy {
        KeyboardTextDocumentProxyAdapter(proxy: textDocumentProxy)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
        configureKeyboardRows(animated: false)
        updateAdaptiveLayout(animated: false)
        refreshPreview()
        applyInitialVisualState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAdaptiveLayout(animated: false)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        schedulePreviewRefresh(after: 0.06)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        refreshWorkItem?.cancel()
        previewTask?.cancel()
        sessionMemory.reset()
    }

    private func configureViewHierarchy() {
        view.backgroundColor = Layout.surface
        let metrics = currentMetrics

        configurePreviewBar()
        configureExpandedPanel()
        configureKeyboardSurface()

        rootStack.addArrangedSubview(previewContainer)
        rootStack.addArrangedSubview(expandedPanel)
        rootStack.addArrangedSubview(keyboardSurface)
        rootStack.axis = .vertical
        rootStack.spacing = metrics.rootSpacing
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        preferredHeightConstraint = view.heightAnchor.constraint(equalToConstant: metrics.preferredCollapsedHeight)
        preferredHeightConstraint?.priority = .defaultHigh
        preferredHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            rootStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
    }

    private var currentMetrics: Layout.Metrics {
        let width = max(view.bounds.width, UIScreen.main.bounds.width)
        if width < 380 {
            return Layout.Metrics(
                preferredCollapsedHeight: 308,
                preferredExpandedHeight: 530,
                expandedPanelHeight: 212,
                keyHeight: 43,
                rootSpacing: 7,
                keyboardSurfaceSpacing: 0,
                keySpacing: 4,
                rowSpacing: 7,
                previewHeight: 70
            )
        }

        if width >= 430 {
            return Layout.Metrics(
                preferredCollapsedHeight: 342,
                preferredExpandedHeight: 610,
                expandedPanelHeight: 256,
                keyHeight: 50,
                rootSpacing: 9,
                keyboardSurfaceSpacing: 0,
                keySpacing: 6,
                rowSpacing: 9,
                previewHeight: 76
            )
        }

        return Layout.Metrics(
            preferredCollapsedHeight: 326,
            preferredExpandedHeight: 580,
            expandedPanelHeight: 236,
            keyHeight: 48,
            rootSpacing: 8,
            keyboardSurfaceSpacing: 0,
            keySpacing: 6,
            rowSpacing: 8,
            previewHeight: 74
        )
    }

    private func updateAdaptiveLayout(animated: Bool) {
        let metrics = currentMetrics
        preferredHeightConstraint?.constant = isExpanded
            ? metrics.preferredExpandedHeight
            : metrics.preferredCollapsedHeight
        expandedHeightConstraint?.constant = isExpanded ? metrics.expandedPanelHeight : 0
        previewHeightConstraint?.constant = metrics.previewHeight
        rootStack.spacing = metrics.rootSpacing
        keyboardSurface.spacing = metrics.keyboardSurfaceSpacing
        keyboardRowsStack.spacing = metrics.rowSpacing

        for row in keyboardRowsStack.arrangedSubviews.compactMap({ $0 as? UIStackView }) {
            row.spacing = metrics.keySpacing
        }

        for constraint in keyHeightConstraints {
            constraint.constant = metrics.keyHeight
        }

        if animated {
            let changes = { self.view.layoutIfNeeded() }
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: changes)
        }
    }

    private func configurePreviewBar() {
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = Layout.panel
        previewContainer.layer.cornerRadius = 16
        previewContainer.layer.borderWidth = 1
        previewContainer.layer.borderColor = Layout.panelBorder.cgColor
        previewContainer.clipsToBounds = true

        previewCaptionLabel.font = .systemFont(ofSize: 10, weight: .bold)
        previewCaptionLabel.textColor = Layout.tint
        previewCaptionLabel.text = "Smart Preview"

        previewMetaLabel.font = .systemFont(ofSize: 10, weight: .medium)
        previewMetaLabel.textColor = Layout.mutedForeground
        previewMetaLabel.numberOfLines = 1

        previewLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        previewLabel.numberOfLines = 1
        previewLabel.textColor = Layout.keyForeground
        previewLabel.lineBreakMode = .byTruncatingTail

        previewScrollView.showsHorizontalScrollIndicator = false
        previewScrollView.alwaysBounceHorizontal = true
        previewScrollView.delaysContentTouches = false
        previewScrollView.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewScrollView.addSubview(previewLabel)

        expandButton.configuration = .tinted()
        expandButton.setTitle("Review", for: .normal)
        expandButton.tintColor = Layout.tint
        expandButton.configuration?.baseBackgroundColor = Layout.tintSoft
        expandButton.configuration?.cornerStyle = .capsule
        expandButton.addTarget(self, action: #selector(handleExpandTap), for: .touchUpInside)

        quickApplyButton.configuration = .filled()
        quickApplyButton.setTitle("Apply", for: .normal)
        quickApplyButton.configuration?.baseBackgroundColor = UIColor(red: 0.78, green: 0.68, blue: 0.18, alpha: 1.0)
        quickApplyButton.configuration?.baseForegroundColor = UIColor.black
        quickApplyButton.configuration?.cornerStyle = .capsule
        quickApplyButton.addTarget(self, action: #selector(handleApplyTap), for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [previewCaptionLabel, previewMetaLabel, UIView(), expandButton, quickApplyButton])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 8

        let stack = UIStackView(arrangedSubviews: [topRow, previewScrollView])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(stack)

        previewHeightConstraint = previewContainer.heightAnchor.constraint(equalToConstant: currentMetrics.previewHeight)
        previewHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -10),
            previewLabel.topAnchor.constraint(equalTo: previewScrollView.contentLayoutGuide.topAnchor),
            previewLabel.leadingAnchor.constraint(equalTo: previewScrollView.contentLayoutGuide.leadingAnchor),
            previewLabel.trailingAnchor.constraint(equalTo: previewScrollView.contentLayoutGuide.trailingAnchor),
            previewLabel.bottomAnchor.constraint(equalTo: previewScrollView.contentLayoutGuide.bottomAnchor),
            previewLabel.heightAnchor.constraint(equalTo: previewScrollView.frameLayoutGuide.heightAnchor),
            previewLabel.widthAnchor.constraint(greaterThanOrEqualTo: previewScrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    private func configureExpandedPanel() {
        expandedPanel.translatesAutoresizingMaskIntoConstraints = false
        expandedPanel.backgroundColor = Layout.panel
        expandedPanel.layer.cornerRadius = 18
        expandedPanel.clipsToBounds = true
        expandedPanel.layer.borderWidth = 1
        expandedPanel.layer.borderColor = Layout.panelBorder.cgColor

        expandedHandle.translatesAutoresizingMaskIntoConstraints = false
        expandedHandle.backgroundColor = Layout.panelBorder
        expandedHandle.layer.cornerRadius = 2

        expandedTitleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        expandedTitleLabel.text = "Full Review"
        expandedTitleLabel.textColor = Layout.keyForeground

        expandedBodyLabel.numberOfLines = 0
        expandedBodyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        expandedBodyLabel.textColor = Layout.mutedForeground

        diffStackView.axis = .vertical
        diffStackView.spacing = 10

        expandedScrollView.showsVerticalScrollIndicator = true
        expandedScrollView.alwaysBounceVertical = false
        expandedScrollView.delaysContentTouches = false

        expandedScrollableStack.axis = .vertical
        expandedScrollableStack.spacing = 12
        expandedScrollableStack.translatesAutoresizingMaskIntoConstraints = false
        expandedScrollableStack.addArrangedSubview(expandedBodyLabel)
        expandedScrollableStack.addArrangedSubview(diffStackView)
        expandedScrollView.addSubview(expandedScrollableStack)

        dismissButton.configuration = .plain()
        dismissButton.setTitle("Not Now", for: .normal)
        dismissButton.tintColor = Layout.mutedForeground
        dismissButton.addTarget(self, action: #selector(handleDismissTap), for: .touchUpInside)

        rejectButton.configuration = .bordered()
        rejectButton.setTitle("Hide This Session", for: .normal)
        rejectButton.configuration?.baseForegroundColor = Layout.tint
        rejectButton.configuration?.baseBackgroundColor = Layout.tintSoft
        rejectButton.configuration?.cornerStyle = .capsule
        rejectButton.addTarget(self, action: #selector(handleRejectTap), for: .touchUpInside)

        applyButton.configuration = .filled()
        applyButton.setTitle("Apply All", for: .normal)
        applyButton.configuration?.baseBackgroundColor = Layout.tint
        applyButton.configuration?.cornerStyle = .capsule
        applyButton.addTarget(self, action: #selector(handleApplyTap), for: .touchUpInside)

        let actionRow = UIStackView(arrangedSubviews: [dismissButton, rejectButton, UIView(), applyButton])
        actionRow.axis = .horizontal
        actionRow.alignment = .center
        actionRow.spacing = 8

        let contentStack = UIStackView(arrangedSubviews: [
            expandedHandle,
            expandedTitleLabel,
            expandedScrollView,
            actionRow,
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        expandedPanel.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: expandedPanel.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: expandedPanel.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: expandedPanel.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: expandedPanel.bottomAnchor, constant: -16),
            expandedHandle.widthAnchor.constraint(equalToConstant: 42),
            expandedHandle.heightAnchor.constraint(equalToConstant: 4),
            expandedScrollableStack.topAnchor.constraint(equalTo: expandedScrollView.contentLayoutGuide.topAnchor),
            expandedScrollableStack.leadingAnchor.constraint(equalTo: expandedScrollView.contentLayoutGuide.leadingAnchor),
            expandedScrollableStack.trailingAnchor.constraint(equalTo: expandedScrollView.contentLayoutGuide.trailingAnchor),
            expandedScrollableStack.bottomAnchor.constraint(equalTo: expandedScrollView.contentLayoutGuide.bottomAnchor),
            expandedScrollableStack.widthAnchor.constraint(equalTo: expandedScrollView.frameLayoutGuide.widthAnchor),
        ])

        expandedHeightConstraint = expandedPanel.heightAnchor.constraint(equalToConstant: 0)
        expandedHeightConstraint?.isActive = true
        expandedPanel.alpha = 0
    }

    private func configureKeyboardSurface() {
        keyboardSurface.axis = .vertical
        keyboardSurface.spacing = currentMetrics.keyboardSurfaceSpacing
        keyboardSurface.distribution = .fill

        keyboardRowsStack.axis = .vertical
        keyboardRowsStack.spacing = currentMetrics.rowSpacing
        keyboardRowsStack.distribution = .fill

        keyboardSurface.addArrangedSubview(keyboardRowsStack)
    }

    private func configureKeyboardRows(animated: Bool) {
        keyHeightConstraints.removeAll()
        keyboardRowsStack.arrangedSubviews.forEach { view in
            keyboardRowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for row in layoutModel.resolvedRows(for: keyboardState) {
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = currentMetrics.keySpacing
            stack.alignment = .fill
            stack.distribution = .fill
            var rowButtons: [(button: UIButton, key: KeyboardLayout.Key)] = []

            for key in row {
                let button = makeKeyButton(for: key)
                stack.addArrangedSubview(button)
                rowButtons.append((button, key))
            }

            if let baseButton = rowButtons.first?.button,
               let baseMultiplier = rowButtons.first?.key.widthMultiplier,
               baseMultiplier > 0 {
                for item in rowButtons.dropFirst() {
                    let widthConstraint = item.button.widthAnchor.constraint(
                        equalTo: baseButton.widthAnchor,
                        multiplier: item.key.widthMultiplier / baseMultiplier
                    )
                    widthConstraint.priority = .required
                    widthConstraint.isActive = true
                }
            }

            keyboardRowsStack.addArrangedSubview(stack)
        }

        if animated {
            animateKeyboardRows()
        }
    }

    private func makeKeyButton(for key: KeyboardLayout.Key) -> UIButton {
        let button = KeyboardKeyButton(type: .system)
        button.configuration = .filled()
        button.configuration?.baseBackgroundColor = backgroundColor(for: key.role)
        button.configuration?.baseForegroundColor = foregroundColor(for: key.role)
        button.configuration?.cornerStyle = .medium
        button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        if let symbol = symbolName(for: key) {
            let configuration = UIImage.SymbolConfiguration(pointSize: symbolPointSize(for: key.role), weight: .semibold)
            button.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
            button.setTitle(nil, for: .normal)
            button.configuration?.imagePadding = 0
        } else {
            button.setImage(nil, for: .normal)
            button.setTitle(displayTitle(for: key), for: .normal)
        }
        button.titleLabel?.font = font(for: key.role)
        button.layer.shadowColor = Layout.shadow.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 2
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.masksToBounds = false
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: currentMetrics.keyHeight)
        heightConstraint.isActive = true
        keyHeightConstraints.append(heightConstraint)
        button.configurationUpdateHandler = { [weak self] updatedButton in
            guard let self else { return }
            var background = self.backgroundColor(for: key.role)
            if !updatedButton.isEnabled {
                background = background.withAlphaComponent(0.45)
            } else if updatedButton.isHighlighted {
                background = self.highlightedBackgroundColor(for: key.role)
            }
            updatedButton.configuration?.baseBackgroundColor = background
            updatedButton.alpha = updatedButton.isEnabled ? 1.0 : 0.55
            updatedButton.transform = updatedButton.isHighlighted
                ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                : .identity
        }
        button.addTarget(self, action: #selector(handleKeyTap(_:)), for: .touchUpInside)
        button.accessibilityIdentifier = key.title
        button.tag = roleTag(for: key.role)
        return button
    }

    private func schedulePreviewRefresh(after delay: TimeInterval) {
        refreshWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshPreview()
        }
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func refreshPreview() {
        refreshWorkItem?.cancel()
        let context = KeyboardTextActionService.makeContext(for: proxyAdapter)
        let configuration = CorrectionRuntimeConfigurationLoader.load()
        let allowsRemote = hasFullAccess && configuration?.relay != nil
        previewTask?.cancel()
        previewRevision += 1
        let revision = previewRevision
        let localAnalysis = sessionMemory.filteredAnalysis(
            from: CorrectionPipeline.analyzeLocally(context: context)
        )
        latestRuntimeSource = .localOnly
        latestAnalysis = localAnalysis
        latestViewState = KeyboardPreviewViewState.make(from: localAnalysis)
        apply(viewState: latestViewState)

        guard allowsRemote else {
            return
        }

        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }

            let result = await CorrectionRuntime.analyze(
                context: context,
                configuration: configuration,
                prefersRemote: true
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self, revision == self.previewRevision else { return }
                let analysis = self.sessionMemory.filteredAnalysis(from: result.analysis)
                self.latestRuntimeSource = result.source
                self.latestAnalysis = analysis
                self.latestViewState = KeyboardPreviewViewState.make(from: analysis)
                self.apply(viewState: self.latestViewState)
            }
        }
    }

    private func apply(viewState: KeyboardPreviewViewState) {
        previewCaptionLabel.text = viewState.caption
        if let previewText = viewState.previewText {
            previewLabel.attributedText = previewText
        } else {
            previewLabel.attributedText = nil
            previewLabel.text = viewState.previewFallback
        }
        previewMetaLabel.text = previewMetaText(
            canApply: viewState.canApply,
            applyBlockedReason: viewState.applyBlockedReason
        )
        expandedBodyLabel.text = viewState.expandedBody
        quickApplyButton.isEnabled = viewState.canApply
        applyButton.isEnabled = viewState.canApply
        expandButton.isEnabled = viewState.canExpand
        expandButton.setTitle(isExpanded ? "Close" : "Review", for: .normal)
        renderDiffSegments(viewState.diffSegments)
    }

    private func previewMetaText(canApply: Bool, applyBlockedReason: String?) -> String {
        if let reason = applyBlockedReason {
            return reason
        }

        let prefix = canApply
            ? "Safe to apply from this cursor position."
            : "Review available. Apply unlocks at a safe overlap point."

        switch latestRuntimeSource {
        case .relay:
            return prefix + " Relay-backed correction is active."
        case .localFallback:
            return prefix + " Using the on-device fallback right now."
        case .localOnly:
            return prefix + (hasFullAccess
                ? " Local correction path is active."
                : " Enable Full Access to allow relay-backed corrections.")
        }
    }

    private func renderDiffSegments(_ segments: [DiffSegment]) {
        diffStackView.arrangedSubviews.forEach { view in
            diffStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if segments.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.font = .systemFont(ofSize: 12, weight: .medium)
            emptyLabel.textColor = Layout.mutedForeground
            emptyLabel.numberOfLines = 0
            emptyLabel.text = "No visible diff yet."
            diffStackView.addArrangedSubview(emptyLabel)
            return
        }

        for segment in segments {
            let row = UIView()
            row.backgroundColor = Layout.key
            row.layer.cornerRadius = 12
            row.layer.borderWidth = 1
            row.layer.borderColor = Layout.panelBorder.cgColor

            let kindLabel = UILabel()
            kindLabel.font = .systemFont(ofSize: 11, weight: .bold)
            kindLabel.textColor = Layout.tint
            kindLabel.text = segment.kind.rawValue.capitalized

            let bodyLabel = UILabel()
            bodyLabel.font = .systemFont(ofSize: 13, weight: .medium)
            bodyLabel.textColor = Layout.keyForeground
            bodyLabel.numberOfLines = 0
            bodyLabel.text = "\(display(segment.original)) → \(display(segment.replacement))"

            let stack = UIStackView(arrangedSubviews: [kindLabel, bodyLabel])
            stack.axis = .vertical
            stack.spacing = 3
            stack.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
                stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
                stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
                stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -8),
            ])

            diffStackView.addArrangedSubview(row)
        }
    }

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        isExpanded = expanded
        updateAdaptiveLayout(animated: false)
        keyboardSurface.alpha = expanded ? 0.16 : 1.0
        keyboardSurface.isUserInteractionEnabled = !expanded
        previewContainer.transform = expanded
            ? CGAffineTransform(scaleX: 0.985, y: 0.985).translatedBy(x: 0, y: -2)
            : .identity
        expandedPanel.transform = expanded
            ? .identity
            : CGAffineTransform(translationX: 0, y: -10).scaledBy(x: 0.98, y: 0.98)
        let changes = {
            self.expandedPanel.alpha = expanded ? 1 : 0
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                usingSpringWithDamping: 0.88,
                initialSpringVelocity: 0.3,
                options: [.curveEaseInOut],
                animations: changes
            )
        } else {
            changes()
        }
    }

    @objc
    private func handleExpandTap() {
        guard latestAnalysis?.suggestion != nil else { return }
        setExpanded(!isExpanded, animated: true)
    }

    @objc
    private func handleDismissTap() {
        sessionMemory.recordDismissal(for: latestAnalysis)
        setExpanded(false, animated: true)
        refreshPreview()
    }

    @objc
    private func handleRejectTap() {
        sessionMemory.recordRejection(for: latestAnalysis)
        setExpanded(false, animated: true)
        refreshPreview()
    }

    @objc
    private func handleApplyTap() {
        guard KeyboardTextActionService.applySuggestion(latestAnalysis, to: proxyAdapter) else {
            expandedBodyLabel.text = "Move the cursor to a safe overlap point where the remaining text after the cursor already matches the suggested ending."
            setExpanded(true, animated: true)
            return
        }

        sessionMemory.recordAcceptance(for: latestAnalysis)
        setExpanded(false, animated: true)
        refreshPreview()
    }

    @objc
    private func handleKeyTap(_ sender: UIButton) {
        guard let role = role(for: sender) else { return }
        if role == .keyboardSwitch {
            advanceToNextInputMode()
            return
        }

        KeyboardTextActionService.handleKeyTap(role: role, state: keyboardState, using: proxyAdapter)
        let previousState = keyboardState
        keyboardState.handleTap(for: role)
        if keyboardState != previousState {
            configureKeyboardRows(animated: false)
        }
        schedulePreviewRefresh(after: 0.06)
    }

    private func displayTitle(for key: KeyboardLayout.Key) -> String {
        switch key.role {
        case .keyboardSwitch:
            return ""
        case .return:
            return "↵"
        case .shift:
            return ""
        default:
            return key.title
        }
    }

    private func symbolName(for key: KeyboardLayout.Key) -> String? {
        switch key.role {
        case .shift:
            if key.title == "caps.on" {
                return "capslock.fill"
            }
            return key.title == "shift.off" ? "shift" : "shift.fill"
        case .keyboardSwitch:
            return "globe"
        default:
            return nil
        }
    }

    private func symbolPointSize(for role: KeyboardLayout.Key.Role) -> CGFloat {
        switch role {
        case .shift, .return:
            return 18
        case .keyboardSwitch:
            return 17
        default:
            return 16
        }
    }

    private func backgroundColor(for role: KeyboardLayout.Key.Role) -> UIColor {
        switch role {
        case .input:
            return Layout.key
        case .space:
            return UIColor(red: 0.27, green: 0.28, blue: 0.28, alpha: 1.0)
        default:
            return Layout.keyAccent
        }
    }

    private func highlightedBackgroundColor(for role: KeyboardLayout.Key.Role) -> UIColor {
        switch role {
        case .space, .input:
            return UIColor(red: 0.34, green: 0.35, blue: 0.35, alpha: 1.0)
        default:
            return UIColor(red: 0.25, green: 0.26, blue: 0.26, alpha: 1.0)
        }
    }

    private func foregroundColor(for role: KeyboardLayout.Key.Role) -> UIColor {
        switch role {
        case .modeChange, .keyboardSwitch:
            return Layout.keyForeground
        default:
            return Layout.keyForeground
        }
    }

    private func font(for role: KeyboardLayout.Key.Role) -> UIFont {
        switch role {
        case .return:
            return .systemFont(ofSize: 20, weight: .semibold)
        case .space, .modeChange, .keyboardSwitch, .shift:
            return .systemFont(ofSize: 12, weight: .semibold)
        default:
            return .systemFont(ofSize: 20, weight: .medium)
        }
    }

    private func roleTag(for role: KeyboardLayout.Key.Role) -> Int {
        switch role {
        case .input(let value):
            switch value {
            case ".":
                return 1
            default:
                return 2
            }
        case .backspace:
            return 3
        case .shift:
            return 4
        case .modeChange:
            return 5
        case .keyboardSwitch:
            return 6
        case .space:
            return 7
        case .return:
            return 8
        }
    }

    private func role(for button: UIButton) -> KeyboardLayout.Key.Role? {
        let title = button.accessibilityIdentifier ?? button.currentTitle ?? ""

        switch button.tag {
        case 1:
            return .input(".")
        case 2:
            return .input(title)
        case 3:
            return .backspace
        case 4:
            return .shift
        case 5:
            return .modeChange(title)
        case 6:
            return .keyboardSwitch
        case 7:
            return .space
        case 8:
            return .return
        default:
            return nil
        }
    }

    private func display(_ value: String) -> String {
        value.isEmpty ? "∅" : value
    }

    private func applyInitialVisualState() {
        expandedPanel.transform = CGAffineTransform(translationX: 0, y: -10).scaledBy(x: 0.98, y: 0.98)
    }

    private func animateKeyboardRows() {
        for (index, row) in keyboardRowsStack.arrangedSubviews.enumerated() {
            row.alpha = 0
            row.transform = CGAffineTransform(translationX: 0, y: 6)
            UIView.animate(
                withDuration: 0.24,
                delay: Double(index) * 0.03,
                options: [.curveEaseOut, .beginFromCurrentState],
                animations: {
                    row.alpha = 1
                    row.transform = .identity
                }
            )
        }
    }
}

private final class KeyboardKeyButton: UIButton {
    private let minimumHitSide: CGFloat = 46

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let horizontalInset = min(0, (bounds.width - minimumHitSide) / 2)
        let verticalInset = min(0, (bounds.height - minimumHitSide) / 2)
        let hitFrame = bounds.insetBy(dx: horizontalInset, dy: verticalInset)
        return hitFrame.contains(point)
    }
}
