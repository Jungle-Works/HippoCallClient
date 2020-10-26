//
//  EstablishingConnectionView.swift
//  HippoCallClient
//
//  Created by Arohi Sharma on 26/10/20.
//

import Foundation

class EstablishingConnectionView : UIView {
    
    //MARK:- IBOutlets
    
    @IBOutlet var label_Connecting : UILabel!{
        didSet{
            label_Connecting.text = "Please wait while we are establishing the connection.."
        }
    }
    
    static var shared: EstablishingConnectionView!
    
    //MARK:- Functions
    
    class  func loadView(with frame: CGRect)-> EstablishingConnectionView? {
        let view = Bundle.init(identifier: "org.cocoapods.HippoCallClient")?.loadNibNamed("EstablishingConnectionView", owner: nil, options: nil)?.first as? EstablishingConnectionView
        view?.frame = frame
        view?.clipsToBounds = true
        return view
    }
    
    
}
