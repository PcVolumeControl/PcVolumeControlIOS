//
//  ViewControllerStart.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 12/21/17.
//  Copyright © 2017 PcVolumeControl. All rights reserved.
//

import UIKit
import Foundation
import Socket

class ViewControllerStart: UIViewController, UITextFieldDelegate {
    // This is controlling the initial connection screen.
    
    let asyncQueue = DispatchQueue(label: "asyncQueue", attributes: .concurrent)
    var serverConnection: Bool?
    var spinnerView: UIView? = nil
    var SController: StreamController? = nil
    var defaults = UserDefaults.standard // to persist the IP/port entered previously

    @IBOutlet weak var Cbutton: UIButton!
    @IBOutlet weak var ServerIPField: UITextField!
    @IBOutlet weak var ServerPortField: UITextField!
    
    @IBOutlet weak var frontAboutButton: UIBarButtonItem!
    @IBAction func frontAboutButtonClicked(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "showAbout", sender: "nothing")
    }
    
    @IBAction func ConnectButtonClicked(_ sender: UIButton) {
        // handoff to the main viewcontroller
        // This function is going to validate both address and port. We do it here and not in the stream controller
        // because we want to fail fast and have all validation code/user alerts in a single spot.
        
        let userInputServer = self.ServerIPField.text
        var IPaddr = "127.0.0.1"  // a sensible initialization/default because it's a valid address, but semantically makes no sense.
        
        // This only checks to see if we can make an Int32 out of the port number. Validation is done below.
        guard let PortNum = Int32(self.ServerPortField.text!) else {
            let _ = Alert.showBasic(title: "Error", message: "Bad port number specified.\nThe default is 3000. The port number needs to be between 1-65535.", vc: self)
            return
        }

        // Check if the IP field is blank.
        if userInputServer!.isEmpty {
            let _ = Alert.showBasic(title: "Error", message: "A host name or IPv4 address is required in order to connect to your PCVolumeControl server.", vc: self)
            return
        } else {
            // Regex match for a v4 address
            if userInputServer!.matches("^[0-9]") && userInputServer!.matches("[0-9]$") {
                // pretty sure it's an IPv4 address, but is it valid?
                if !isValidIP(s: userInputServer!) {
                    let _ = Alert.showBasic(title: "Error", message: "The entry '\(userInputServer!)' was not a valid IPv4 address.", vc: self)
                    return
                } else {
                    IPaddr = userInputServer!
                }
            } else {
                // Try resolving it.
                print("DEBUG: resolving....")
                guard let ip = getIPs(dnsName: userInputServer!) else {
                    print("DNS resolution failed on this user input: \(userInputServer!)")
                    let _ = Alert.showBasic(title: "Error", message: "DNS resolution failed for hostname\n'\(userInputServer!)'", vc: self)
                    return
                }
                IPaddr = ip  // We got an address, so assign it.
                print("DNS resolution for hostname '\(userInputServer!)' yielded: \(IPaddr)")
            }
        }
        
        if !isValidPort(p: PortNum) {
            let _ = Alert.showBasic(title: "Error", message: "Bad port number specified.\nThe default is 3000. The port number needs to be between 1-65535.", vc: self)
            return
        }
        
        // Whether it's a name or an IP, the last successfully-used will become the default here.
        defaults.set(userInputServer!, forKey: "IPaddr")
        defaults.set(PortNum, forKey: "PortNum")
        
        // The stream controller only deals in IP addresses for its socket connections.
        SController = StreamController(address: IPaddr, port: PortNum, delegate: self)
        SController?.delegate = self
        
        // Start looking for messages in the publish subject.
        SController?.processMessages()
        
        // Make the initial server connection and get the first message.
        asyncQueue.async {
            self.SController?.connectNoSend()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        ServerIPField.delegate = self
        ServerPortField.delegate = self
        ServerIPField.returnKeyType = UIReturnKeyType.next
        ServerIPField.tag = 1
        ServerPortField.tag = 2
        ServerIPField.autocorrectionType = .no
        ServerPortField.autocorrectionType = .no
        ServerIPField.keyboardType = .numbersAndPunctuation
        ServerPortField.keyboardType = .numberPad
        ServerPortField.textColor = .black
        
        setNeedsStatusBarAppearanceUpdate() // light upper bar
        
        // connect button styling
        Cbutton.styleButton(cornerRadius: 8, borderWidth: 2, borderColor: UIColor.gray.cgColor)
        addDoneButtonOnKeyboard()
        
        if let ipaddr = defaults.string(forKey: "IPaddr") {
            ServerIPField.text = ipaddr
        }
        if let port = defaults.string(forKey: "PortNum") {
            ServerPortField.text = port
        }
        
    }
    
    // TODO: This hasn't been tested with multiple addresses in the response.
    func getIPs(dnsName: String) -> String? {
        let host = CFHostCreateWithName(nil, dnsName as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray? {
            for case let theAddress as NSData in addresses {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let numAddress = String(cString: hostname)
                    return numAddress
                }
            }
        }
        
        return nil
    }
    
    // used to move between IP and Port fields
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        if let nextField = textField.superview?.viewWithTag(textField.tag + 1) as? UITextField {
            nextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ConnectSegue" {
            let destVC = segue.destination as! ViewController
            destVC.SController = self.SController // give them our stream controller
            destVC.initialDraw = true // signal to viewDidLoad() to reload everything.
            destVC.modalPresentationStyle = .fullScreen
            destVC.modalTransitionStyle = .crossDissolve
        }
        if segue.identifier == "showAbout" {
            let destVC = segue.destination as UIViewController
            destVC.modalPresentationStyle = .fullScreen
            destVC.modalTransitionStyle = .flipHorizontal
        }
    }
    func addDoneButtonOnKeyboard()
    {
        let doneToolbar: UIToolbar = UIToolbar()
        doneToolbar.barStyle = UIBarStyle.default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: UIBarButtonItem.Style.done, target: self, action: #selector(ViewControllerStart.doneButtonAction(_:)))
        var items = [UIBarButtonItem]()
        items.append(flexSpace)
        items.append(done)
        items.append(flexSpace)
        
        doneToolbar.items = items
        doneToolbar.sizeToFit()
        
        ServerPortField.inputAccessoryView = doneToolbar
        
    }
    
    @objc func doneButtonAction(_ sender: UIBarButtonItem!)
    {
        view.endEditing(true)
    }
    // This obviously only supports v4, but if they used a hostname and got a AAAA record back, we would technically work with v6.
    func isValidIP(s: String) -> Bool {
        let parts = s.components(separatedBy: ".")
        let nums = parts.compactMap { Int($0) }
        return parts.count == 4 && nums.count == 4 && nums.filter { $0 >= 0 && $0 < 256}.count == 4
    }
    
    func isValidPort(p: Int32) -> Bool {
        let portRange = 1...65535
        if portRange.contains(Int(p)){
            return true
        }
        return false
    }
}

