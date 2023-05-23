//
//  AppALConstants.swift
//  AppLocker
//
//  Created by Oleg Ryasnoy on 07.07.17.
//  Copyright © 2017 Oleg Ryasnoy. All rights reserved.
//

import UIKit
import AudioToolbox
import LocalAuthentication

public enum ALConstants {
    static let nibName = "AppLocker"
    static let kPincode = "tewa_pincode" // Key for saving pincode to UserDefaults
    static let kLocalizedReason = "Unlock with sensor" // Your message when sensors must be shown
    static let duration = 0.3 // Duration of indicator filling
    static let maxPinLength = 4
    
    enum button: Int {
        case delete = 1000
        case cancel = 1001
    }
}

public struct ALAppearance { // The structure used to display the controller
    public var title: String?
    public var subtitle: String?
    public var deleteString: String?
    public var cancelString: String?
    public var contactUsString: String?
    public var createString: String?
    public var validateString: String?
    public var confirmString: String?
    public var image: UIImage?
    public var color: UIColor?
    public var isSensorsEnabled: Bool?
    public var supprotURL: URL?
    public var isRTL: Bool = false
    public var isLightTheme: Bool = false
    public var supportButtonAction: (()->Void)?
    public init() {}
}

public enum ALMode { // Modes for AppLocker
    case validate
    case change
    case deactive
    case create
}

public class AppLocker: UIViewController {
    
    // MARK: - Top view
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var submessageLabel: UILabel!
    @IBOutlet var pinIndicators: [Indicator]!
    @IBOutlet weak var contactSupportButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    @IBOutlet weak var button1: UIButton!
    @IBOutlet weak var button2: UIButton!
    @IBOutlet weak var button3: UIButton!
    @IBOutlet weak var button4: UIButton!
    @IBOutlet weak var button5: UIButton!
    @IBOutlet weak var button6: UIButton!
    @IBOutlet weak var button7: UIButton!
    @IBOutlet weak var button8: UIButton!
    @IBOutlet weak var button9: UIButton!
    @IBOutlet weak var button0: UIButton!
    
    
    // MARK: - Pincode

