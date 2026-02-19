import UIKit

@MainActor
protocol ColorSwatchCollectionViewDelegate: AnyObject {
    func colorSwatchCollectionView(_ collectionView: ColorSwatchCollectionView, didSelectColorHex hex: String?)
}

final class ColorSwatchCollectionView: UIView {

    weak var delegate: ColorSwatchCollectionViewDelegate?

    var selectedHex: String? {
        didSet {
            collectionView.reloadData()
        }
    }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 44, height: 44)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.dataSource = self
        cv.delegate = self
        cv.register(ColorSwatchCell.self, forCellWithReuseIdentifier: ColorSwatchCell.reuseIdentifier)
        cv.register(CustomColorCell.self, forCellWithReuseIdentifier: CustomColorCell.reuseIdentifier)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private var isCustomSelected: Bool {
        guard let selectedHex else { return false }
        return !ObjectColorCodec.palette.contains(selectedHex)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            collectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 112)
    }

    fileprivate func handleCustomColorSelected(_ color: UIColor) {
        if let hex = ObjectColorCodec.hex(from: color) {
            selectedHex = hex
            delegate?.colorSwatchCollectionView(self, didSelectColorHex: hex)
        }
    }
}

// MARK: - UICollectionViewDataSource

extension ColorSwatchCollectionView: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        ObjectColorCodec.palette.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < ObjectColorCodec.palette.count {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ColorSwatchCell.reuseIdentifier, for: indexPath) as! ColorSwatchCell
            let hex = ObjectColorCodec.palette[indexPath.item]
            let color = ObjectColorCodec.uiColor(from: hex) ?? .clear
            let isSelected = selectedHex == hex
            cell.configure(color: color, isSelected: isSelected)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomColorCell.reuseIdentifier, for: indexPath) as! CustomColorCell
            let customColor: UIColor? = isCustomSelected ? ObjectColorCodec.uiColor(from: selectedHex) : nil
            cell.configure(customColor: customColor, isSelected: isCustomSelected)
            cell.onColorSelected = { [weak self] color in
                self?.handleCustomColorSelected(color)
            }
            cell.onDeselectRequested = { [weak self] in
                guard let self else { return }
                self.selectedHex = nil
                self.delegate?.colorSwatchCollectionView(self, didSelectColorHex: nil)
            }
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegate

extension ColorSwatchCollectionView: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item < ObjectColorCodec.palette.count {
            let hex = ObjectColorCodec.palette[indexPath.item]
            selectedHex = (selectedHex == hex) ? nil : hex
            delegate?.colorSwatchCollectionView(self, didSelectColorHex: selectedHex)
        }
    }
}

// MARK: - ColorSwatchCell

private final class ColorSwatchCell: UICollectionViewCell {

    static let reuseIdentifier = "ColorSwatchCell"

    private let colorView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let selectionRing: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 3
        view.layer.borderColor = UIColor.label.cgColor
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.addSubview(colorView)
        contentView.addSubview(selectionRing)

        NSLayoutConstraint.activate([
            colorView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            colorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            colorView.widthAnchor.constraint(equalToConstant: 36),
            colorView.heightAnchor.constraint(equalToConstant: 36),

            selectionRing.centerXAnchor.constraint(equalTo: colorView.centerXAnchor),
            selectionRing.centerYAnchor.constraint(equalTo: colorView.centerYAnchor),
            selectionRing.widthAnchor.constraint(equalToConstant: 36),
            selectionRing.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    func configure(color: UIColor, isSelected: Bool) {
        colorView.backgroundColor = color
        selectionRing.isHidden = !isSelected
    }
}

// MARK: - Color Wheel Ring View

private final class ColorWheelRingView: UIView {

    private let gradientLayer = CAGradientLayer()
    private let innerColorView: UIView = {
        let v = UIView()
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.separator.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.type = .conic
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.colors = (0..<12).map { i in
            UIColor(hue: CGFloat(i) / 12, saturation: 1, brightness: 1, alpha: 1).cgColor
        }
        layer.addSublayer(gradientLayer)
        addSubview(innerColorView)
        NSLayoutConstraint.activate([
            innerColorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            innerColorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            innerColorView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 11/18),
            innerColorView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 11/18)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = bounds
        gradientLayer.frame = b
        let outerR = min(b.width, b.height) / 2
        let innerR = outerR * 11/18
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: b.midX - outerR, y: b.midY - outerR, width: 2 * outerR, height: 2 * outerR))
        path.addEllipse(in: CGRect(x: b.midX - innerR, y: b.midY - innerR, width: 2 * innerR, height: 2 * innerR))
        let mask = CAShapeLayer()
        mask.path = path
        mask.fillRule = .evenOdd
        gradientLayer.mask = mask
        innerColorView.layer.cornerRadius = innerR
    }

    func setInnerColor(_ color: UIColor?) {
        innerColorView.backgroundColor = color ?? .systemGray5
    }
}

// MARK: - CustomColorCell

private final class CustomColorCell: UICollectionViewCell {

    static let reuseIdentifier = "CustomColorCell"

    var onColorSelected: ((UIColor) -> Void)?
    var onDeselectRequested: (() -> Void)?

    private let containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.cgColor
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let colorWheelView: ColorWheelRingView = {
        let view = ColorWheelRingView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let selectionRing: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 3
        view.layer.borderColor = UIColor.label.cgColor
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var currentColor: UIColor = .systemBlue
    private var isCustomColorSelected: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.addSubview(containerView)
        containerView.addSubview(colorWheelView)
        contentView.addSubview(selectionRing)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tap)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 36),
            containerView.heightAnchor.constraint(equalToConstant: 36),

            colorWheelView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            colorWheelView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            colorWheelView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            colorWheelView.heightAnchor.constraint(equalTo: containerView.heightAnchor),

            selectionRing.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            selectionRing.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            selectionRing.widthAnchor.constraint(equalToConstant: 36),
            selectionRing.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    func configure(customColor: UIColor?, isSelected: Bool) {
        isCustomColorSelected = isSelected
        if let customColor {
            currentColor = customColor
            colorWheelView.setInnerColor(customColor)
        } else {
            colorWheelView.setInnerColor(.systemGray5)
        }
        selectionRing.isHidden = !isSelected
    }

    @objc private func handleTap() {
        if isCustomColorSelected {
            onDeselectRequested?()
            return
        }
        let colorPicker = UIColorPickerViewController()
        colorPicker.selectedColor = currentColor
        colorPicker.supportsAlpha = false
        colorPicker.delegate = self

        if let viewController = findViewController() {
            viewController.present(colorPicker, animated: true)
        }
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let vc = nextResponder as? UIViewController {
                return vc
            }
            responder = nextResponder
        }
        return nil
    }
}

extension CustomColorCell: UIColorPickerViewControllerDelegate {
    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        if !continuously {
            onColorSelected?(color)
        }
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        onColorSelected?(viewController.selectedColor)
    }
}
