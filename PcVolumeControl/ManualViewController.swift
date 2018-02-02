//
//  ManualViewController.swift
//  PcVolumeControl
//
//  Created by Bill Booth on 1/26/18.
//  Copyright © 2018 PcVolumeControl. All rights reserved.
//

import UIKit

class ManualViewController: UIViewController, UITextFieldDelegate {
    
    let asyncQueue = DispatchQueue(label: "asyncQueue", attributes: .concurrent)
    var defaults = UserDefaults.standard // to persist the IP/port entered previously
    var SController: StreamController? = nil
    var spinnerView: UIView? = nil

    @IBOutlet weak var Cbutton: UIButton!
    @IBOutlet weak var ServerIPField: UITextField!
    @IBOutlet weak var ServerPortField: UITextField!
    
    @IBAction func ConnectButtonClicked(_ sender: UIButton) {
    // handoff to the main viewcontroller
        guard let PortNum = Int32(self.ServerPortField.text!) else {
            let _ = Alert.showBasic(title: "Error", message: "Bad port number specified.\nThe default is 3000. The port number needs to be between 1-65535.", vc: self)
            return
        }
        guard let IPaddr = self.ServerIPField.text else {
            return
        }

        // Check if the IP field is blank.
        if IPaddr.isEmpty {
            let _ = Alert.showBasic(title: "Error", message: "A host name or IPv4 address is required in order to connect to your PCVolumeControl server.", vc: self)
            return
        } else {
            // They entered *something*
            if IPaddr.matches("^[0-9]") && IPaddr.matches("[0-9]$") {
                // pretty sure it's an IP address, but is it valid?
                if !isValidIP(s: IPaddr) {
                    let _ = Alert.showBasic(title: "Error", message: "The entry '\(IPaddr)' was not a valid IPv4 address.", vc: self)
                    return
                }
            }
        }
        
        defaults.set(IPaddr, forKey: "IPaddr")
        defaults.set(PortNum, forKey: "PortNum")
        defaults.synchronize()
        
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

        ServerIPField.delegate = self
        ServerPortField.delegate = self
        ServerIPField.returnKeyType = UIReturnKeyType.next
        ServerIPField.tag = 1
        ServerPortField.tag = 2
        ServerIPField.autocorrectionType = .no
        ServerPortField.autocorrectionType = .no
        ServerIPField.keyboardType = .numbersAndPunctuation
        ServerPortField.keyboardType = .numberPad
        
        Cbutton.styleButton(cornerRadius: 8, borderWidth: 2, borderColor: UIColor.gray.cgColor)
        addDoneButtonOnKeyboard()
        
        if let ipaddr = defaults.string(forKey: "IPaddr") {
            ServerIPField.text = ipaddr
        }
        if let port = defaults.string(forKey: "PortNum") {
            ServerPortField.text = port
        }

    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        if let nextField = textField.superview?.viewWithTag(textField.tag + 1) as? UITextField {
            nextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return false
    }
    
    func isValidIP(s: String) -> Bool {
        let parts = s.components(separatedBy: ".")
        let nums = parts.flatMap { Int($0) }
        return parts.count == 4 && nums.count == 4 && nums.filter { $0 >= 0 && $0 < 256}.count == 4
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func addDoneButtonOnKeyboard()
    {
        let doneToolbar: UIToolbar = UIToolbar()
        doneToolbar.barStyle = UIBarStyle.default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(ManualViewController.doneButtonAction(_:)))
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ManualConnectSegue" {
            let destVC = segue.destination as! ViewController
            destVC.SController = self.SController // give them our stream controller
            destVC.initialDraw = true // signal to viewDidLoad() to reload everything.
            navigationItem.backBarButtonItem?.title = "Disconnect"
        }
    }

}

extension ManualViewController: StreamControllerDelegate {
    func isAttemptingConnection() {
        print("Connection is in progress...")
        
        asyncQueue.async {
            DispatchQueue.main.async {
                self.spinnerView = UIViewController.displaySpinner(onView: self.view)
            }
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
                self.performSegue(withIdentifier: "ManualConnectSegue", sender: self.SController)
            }
        }
    }
    
    func failedToConnect() {
        if let spinner = spinnerView {
            UIViewController.removeSpinner(spinner: spinner)
            DispatchQueue.main.async {
                let _ = Alert.showBasic(title: "Connection Error", message: "Connection to the server failed.\n\nIs the IP or name correct?\nIs the port open?", vc: self)
            }
        }
    }
    func didGetServerUpdate() {}
    func bailToConnectScreen() {}
    func tearDownConnection() {}
}

// This is the spinner shown when the socket is being set up.
extension ManualViewController {
    func displaySpinner(onView : UIView) -> UIView {
        
        let spinnerView = UIView.init(frame: onView.bounds)
        spinnerView.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        let ai = UIActivityIndicatorView.init(activityIndicatorStyle: .whiteLarge)
        ai.startAnimating()
        ai.center = spinnerView.center
        
        spinnerView.addSubview(ai)
        onView.addSubview(spinnerView)
        
        return spinnerView
    }
    
    func removeSpinner(spinner :UIView) {
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