    private let context = LAContext()
    private var pin = "" // Entered pincode
    private var reservedPin = "" // Reserve pincode for confirm
    private var isFirstCreationStep = true
    private var retryCount: Int = 0
    private var supportURL: URL?
    public var confirmString: String?
    private var savedPin: String? {
        get {
            return UserDefaults.standard.string(forKey: ALConstants.kPincode)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ALConstants.kPincode)
        }
    }
    
    fileprivate var mode: ALMode? {
        didSet {
            let mode = self.mode ?? .validate
            switch mode {
            case .create:
                submessageLabel.text = "Create your TeWa Passcode" // Your submessage for create mode
            case .change:
                submessageLabel.text = "Enter your TeWa Passcode" // Your submessage for change mode
            case .deactive:
                submessageLabel.text = "Enter your TeWa Passcode" // Your submessage for deactive mode
            case .validate:
                submessageLabel.text = "Enter your TeWa Passcode" // Your submessage for validate mode
                cancelButton.isHidden = true
                isFirstCreationStep = false
            }
        }
    }
    private var supportButtonAction: (()->Void)?
    private func precreateSettings () { // Precreate settings for change mode
        mode = .create
        clearView()
    }
    
    private func drawing(isNeedClear: Bool, tag: Int? = nil) { // Fill or cancel fill for indicators
        let results = pinIndicators.filter { $0.isNeedClear == isNeedClear }
        let pinView = isNeedClear ? results.last : results.first
        pinView?.isNeedClear = !isNeedClear
        pinView?.layer.cornerRadius = (pinView?.frame.size.width ?? 0)/2
        pinView?.clipsToBounds = true
        UIView.animate(withDuration: ALConstants.duration, animations: {
            if #available(iOS 12, *) {
                if UIScreen.main.traitCollection.userInterfaceStyle == .light {
                    pinView?.backgroundColor = isNeedClear ? .clear : .black
                }
                else {
                    pinView?.backgroundColor = isNeedClear ? .clear : .white
                }
            }
        }) { _ in
            isNeedClear ? self.pin = String(self.pin.dropLast()) : self.pincodeChecker(tag ?? 0)
        }
    }
    
    private func pincodeChecker(_ pinNumber: Int) {
        if pin.count < ALConstants.maxPinLength {
            pin.append("\(pinNumber)")
            if pin.count == ALConstants.maxPinLength {
                switch mode ?? .validate {
                case .create:
                    createModeAction()
                case .change:
                    changeModeAction()
                case .deactive:
                    deactiveModeAction()
                case .validate:
                    validateModeAction()
                }
            }
        }
    }
    
    // MARK: - Modes
    private func createModeAction() {
        if isFirstCreationStep {
            isFirstCreationStep = false
            reservedPin = pin
            clearView()
            submessageLabel.text = confirmString
        } else {
            confirmPin()
        }
    }
    
    private func changeModeAction() {
        pin == savedPin ? precreateSettings() : incorrectPinAnimation()
    }
    
    private func deactiveModeAction() {
        pin == savedPin ? removePin() : incorrectPinAnimation()
    }
    
    private func validateModeAction() {
        if pin == savedPin {
            retryCount = 0
            UserDefaults.standard.set(false, forKey: "tewa_passcode_background_enabled")
            dismiss(animated: true, completion: nil)
        }
        else {
            retryCount += 1
            incorrectPinAnimation()
        }
//        pin == savedPin ? dismiss(animated: true, completion: nil) : incorrectPinAnimation()
    }
    
    private func removePin() {
        UserDefaults.standard.removeObject(forKey: ALConstants.kPincode)
        UserDefaults.standard.set(false, forKey: "tewa_passcode_enabled")
        dismiss(animated: true, completion: nil)
    }
    
    private func confirmPin() {
        if pin == reservedPin {
            savedPin = pin
            dismiss(animated: true, completion: {
                UserDefaults.standard.set(true, forKey: "tewa_passcode_enabled")
                NotificationCenter.default.post(name: Notification.Name("tewa_new_password_setuped"), object: nil)
            })
        } else {
            incorrectPinAnimation()
        }
    }
    
    private func incorrectPinAnimation() {
        if retryCount >= 3 && mode == .validate{
            contactSupportButton.isHidden = false
        }
        pinIndicators.forEach { view in
            view.shake(delegate: self)
            view.backgroundColor = .clear
        }
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    fileprivate func clearView() {
        pin = ""
        pinIndicators.forEach { view in
            view.isNeedClear = false
            UIView.animate(withDuration: ALConstants.duration, animations: {
                view.backgroundColor = .clear
            })
        }
    }
    
    // MARK: - Touch ID / Face ID
    fileprivate func checkSensors() {
        guard mode == .validate else {return}
        
        var policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics // iOS 8+ users with Biometric and Custom (Fallback button) verification
        
        // Depending the iOS version we'll need to choose the policy we are able to use
        if #available(iOS 9.0, *) {
            // iOS 9+ users with Biometric and Passcode verification
            policy = .deviceOwnerAuthentication
        }
        
        var err: NSError?
        // Check if the user is able to use the policy we've selected previously
        guard context.canEvaluatePolicy(policy, error: &err) else {return}
        // The user is able to use his/her Touch ID / Face ID 👍
        context.evaluatePolicy(policy, localizedReason: ALConstants.kLocalizedReason, reply: {  success, error in
            if success {
                DispatchQueue.main.async {
                    self.retryCount = 0
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "applocker_present_last_time")
                    self.dismiss(animated: true, completion: nil)
                }
            }
        })
    }
    
    // MARK: - Keyboard
    @IBAction func keyboardPressed(_ sender: UIButton) {
        switch sender.tag {
        case ALConstants.button.delete.rawValue:
            drawing(isNeedClear: true)
        case ALConstants.button.cancel.rawValue:
            clearView()
            retryCount = 0
            dismiss(animated: true, completion: nil)
        default:
            drawing(isNeedClear: false, tag: sender.tag)
        }
    }
    
    @IBAction func contactSupportPressed(_ sender: UIButton) {
        if let url = supportURL {
            UIApplication.shared.open(url)
        }
        else {
            supportButtonAction?()
        }
        
    }
    
}

