//
//  AppDelegate.swift
//

import Cocoa
import MediaKeyTap

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate {

    @IBOutlet weak var menuView: NSMenu!
    @IBOutlet weak var SettingsButton: NSButton!
    @IBOutlet weak var SettingsWindow: NSWindow!
    @IBOutlet weak var RaspberryPiAddressField: NSTextField!
    @IBOutlet weak var BrightnessSlider: NSSlider!
    @IBOutlet weak var QuitButton: NSButton!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var windowController: NSWindowController!
    let settings = UserDefaults.standard
    
    var timer: Timer? = nil
    var currentGamma = Float(1.0)
    var mediaKeyTap: MediaKeyTap?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        //Set menubar icon
        let icon = NSImage(named: "mainIcon")
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon
        
        //Set settings field delegate
        RaspberryPiAddressField.delegate = self
        
        //Create a new menu item for the slider
        let sliderItem = NSMenuItem()
        sliderItem.title = ""
        sliderItem.view = BrightnessSlider
        menuView.addItem(sliderItem)
        
        //Add parameters to the slider
        BrightnessSlider.target = self
        BrightnessSlider.action = #selector(sliderChange)
        
        //Resize settings button
        SettingsButton.setFrameSize(NSSize(width: 24, height: 24))
        SettingsButton.frame.size.width = 24
        
        //Add settings button to the bottom of the slider
        let menuItemSettings = NSMenuItem()
        menuItemSettings.view = SettingsButton
        menuView.addItem(menuItemSettings)

        //Init the settings window
        windowController = NSWindowController()
        windowController.contentViewController = SettingsWindow.contentViewController
        windowController.window = SettingsWindow

        //Show menu
        statusItem.menu = menuView
        
        //Load saved settings
        RaspberryPiAddressField.stringValue = settings.string(forKey: "raspberry_address") ?? ""
        
        //let defaults = UserDefaults.standard
        let currentVal = settings.string(forKey: "brightness") ?? ""
        BrightnessSlider.stringValue = currentVal.isEmpty ? "50" : currentVal
        
        //Trigger change if saved value found
        if(!currentVal.isEmpty) {
            updatePwmValue(value: BrightnessSlider.floatValue)
        }
        
        //Media keys listener
        self.startMediaKeyOnAccessibiltiyApiChange()
        self.startMediaKeyTap()
        
    }
    
    //On slider change
    @IBAction func sliderChange(_ sender:Any) {
        settings.set(BrightnessSlider.stringValue, forKey: "brightness")
        updatePwmValue(value: BrightnessSlider.floatValue)
    }
    
    //Open settings window
    @IBAction func openSettings(_ sender: Any) {
        windowController.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    //When the IP address is changed in the app
    func controlTextDidChange(_ obj: Notification) {

        //Check for field
        if let textField = obj.object as? NSTextField, self.RaspberryPiAddressField.identifier == textField.identifier {
            //Save value
            settings.set(textField.stringValue, forKey: "raspberry_address")
        }
        
    }
    
    //Quit button
    @IBAction func QuitApp(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }
    
    //Send a request to Node-RED to change the PWM value
    func updatePwmValue(value: Float) {
        let host = settings.string(forKey: "raspberry_address") ?? ""
        
        //No Node-RED, so just simulate brightness change
        if(host.isEmpty) {
            set_gamma(value: value/100)
        } else {
            let brightness = self.BrightnessSlider.stringValue
            let url = URL(string: host+"/pwm/"+brightness)
            let task = URLSession.shared.dataTask(with: url! as URL) { data, response, error in
                guard let data = data, error == nil else { return }
                print(NSString(data: data, encoding: String.Encoding.utf8.rawValue) ?? "")
            }

            task.resume()
        }
    }
    
    //Set screen's gamma table to reduce brigthness
    func set_gamma(value: Float) {
        if(value>0.1) {
            CGSetDisplayTransferByTable(CGMainDisplayID(), 2, [0, value], [0, value], [0, value])
        } else {
            CGSetDisplayTransferByTable(CGMainDisplayID(), 2, [0, 0.1], [0, 0.1], [0, 0.1])
        }
    }
    
    //If accessibility api changes, try to start media key listener
    private func startMediaKeyOnAccessibiltiyApiChange() {
        DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name(rawValue: "com.apple.accessibility.api"), object: nil, queue: nil) { _ in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(100)) {
                self.startMediaKeyTap()
            }
        }
    }
    
}

//Extend AppDelegate with Media Key Tap functions
extension AppDelegate: MediaKeyTapDelegate {
    
    //Try to start the media key tap listeners for brightness down and up
    private func startMediaKeyTap() {
        var keys: [MediaKey]
        keys = [.brightnessUp, .brightnessDown]
        
        self.mediaKeyTap?.stop()
        self.mediaKeyTap = MediaKeyTap(delegate: self, for: keys, observeBuiltIn: false)
        self.mediaKeyTap?.start()
    }

    //Handle the media key taps
    func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
        let step: Float = 100/16

        switch mediaKey {
            case .brightnessUp:
                let roundedValue = (round(self.BrightnessSlider.floatValue / step) * step) + step
                
                if(roundedValue>100) {
                    self.updatePwmValue(value: self.BrightnessSlider.floatValue)
                } else {
                    self.BrightnessSlider.floatValue = roundedValue
                    self.updatePwmValue(value: roundedValue)
                }

                showOSD()
            case  .brightnessDown:
                let roundedValue = (round(self.BrightnessSlider.floatValue / step) * step) - step
                
                if(roundedValue<0) {
                    self.updatePwmValue(value: self.BrightnessSlider.floatValue)
                } else {
                    self.BrightnessSlider.floatValue = roundedValue
                    self.updatePwmValue(value: roundedValue)
                }
                
                showOSD()
            default: break
        }
    }
    
    func showOSD() {
        guard let manager = OSDManager.sharedManager() as? OSDManager else {
          return
        }
        manager.showImage(Int64(1), onDisplayID: CGMainDisplayID(), priority: 0x1F4, msecUntilFade: 1000, filledChiclets: UInt32(16*self.BrightnessSlider.floatValue/100), totalChiclets: UInt32(16), locked: false)
    }
}
