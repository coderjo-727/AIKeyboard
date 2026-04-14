import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum Layout {
        static let tint = UIColor(red: 0.09, green: 0.39, blue: 0.30, alpha: 1.0)
        static let tintSoft = UIColor(red: 0.84, green: 0.92, blue: 0.88, alpha: 1.0)
        static let surface = UIColor(red: 0.97, green: 0.97, blue: 0.94, alpha: 1.0)
        static let panel = UIColor(red: 0.99, green: 0.99, blue: 0.97, alpha: 0.97)
        static let panelBorder = UIColor(red: 0.84, green: 0.87, blue: 0.82, alpha: 0.8)
        static let key = UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1.0)
        static let keyAccent = UIColor(red: 0.86, green: 0.90, blue: 0.86, alpha: 1.0)
        static let keyForeground = UIColor(red: 0.12, green: 0.15, blue: 0.13, alpha: 1.0)
        static let mutedForeground = UIColor(red: 0.38, green: 0.42, blue: 0.39, alpha: 1.0)
        static let shadow = UIColor(red: 0.08, green: 0.12, blue: 0.09, alpha: 0.08)
    }

    private let previewContainer = UIView()
    private let previewLabel = UILabel()
    private let previewCaptionLabel = UILabel()
    private let previewMetaLabel = UILabel()
    private let expandButton = UIButton(type: .system)
    private let quickApplyButton = UIButton(type: .system)

    private let expandedPanel = UIView()
    private let expandedHandle = UIView()
    private let expandedTitleLabel = UILabel()
    private let expandedBodyLabel = UILabel()
    private let diffStackView = UIStackView()
    private let dismissButton = UIButton(type: .system)
    private let rejectButton = UIButton(type: .system)
    private let applyButton = UIButton(type: .system)

    private let keyboardSurface = UIStackView()
    private let helperCard = UIView()
    private let helperEyebrowLabel = UILabel()
    private let helperLabel = UILabel()
    private let suggestionKeys = UIStackView()
    private let keyboardRowsStack = UIStackView()

    private var expandedHeightConstraint: NSLayoutConstraint?
    private var latestAnalysis: CorrectionAnalysis?
    private var latestViewState = KeyboardPreviewViewState.make(from: nil)
    private var latestRuntimeSource: CorrectionRuntimeResult.Source = .localOnly
    private var isExpanded = false
    private var keyboardState = KeyboardState()
    private let sessionMemory = KeyboardSessionMemory()
    private let layoutModel = KeyboardLayout.qwertyPrototype
    private var previewTask: Task<Void, Never>?
    private var previewRevision = 0
    private var proxyAdapter: KeyboardTextDocumentProxy {
        KeyboardTextDocumentProxyAdapter(proxy: textDocumentProxy)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
        configureKeyboardRows()
        refreshPreview()
        applyInitialVisualState()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshPreview()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        previewTask?.cancel()
        sessionMemory.reset()
    }

    private func configureViewHierarchy() {
        view.backgroundColor = Layout.surface

        configurePreviewBar()
        configureExpandedPanel()
        configureKeyboardSurface()

        let rootStack = UIStackView(arrangedSubviews: [
            previewContainer,
            expandedPanel,
            keyboardSurface,
        ])
        rootStack.axis = .vertical
        rootStack.spacing = 10
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            rootStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
    }

    private func configurePreviewBar() {
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = Layout.panel
        previewContainer.layer.cornerRadius = 20
        applyCardStyle(to: previewContainer, shadowOpacity: 0.12)

        previewCaptionLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        previewCaptionLabel.textColor = Layout.tint
        previewCaptionLabel.text = "Smart Preview"

        previewMetaLabel.font = .systemFont(ofSize: 12, weight: .medium)
        previewMetaLabel.textColor = Layout.mutedForeground
        previewMetaLabel.text = "Sentence-aware and tap-to-review"

        previewLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        previewLabel.numberOfLines = 2
        previewLabel.textColor = Layout.keyForeground

        expandButton.configuration = .tinted()
        expandButton.setTitle("Review", for: .normal)
        expandButton.tintColor = Layout.tint
        expandButton.configuration?.baseBackgroundColor = Layout.tintSoft
        expandButton.configuration?.cornerStyle = .capsule
        expandButton.addTarget(self, action: #selector(handleExpandTap), for: .touchUpInside)

        quickApplyButton.configuration = .filled()
        quickApplyButton.setTitle("Apply", for: .normal)
        quickApplyButton.configuration?.baseBackgroundColor = Layout.tint
        quickApplyButton.configuration?.cornerStyle = .capsule
        quickApplyButton.addTarget(self, action: #selector(handleApplyTap), for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [previewCaptionLabel, UIView(), expandButton, quickApplyButton])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        let stack = UIStackView(arrangedSubviews: [topRow, previewLabel, previewMetaLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            previewContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 84),
            stack.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -14),
        ])
    }

    private func configureExpandedPanel() {
        expandedPanel.translatesAutoresizingMaskIntoConstraints = false
        expandedPanel.backgroundColor = Layout.panel
        expandedPanel.layer.cornerRadius = 24
        expandedPanel.clipsToBounds = true
        applyCardStyle(to: expandedPanel, shadowOpacity: 0.14)

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
            expandedBodyLabel,
            diffStackView,
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
        ])

        expandedHeightConstraint = expandedPanel.heightAnchor.constraint(equalToConstant: 0)
        expandedHeightConstraint?.isActive = true
        expandedPanel.alpha = 0
    }

    private func configureKeyboardSurface() {
        keyboardSurface.axis = .vertical
        keyboardSurface.spacing = 12
        keyboardSurface.distribution = .fillEqually

        helperEyebrowLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        helperEyebrowLabel.textColor = Layout.tint
        helperEyebrowLabel.text = "LIGHTWEIGHT REVIEW"

        helperLabel.font = .systemFont(ofSize: 13, weight: .medium)
        helperLabel.textColor = Layout.mutedForeground
        helperLabel.numberOfLines = 2
        helperLabel.text = "Preview stays visible while typing. Open review only when you want the full change list."

        suggestionKeys.axis = .horizontal
        suggestionKeys.spacing = 8
        suggestionKeys.distribution = .fillEqually

        keyboardRowsStack.axis = .vertical
        keyboardRowsStack.spacing = 10
        keyboardRowsStack.distribution = .fillEqually

        helperCard.backgroundColor = Layout.panel
        helperCard.layer.cornerRadius = 18
        helperCard.translatesAutoresizingMaskIntoConstraints = false
        applyCardStyle(to: helperCard, shadowOpacity: 0.08)
        helperEyebrowLabel.translatesAutoresizingMaskIntoConstraints = false
        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        helperCard.addSubview(helperEyebrowLabel)
        helperCard.addSubview(helperLabel)

        NSLayoutConstraint.activate([
            helperEyebrowLabel.topAnchor.constraint(equalTo: helperCard.topAnchor, constant: 12),
            helperEyebrowLabel.leadingAnchor.constraint(equalTo: helperCard.leadingAnchor, constant: 14),
            helperEyebrowLabel.trailingAnchor.constraint(equalTo: helperCard.trailingAnchor, constant: -14),
            helperLabel.topAnchor.constraint(equalTo: helperEyebrowLabel.bottomAnchor, constant: 6),
            helperLabel.leadingAnchor.constraint(equalTo: helperCard.leadingAnchor, constant: 14),
            helperLabel.trailingAnchor.constraint(equalTo: helperCard.trailingAnchor, constant: -14),
            helperLabel.bottomAnchor.constraint(equalTo: helperCard.bottomAnchor, constant: -12),
        ])

        keyboardSurface.addArrangedSubview(helperCard)
        keyboardSurface.addArrangedSubview(suggestionKeys)
        keyboardSurface.addArrangedSubview(keyboardRowsStack)
    }

    private func configureKeyboardRows() {
        keyboardRowsStack.arrangedSubviews.forEach { view in
            keyboardRowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for row in layoutModel.resolvedRows(for: keyboardState) {
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 8
            stack.alignment = .fill
            stack.distribution = .fill

            for key in row {
                let button = makeKeyButton(for: key)
                stack.addArrangedSubview(button)
                let widthConstraint = button.widthAnchor.constraint(
                    equalTo: stack.heightAnchor,
                    multiplier: key.widthMultiplier
                )
                widthConstraint.priority = .defaultHigh
                widthConstraint.isActive = true
            }

            keyboardRowsStack.addArrangedSubview(stack)
        }

        animateKeyboardRows()
    }

    private func makeKeyButton(for key: KeyboardLayout.Key) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = .filled()
        button.configuration?.baseBackgroundColor = backgroundColor(for: key.role)
        button.configuration?.baseForegroundColor = foregroundColor(for: key.role)
        button.configuration?.cornerStyle = .large
        button.setTitle(displayTitle(for: key), for: .normal)
        button.titleLabel?.font = font(for: key.role)
        button.layer.shadowColor = Layout.shadow.cgColor
        button.layer.shadowOpacity = 0.16
        button.layer.shadowRadius = 8
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.masksToBounds = false
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
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

    private func refreshPreview() {
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
        previewLabel.attributedText = viewState.previewText
        previewLabel.text = viewState.previewFallback
        previewMetaLabel.text = previewMetaText(canApply: viewState.canApply)
        expandedBodyLabel.text = viewState.expandedBody
        quickApplyButton.isEnabled = viewState.canApply
        applyButton.isEnabled = viewState.canApply
        expandButton.isEnabled = viewState.canExpand
        expandButton.setTitle(isExpanded ? "Close" : "Review", for: .normal)
        helperEyebrowLabel.text = viewState.canExpand ? "READY TO REVIEW" : "LIGHTWEIGHT REVIEW"
        helperLabel.text = helperText(canExpand: viewState.canExpand)
        renderDiffSegments(viewState.diffSegments)
        renderSuggestionRow(with: viewState)
    }

    private func previewMetaText(canApply: Bool) -> String {
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

    private func helperText(canExpand: Bool) -> String {
        let base = canExpand
            ? "A conservative suggestion is ready. Review it inline or keep typing."
            : "Preview stays visible while typing. Open review only when you want the full change list."

        if !hasFullAccess {
            return base + " Full Access is still off, so this session stays fully local."
        }

        switch latestRuntimeSource {
        case .relay:
            return base + " Relay quality is active for this pass."
        case .localFallback:
            return base + " The network path fell back cleanly to the local engine."
        case .localOnly:
            return base
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
            row.backgroundColor = UIColor.white.withAlphaComponent(0.94)
            row.layer.cornerRadius = 16
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

    private func renderSuggestionRow(with viewState: KeyboardPreviewViewState) {
        suggestionKeys.arrangedSubviews.forEach { view in
            suggestionKeys.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for chip in viewState.chips {
            let button = UIButton(type: .system)
            button.configuration = .tinted()
            button.configuration?.cornerStyle = .capsule
            button.configuration?.baseForegroundColor = Layout.tint
            button.configuration?.baseBackgroundColor = Layout.tintSoft
            button.setTitle(chip.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            button.isUserInteractionEnabled = false
            suggestionKeys.addArrangedSubview(button)
        }
    }

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        isExpanded = expanded
        expandedHeightConstraint?.constant = expanded ? 252 : 0
        keyboardSurface.alpha = expanded ? 0.16 : 1.0
        helperCard.alpha = expanded ? 0.5 : 1.0
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
        keyboardState.handleTap(for: role)
        configureKeyboardRows()
        refreshPreview()
    }

    private func displayTitle(for key: KeyboardLayout.Key) -> String {
        switch key.role {
        case .keyboardSwitch:
            return "globe"
        default:
            return key.title
        }
    }

    private func backgroundColor(for role: KeyboardLayout.Key.Role) -> UIColor {
        switch role {
        case .space, .input:
            return Layout.key
        default:
            return Layout.keyAccent
        }
    }

    private func highlightedBackgroundColor(for role: KeyboardLayout.Key.Role) -> UIColor {
        switch role {
        case .space, .input:
            return UIColor(red: 0.92, green: 0.95, blue: 0.92, alpha: 1.0)
        default:
            return UIColor(red: 0.77, green: 0.84, blue: 0.79, alpha: 1.0)
        }
    }

    private func foregroundColor(for role: KeyboardLayout.Key.Role) -> UIColor {
        switch role {
        case .modeChange, .keyboardSwitch:
            return Layout.tint
        default:
            return Layout.keyForeground
        }
    }

    private func font(for role: KeyboardLayout.Key.Role) -> UIFont {
        switch role {
        case .space, .modeChange, .keyboardSwitch, .return, .shift:
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

    private func applyCardStyle(to view: UIView, shadowOpacity: Float) {
        view.layer.borderWidth = 1
        view.layer.borderColor = Layout.panelBorder.cgColor
        view.layer.shadowColor = Layout.shadow.cgColor
        view.layer.shadowOpacity = shadowOpacity
        view.layer.shadowRadius = 18
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.layer.masksToBounds = false
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
