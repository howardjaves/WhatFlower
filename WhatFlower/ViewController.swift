//
//  ViewController.swift
//  WhatFlower
//
//  Created by Howard Javes on 07/11/2021.
//

import UIKit
import CoreML
import Vision
import Alamofire
import SwiftyJSON
import SDWebImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    let imagePicker = UIImagePickerController()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = false
    }

    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!

    @IBAction func cameraTapped(_ sender: UIBarButtonItem) {
        present(imagePicker, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if let selectedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {


            guard let ciImage = CIImage(image: selectedImage) else {
                fatalError("Could not convert to CIImage")
            }

            detect(ciImage)
        }

        dismiss(animated: true, completion: nil)
    }

    func detect(_ ciImage: CIImage) {
        guard let model = try? VNCoreMLModel(for: Inceptionv3().model) else {
            fatalError("Loading CoreML model failed.")
        }

        let request = VNCoreMLRequest(model: model) { (request, error) in
            guard let results = request.results as? [VNClassificationObservation] else {
                fatalError("Unable to convert model results to VNClassificationObservation")
            }

            if let firstResult = results.first {
                self.navigationItem.title = firstResult.identifier
                self.lookupInWikipedia("barberton daisy" /*firstResult.identifier*/)
            }
        }

        let handler = VNImageRequestHandler(ciImage: ciImage)

        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
    }

    func lookupInWikipedia(_ subject: String) {
        let wikipediaUrl = "https://en.wikipedia.org/w/api.php"

          let parameters : [String:String] = [
          "format" : "json",
          "action" : "query",
          "prop" : "extracts|pageImages",
          "exintro" : "",
          "explaintext" : "",
          "titles" : subject,
          "indexpageids" : "",
          "redirects" : "1",
          "pithumbsize" : "500"
          ]

        AF.request(wikipediaUrl, method: .get, parameters: parameters).validate().responseJSON { (response) in
                print("Got the info")
                print(response)

            if let data = response.data {
                do {
                    let json = try JSON(data: data)
                    guard let pageId = json["query"]["pageids"][0].string else {
                      print("Unable to get pageId")
                      return
                    }

                    print("Page id = \(pageId)")
                    if let extract = json["query"]["pages"][pageId]["extract"].string {
                        print("Extract: \(extract)")
                        self.descriptionLabel.text = extract
                    }

                    if let flowerImageURL = json["query"]["pages"][pageId]["images"]["source"].string {
                        self.image.sd_setImage(with: URL(string: flowerImageURL))
                    }

                } catch {
                    print("Unable to parse data")
                }
            }

        }
    }
}

