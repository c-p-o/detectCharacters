//
//  AppDelegate.swift
//  detectCharacters
//
//  Created by christopher otto on 4/24/19.
//  Copyright © 2019 christopher otto. All rights reserved.
//

import Cocoa
import Vision

// main struct for json
struct ImgTxtCoords: Codable {
    let ImgName:String?
    let ImgW:CGFloat?
    let ImgH:CGFloat?
    let TxtLines: [TxtLineForCss]?
}

// struct for each line of characters
struct TxtLineForCss: Codable {
    let Coords: TxtBoxForCss?
    let CharCoords : [TxtBoxForCss]?
}

// struct for coordinates
struct TxtBoxForCss: Codable {
    let x: CGFloat?
    let y: CGFloat?
    let w: CGFloat?
    let h: CGFloat?
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var imgWidth = CGFloat()
    var imgHeight = CGFloat()
    var fileName = String()
    var fileNameWithoutExtension = String()
    var brightnessTest = false
    var pathURL : URL?

    @IBAction func openMenuSelected(_ sender: Any) {
        showDialog()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        showDialog()
    }

    func showDialog() -> Void {
        let dialog = NSOpenPanel();

        brightnessTest = false

        dialog.title                   = "Choose a file";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = false;
        dialog.canCreateDirectories    = false;
        dialog.allowsMultipleSelection = false;
        dialog.allowedFileTypes        = ["png","jpg"];

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file

            if (result != nil) {
                print(result!)
                self.fileName = (result!.path as NSString).lastPathComponent
                self.fileNameWithoutExtension = result!.deletingPathExtension().lastPathComponent
                pathURL = result!
                getImageData(result!)
            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }

    // reads image using path from open dialog
    // and creates vision request
    func getImageData(_ path:URL) -> Void {
        let data = try! Data(contentsOf: path)

        // create NSImage to save height of image for json
        let mainImage = NSImage(data: data)
        self.imgWidth = (mainImage?.size.width)!
        self.imgHeight = (mainImage?.size.height)!

        // create request with charcter boxes set to true
        let textRequest = VNDetectTextRectanglesRequest(completionHandler: detectTextHandler)
        textRequest.reportCharacterBoxes = true

        // perform request
        let vnImage = VNImageRequestHandler(data: data, options: [:])
        try? vnImage.perform([textRequest])
    }

    // returns vision results in format for json
    func getTxtBoxForCss(_ observation:VNRectangleObservation) -> TxtBoxForCss {
        let txtX = round(observation.boundingBox.origin.x * imgWidth)
        let origY = round(observation.boundingBox.origin.y * imgHeight)
        let txtW = round(observation.boundingBox.size.width * imgWidth)
        let txtH = round(observation.boundingBox.size.height * imgHeight)

        // convert to top-left coordinate system
        let txtY = imgHeight - (origY + txtH)

        return TxtBoxForCss(x:txtX,y:txtY,w:txtW,h:txtH)
    }

    func detectTextHandler(request: VNRequest, error: Error?)  -> Void {
        guard let observations = request.results else {
            print("no result")
            return
        }

        // text-detection doesn't work with transparent pngs with text <16% brightness
        // because transparent pixels are actually black set to 0 opacity (rgba(0,0,0,0))
        // this makes the image 20% brighter and tries again if there are no results
        if observations.isEmpty && !brightnessTest {
            let data = try! Data(contentsOf: pathURL!)
            let dataProvider = CGDataProvider(data: data as CFData)
            let cgImageRef = CGImage(pngDataProviderSource: dataProvider!,
                                     decode: nil,
                                     shouldInterpolate: true,
                                     intent: CGColorRenderingIntent.defaultIntent)
            let context = CIContext()
            let currentFilter = CIFilter(name: "CIColorControls")
            let ciImageRef = CIImage(cgImage:cgImageRef!)

            currentFilter?.setValue(ciImageRef,
                                    forKey: kCIInputImageKey)
            currentFilter?.setValue(CGFloat(0.20),
                                    forKey: kCIInputBrightnessKey)

            let newCGImage = context.createCGImage(currentFilter!.outputImage!,
                                                   from: ciImageRef.extent)

            let textRequest = VNDetectTextRectanglesRequest(completionHandler: detectTextHandler)
            textRequest.reportCharacterBoxes = true

            let vnImage = VNImageRequestHandler(cgImage: newCGImage!,
                                                options: [:])
            try? vnImage.perform([textRequest])

            brightnessTest = true

            return
        }

        var txtLines = [TxtLineForCss]()
        let results = observations.map({$0 as? VNTextObservation})

        for result in results {
            if let textObservation = result {

                let coords = getTxtBoxForCss(textObservation as VNRectangleObservation)
                var charCoords = [TxtBoxForCss]()

                if let boxes = textObservation.characterBoxes {
                    for characterBox in boxes {
                        charCoords.append(getTxtBoxForCss(characterBox as VNRectangleObservation))
                    }
                }

                txtLines.append(TxtLineForCss(Coords:coords,
                                              CharCoords:charCoords))
            }
        }

        let imgContent = ImgTxtCoords(ImgName:"\(self.fileName)",
                                      ImgW:imgWidth,
                                      ImgH:imgHeight,
                                      TxtLines:txtLines)

        let jsonEncoder = JSONEncoder()
        let jsonData = try! jsonEncoder.encode(imgContent)
        let jsonString = String(data: jsonData, encoding: .utf8)

        let htmlOutput = String(format:htmlTemplate,
                                arguments: [fileNameWithoutExtension, jsonString!])

        let savePanel = NSSavePanel()
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "\(fileNameWithoutExtension).html"

        if (savePanel.runModal() == NSApplication.ModalResponse.OK) {
            let result = savePanel.url // Pathname of the file

            if (result != nil) {
                do {
                    try htmlOutput.write(to: result!,
                                         atomically:
                        true, encoding: .utf8)
                    showDialog()
                } catch {
                    print(error)
                }

            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