extension ViewControllerStart: StreamControllerDelegate {
    func isAttemptingConnection() {
        let timeout = 3.0 // in seconds
        
        print("Connection is in progress...")
        let semaphore = DispatchSemaphore(value: 0)
        asyncQueue.async {
            DispatchQueue.main.async {
                self.spinnerView = UIViewController.displaySpinner(onView: self.view)
                // This signal allows us to fail fast.
                semaphore.signal()
            }
        }
        // This timeout code will be hit/executed only if the doesn't go away after the timeout.
        // In normal operation, the spinner should be gone very quickly. Less than a second.
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            print("Timeout hit during initial server connection")
        }
    }
    func didConnectToServer() {
        print("Server connection complete. Moving to main VC.")
        asyncQueue.async {
            DispatchQueue.main.async {
                if let spinner = self.spinnerView {
                    UIViewController.removeSpinner(spinner: spinner)
                }
                // go to the next screen, pushing along the stream controller instance.
                self.performSegue(withIdentifier: "ConnectSegue", sender: self.SController)
            }
        }
    }
    
    func failedToConnect() {
        DispatchQueue.main.async { [self] in
            let _ = Alert.showBasic(title: "Connection Error", message: "Connection to the server failed.\n\nIs the endpoint correct?\nIs the TCP port open?", vc: self)
        }
        if let spinner = spinnerView {
            UIViewController.removeSpinner(spinner: spinner)
        }
    }
    func didGetServerUpdate() {}
    func bailToConnectScreen() {}
    func tearDownConnection() {}
}

// This is the spinner shown when the socket is being set up.
extension UIViewController {
    class func displaySpinner(onView : UIView) -> UIView {
        
        let spinnerView = UIView.init(frame: onView.bounds)
        spinnerView.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        let ai = UIActivityIndicatorView.init(style: .whiteLarge)
        ai.startAnimating()
        ai.center = spinnerView.center
    
        spinnerView.addSubview(ai)
        onView.addSubview(spinnerView)

        return spinnerView
    }
    
    class func removeSpinner(spinner :UIView) {
        DispatchQueue.main.async {
            spinner.removeFromSuperview()
        }
    }
}

// Customizing the Connect button a bit
extension UIButton {
    func styleButton(cornerRadius: CGFloat, borderWidth: CGFloat, borderColor: CGColor) {
        self.layer.cornerRadius = cornerRadius
        self.layer.borderWidth = borderWidth
        self.layer.borderColor = borderColor
    }
}

// Extend String so we can allow regex matching on the domain name/IP entered.
extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
