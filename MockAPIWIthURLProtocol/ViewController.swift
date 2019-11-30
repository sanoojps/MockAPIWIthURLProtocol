//
//  ViewController.swift
//  MockAPIWIthURLProtocol
//
//  Created by carvak on 18/09/2019.
//  Copyright © 2019 0. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        guard let url: URL =
            URL(
                string: "https://jsonplaceholder.typicode.com/posts/1"
            ) else { return }
        
        URLSession.shared.dataTask(with: url) { (data:Data?, response: URLResponse?, error: Error?) in
            
            
            
        }.resume()
        
    }


}

