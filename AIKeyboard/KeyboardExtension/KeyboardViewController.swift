import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum Layout {
        static let tint = UIColor(red: 0.13, green: 0.44, blue: 0.30, alpha: 1.0)
        static let surface = UIColor(red: 0.94, green: 0.96, blue: 0.95, alpha: 1.0)
        static let panel = UIColor.white.withAlphaComponent(0.92)
    }

    private let previewContainer = UIView()
    private let previewLabel = UILabel()
    private let previewCaptionLabel = UILabel()
    private let expandButton = UIButton(type: .system)
    private let quickApplyButton = UIButton(type: .system)

    private let expandedPanel = UIView()
    private let expandedTitleLabel = UILabel()
    private let expandedBodyLabel = UILabel()
    private let diffStackView = UIStackView()
    private let dismissButton = UIButton(type: .system)
    private let rejectButton = UIButton(type: .system)
    private let applyButton = UIButton(type: .system)

    private let keyboardSurface = UIStackView()
    private let helperLabel = UILabel()
    private let suggestionKeys = UIStackView()
    private let keyboardRowsStack = UIStackView()

    private var expandedHeightConstraint: NSLayoutConstraint?
    private var latestAnalysis: CorrectionAnalysis?
    private var latestViewState = KeyboardPreviewViewState.make(from: nil)
    private var isExpanded = false
    private var keyboardState = KeyboardState()
    private let sessionMemory = KeyboardSessionMemory()
    private let layoutModel = KeyboardLayout.qwertyPrototype
    private var proxyAdapter: KeyboardTextDocumentProxy {
        KeyboardTextDocumentProxyAdapter(proxy: textDocumentProxy)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
        configureKeyboardRows()
        refreshPreview()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshPreview()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
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
        previewContainer.layer.cornerRadius = 16

        previewCaptionLabel.font = .preferredFont(forTextStyle: .caption1)
        previewCaptionLabel.textColor = .secondaryLabel
        previewCaptionLabel.text = "Smart Preview"

        previewLabel.font = .preferredFont(forTextStyle: .subheadline)
        previewLabel.numberOfLines = 2
        previewLabel.textColor = .label

        expandButton.configuration = .plain()
        expandButton.setTitle("Review", for: .normal)
        expandButton.tintColor = Layout.tint
        expandButton.addTarget(self, action: #selector(handleExpandTap), for: .touchUpInside)

        quickApplyButton.configuration = .filled()
        quickApplyButton.setTitle("Apply", for: .normal)
        quickApplyButton.configuration?.baseBackgroundColor = Layout.tint
        quickApplyButton.addTarget(self, action: #selector(handleApplyTap), for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [previewCaptionLabel, UIView(), expandButton, quickApplyButton])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 8

        let stack = UIStackView(arrangedSubviews: [topRow, previewLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            previewContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            stack.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -10),
        ])
    }

    private func configureExpandedPanel() {
        expandedPanel.translatesAutoresizingMaskIntoConstraints = false
        expandedPanel.backgroundColor = Layout.panel
        expandedPanel.layer.cornerRadius = 20
        expandedPanel.clipsToBounds = true

        expandedTitleLabel.font = .preferredFont(forTextStyle: .headline)
        expandedTitleLabel.text = "Full Review"

        expandedBodyLabel.numberOfLines = 0
        expandedBodyLabel.font = .preferredFont(forTextStyle: .subheadline)
        expandedBodyLabel.textColor = .secondaryLabel

        diffStackView.axis = .vertical
        diffStackView.spacing = 8

        dismissButton.configuration = .plain()
        dismissButton.setTitle("Not Now", for: .normal)
        dismissButton.tintColor = .secondaryLabel
        dismissButton.addTarget(self, action: #selector(handleDismissTap), for: .touchUpInside)

        rejectButton.configuration = .bordered()
        rejectButton.setTitle("Hide This Session", for: .normal)
        rejectButton.configuration?.baseForegroundColor = Layout.tint
        rejectButton.addTarget(self, action: #selector(handleRejectTap), for: .touchUpInside)

        applyButton.configuration = .filled()
        applyButton.setTitle("Apply All", for: .normal)
        applyButton.configuration?.baseBackgroundColor = Layout.tint
        applyButton.addTarget(self, action: #selector(handleApplyTap), for: .touchUpInside)

        let actionRow = UIStackView(arrangedSubviews: [dismissButton, rejectButton, UIView(), applyButton])
        actionRow.axis = .horizontal
        actionRow.alignment = .center
        actionRow.spacing = 8

        let contentStack = UIStackView(arrangedSubviews: [
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
            contentStack.topAnchor.constraint(equalTo: expandedPanel.topAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: expandedPanel.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: expandedPanel.trailingAnchor, constant: -14),
            contentStack.bottomAnchor.constraint(equalTo: expandedPanel.bottomAnchor, constant: -14),
        ])

        expandedHeightConstraint = expandedPanel.heightAnchor.constraint(equalToConstant: 0)
        expandedHeightConstraint?.isActive = true
        expandedPanel.alpha = 0
    }

    private func configureKeyboardSurface() {
        keyboardSurface.axis = .vertical
        keyboardSurface.spacing = 10
        keyboardSurface.distribution = .fillEqually

        helperLabel.font = .preferredFont(forTextStyle: .caption1)
        helperLabel.textColor = .secondaryLabel
        helperLabel.numberOfLines = 2
        helperLabel.text = "Collapsed preview stays visible while typing. Review opens when you want the full change list."

        suggestionKeys.axis = .horizontal
        suggestionKeys.spacing = 8
        suggestionKeys.distribution = .fillEqually

        keyboardRowsStack.axis = .vertical
        keyboardRowsStack.spacing = 8
        keyboardRowsStack.distribution = .fillEqually

        let helperCard = UIView()
        helperCard.backgroundColor = UIColor.white.withAlphaComponent(0.55)
        helperCard.layer.cornerRadius = 14
        helperCard.translatesAutoresizingMaskIntoConstraints = false
        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        helperCard.addSubview(helperLabel)

        NSLayoutConstraint.activate([
            helperLabel.topAnchor.constraint(equalTo: helperCard.topAnchor, constant: 10),
            helperLabel.leadingAnchor.constraint(equalTo: helperCard.leadingAnchor, constant: 12),
            helperLabel.trailingAnchor.constraint(equalTo: helperCard.trailingAnchor, constant: -12),
            helperLabel.bottomAnchor.constraint(equalTo: helperCard.bottomAnchor, constant: -10),
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
    }

    private func makeKeyButton(for key: KeyboardLayout.Key) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = .filled()
        button.configuration?.baseBackgroundColor = backgroundColor(for: key.role)
        button.configuration?.baseForegroundColor = foregroundColor(for: key.role)
        button.configuration?.cornerStyle = .large
        button.setTitle(displayTitle(for: key), for: .normal)
        button.titleLabel?.font = font(for: key.role)
        button.heightAnchor.constraint(equalToConstant: 42).isActive = true
        button.addTarget(self, action: #selector(handleKeyTap(_:)), for: .touchUpInside)
        button.accessibilityIdentifier = key.title
        button.tag = roleTag(for: key.role)
        return button
    }

    private func refreshPreview() {
        let context = KeyboardTextActionService.makeContext(for: proxyAdapter)
        let analysis = sessionMemory.filteredAnalysis(
            from: SimpleCorrectionEngine.analyze(context: context)
        )
        latestAnalysis = analysis
        latestViewState = KeyboardPreviewViewState.make(from: analysis)
        apply(viewState: latestViewState)
    }

    private func apply(viewState: KeyboardPreviewViewState) {
        previewCaptionLabel.text = viewState.caption
        previewLabel.attributedText = viewState.previewText
        previewLabel.text = viewState.previewFallback
        expandedBodyLabel.text = viewState.expandedBody
        quickApplyButton.isEnabled = viewState.canApply
        applyButton.isEnabled = viewState.canApply
        expandButton.isEnabled = viewState.canExpand
        renderDiffSegments(viewState.diffSegments)
        renderSuggestionRow(with: viewState)
    }

    private func renderDiffSegments(_ segments: [DiffSegment]) {
        diffStackView.arrangedSubviews.forEach { view in
            diffStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if segments.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.font = .preferredFont(forTextStyle: .caption1)
            emptyLabel.textColor = .secondaryLabel
            emptyLabel.numberOfLines = 0
            emptyLabel.text = "No visible diff yet."
            diffStackView.addArrangedSubview(emptyLabel)
            return
        }

        for segment in segments {
            let row = UIView()
            row.backgroundColor = UIColor.white.withAlphaComponent(0.7)
            row.layer.cornerRadius = 12

            let kindLabel = UILabel()
            kindLabel.font = .preferredFont(forTextStyle: .caption1)
            kindLabel.textColor = Layout.tint
            kindLabel.text = segment.kind.rawValue.capitalized

            let bodyLabel = UILabel()
            bodyLabel.font = .preferredFont(forTextStyle: .caption1)
            bodyLabel.textColor = .label
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
            button.configuration = .bordered()
            button.configuration?.cornerStyle = .capsule
            button.configuration?.baseForegroundColor = Layout.tint
            button.setTitle(chip.title, for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
            button.isUserInteractionEnabled = false
            suggestionKeys.addArrangedSubview(button)
        }
    }

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        isExpanded = expanded
        expandedHeightConstraint?.constant = expanded ? 220 : 0
        keyboardSurface.alpha = expanded ? 0.2 : 1.0
        keyboardSurface.isUserInteractionEnabled = !expanded
        let changes = {
            self.expandedPanel.alpha = expanded ? 1 : 0
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut], animations: changes)
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
            return UIColor.white.withAlphaComponent(0.88)
        default:
            return UIColor(red: 0.84, green: 0.88, blue: 0.85, alpha: 1.0)
        }
    }

    private func foregroundColor(for role: KeyboardLayout.Key.Role) -> UIColor {
        switch role {
        case .modeChange, .keyboardSwitch:
            return Layout.tint
        default:
            return .label
        }
    }

    private func font(for role: KeyboardLayout.Key.Role) -> UIFont {
        switch role {
        case .space, .modeChange, .keyboardSwitch, .return, .shift:
            return .preferredFont(forTextStyle: .caption1)
        default:
            return .preferredFont(forTextStyle: .body)
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
}