// MARK: - CAAnimationDelegate
extension AppLocker: CAAnimationDelegate {
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        clearView()
    }
}

// MARK: - Present
public extension AppLocker {
    // Present AppLocker
    class func present(with mode: ALMode, and config: ALAppearance? = nil) {
        guard let root = UIApplication.shared.keyWindow?.rootViewController,
              
              let locker = Bundle(for: self.classForCoder()).loadNibNamed(ALConstants.nibName, owner: self, options: nil)?.first as? AppLocker else {
            return
        }
        locker.contactSupportButton.isHidden = true
        locker.messageLabel.text = config?.title ?? ""
        locker.submessageLabel.text = config?.subtitle ?? ""
        locker.deleteButton.setTitle(config?.deleteString, for: .normal)
        locker.cancelButton.setTitle(config?.cancelString, for: .normal)
        locker.contactSupportButton.setTitle(config?.contactUsString, for: .normal)
        locker.view.backgroundColor = config?.color ?? .black
        locker.supportURL = config?.supprotURL
        locker.mode = mode
        locker.supportButtonAction = config?.supportButtonAction
        if config!.isRTL {
            locker.view.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.messageLabel.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.submessageLabel.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.contactSupportButton.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.cancelButton.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.deleteButton.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.button1.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.button2.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.button3.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.button4.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.button5.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.button6.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.button7.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.button8.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.button9.transform = CGAffineTransform(scaleX: -1, y: 1)
            locker.button0.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
        if #available(iOS 12, *) {
            if UIScreen.main.traitCollection.userInterfaceStyle == .light {
                locker.messageLabel.textColor = .black
                locker.submessageLabel.textColor = .black
                locker.contactSupportButton.setTitleColor(.black, for: .normal)
                locker.cancelButton.setTitleColor(.black, for: .normal)
                locker.deleteButton.setTitleColor(.black, for: .normal)
                locker.button1.setTitleColor(.black, for: .normal)
                locker.button2.setTitleColor(.black, for: .normal)
                locker.button3.setTitleColor(.black, for: .normal)
                locker.button4.setTitleColor(.black, for: .normal)
                locker.button5.setTitleColor(.black, for: .normal)
                locker.button6.setTitleColor(.black, for: .normal)
                locker.button7.setTitleColor(.black, for: .normal)
                locker.button8.setTitleColor(.black, for: .normal)
                locker.button9.setTitleColor(.black, for: .normal)
                locker.button0.setTitleColor(.black, for: .normal)
            }
        }
        switch mode {
        case .create:
            locker.submessageLabel.text = config?.createString
            locker.confirmString = config?.confirmString
        case .validate:
            locker.submessageLabel.text = config?.validateString
        default:
            locker.submessageLabel.text = "not_localized"
        }
        if config?.isSensorsEnabled ?? false {
            locker.checkSensors()
        }
        if let image = config?.image {
            locker.photoImageView.image = image
        } else {
            locker.photoImageView.isHidden = true
        }
        locker.modalPresentationStyle = .fullScreen

        if root.presentedViewController?.presentedViewController !=  nil {
            root.presentedViewController?.presentedViewController?.present(locker, animated: false, completion: nil)
        }
        else if root.presentedViewController != nil {
            root.presentedViewController?.present(locker, animated: false, completion: nil)
        }
        else {
            root.present(locker, animated: false, completion: nil)
        }
    }
    
}
