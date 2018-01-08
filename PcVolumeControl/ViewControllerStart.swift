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

    @IBOutlet weak var Cbutton: UIButton!
    @IBOutlet weak var ServerIPField: UITextField!
    @IBOutlet weak var ServerPortField: UITextField!
    
    @IBOutlet weak var frontAboutButton: UIBarButtonItem!
    @IBAction func frontAboutButtonClicked(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "showAbout", sender: "nothing")
    }
    
    @IBAction func ConnectButtonClicked(_ sender: UIButton) {

        // handoff to the main viewcontroller
        guard let PortNum = Int32(self.ServerPortField.text!) else {
            let _ = Alert.showBasic(title: "Error", message: "Bad port number specified.\nThe default is 3000.", vc: self)
            return
        }
        guard let IPaddr = self.ServerIPField.text else {
            let _ = Alert.showBasic(title: "Error", message: "There was an issue parsing the server IP address or name.", vc: self)
            return
        }
        
        SController = StreamController(address: IPaddr, port: PortNum, delegate: self)
        SController?.delegate = self
        
        // Start looking for messages in the publish subject.
        SController?.processMessages()
        
        // Make the initial server connection and get the first message,
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
        
        setNeedsStatusBarAppearanceUpdate() // light upper bar
     
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        if let nextField = textField.superview?.viewWithTag(textField.tag + 1) as? UITextField {
            nextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        // Do not add a line break
        return false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ConnectSegue" {
            let destVC = segue.destination as! ViewController
            destVC.SController = self.SController
        }
    }
}

// TODO: actually connect this to the text boxes
extension UITextField {
    func setPreferences() {
        self.layer.cornerRadius = 8
//        self.layer.borderColor = UIColor.grayColor().CGColor
        self.layer.borderWidth = 2
    }
}

extension ViewControllerStart: StreamControllerDelegate {
    func didGetServerUpdate() {
        
    }
    func bailToConnectScreen() {
        
    }
    func tearDownConnection() {
    }
    func isAttemptingConnection() {
        print("connection is in progress...")

        // validate that the connection was actually opened.
        asyncQueue.async {
            DispatchQueue.main.async {
                self.spinnerView = UIViewController.displaySpinner(onView: self.view)
            }
        }
    }
    func didConnectToServer() {
        print("did connect to server delegation...")
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
        if let spinner = spinnerView {
            UIViewController.removeSpinner(spinner: spinner)
        }
    }
}

extension UIViewController {
    class func displaySpinner(onView : UIView) -> UIView {
        
        let spinnerView = UIView.init(frame: onView.bounds)
        spinnerView.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        let ai = UIActivityIndicatorView.init(activityIndicatorStyle: .whiteLarge)
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
