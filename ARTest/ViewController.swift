//
//  ViewController.swift
//  ARTest
//
//  Created by Laurent on 20/11/2017.
//  Copyright © 2017 Laurent68k. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    
    /// ---------------------------------------------------------------------------------------------------------------------------------------------
    //  ViewController classical override
    override func viewDidLoad() {
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard ARWorldTrackingConfiguration.isSupported else {
            
            let alertController = UIAlertController(title: NSLocalizedString("ARKit is not available", comment: ""), message: NSLocalizedString("ARKit is not available on this device.", comment: ""), preferredStyle: .alert)
            
            let okAction = UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .cancel, handler: {
                
                _ in
                
                fatalError("ARKit is not available on this device")
                
            } )
            
            //    Add the both possibilities
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
            
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        self.sceneView.session.run(configuration)
        self.sceneView.session.delegate = self
        self.sceneView.showsStatistics = true

        // Create a new scene
//        let scene = SCNScene(named: "art.scnassets/ship.scn")!
//        self.sceneView.scene = scene

        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.sceneView.session.pause()
    }
 
    /// ---------------------------------------------------------------------------------------------------------------------------------------------
    // Implementation from ARSCNViewDelegate
    /// ---------------------------------------------------------------------------------------------------------------------------------------------

    
    // Add a new node/object
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Create a SceneKit plane to visualize the plane anchor using its position and extent.
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        
        let earthRadius = min(CGFloat(planeAnchor.extent.x), CGFloat(planeAnchor.extent.z)) / 4.0
        let marsRadius = earthRadius / 2.0

        
        let sphereEarth = SCNSphere(radius: earthRadius )
        let sphereMars = SCNSphere(radius: marsRadius )

        let planeNode = SCNNode(geometry: plane)
        let sphereEarthNode = SCNNode(geometry: sphereEarth)
        let sphereMarsNode = SCNNode(geometry: sphereMars)

        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        
        /*
         `SCNPlane` is vertically oriented in its local coordinate space, so rotate the plane to match the horizontal orientation of `ARPlaneAnchor`.
         */
        planeNode.eulerAngles.x = -.pi / 2
        
        // Make the plane visualization semitransparent to clearly show real-world placement.
        planeNode.opacity = 0.25
        
        let altitude = planeAnchor.extent.x    //  Just to have an altitude
        
        sphereEarthNode.simdPosition = float3(planeAnchor.center.x, altitude, planeAnchor.center.z)
        sphereEarthNode.opacity = 1.0

        sphereMarsNode.simdPosition = float3( (planeAnchor.center.x + Float(2.0 * earthRadius)), altitude, planeAnchor.center.z)
        sphereMarsNode.opacity = 1.0

        let materialEarth = SCNMaterial()
        materialEarth.diffuse.contents = UIImage(named: "earthTexture.jpg")
        materialEarth.specular.contents = UIColor.white
        materialEarth.shininess = 1.0

        let materialMars = SCNMaterial()
        materialMars.diffuse.contents = UIImage(named: "marsTexture.jpg")
        materialMars.specular.contents = UIColor.white
        materialMars.shininess = 1.0
        
        sphereEarth.materials = [ materialEarth ]
        sphereMars.materials = [ materialMars ]
        
        
        node.addChildNode(planeNode)
        node.addChildNode(sphereEarthNode)
        node.addChildNode(sphereMarsNode)
    }
    
    // Update node/object
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update content only for plane anchors and nodes matching the setup created in `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        // Plane estimation may shift the center of a plane relative to its anchor's transform.
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        /*
         Plane estimation may extend the size of the plane, or combine previously detected
         planes into a larger one. In the latter case, `ARSCNView` automatically deletes the
         corresponding node for one plane, then calls this method to update the size of
         the remaining plane.
         */
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
    }
    
    /// ---------------------------------------------------------------------------------------------------------------------------------------------
    // Implementation from ARSessionDelegate
    /// ---------------------------------------------------------------------------------------------------------------------------------------------

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
        guard let frame = session.currentFrame else {
            return
        }
        updateSessionState(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        
        guard let frame = session.currentFrame else {
            return
        }
        updateSessionState(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        
        guard let frame = session.currentFrame else {
            return
        }
        updateSessionState(for: frame, trackingState: camera.trackingState)
    }
    
    /// ---------------------------------------------------------------------------------------------------------------------------------------------
    // Implementation from ARSessionObserver
    /// ---------------------------------------------------------------------------------------------------------------------------------------------

    func sessionWasInterrupted(_ session: ARSession) {
        
        sessionInfoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        
        //sessionInfoLabel.text = "Session interruption ended"
        resetTracking()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        
        //sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
        resetTracking()
    }
    
    // MARK: - Private methods
    
    private func updateSessionState(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move the device around to detect horizontal surfaces."
            
        case .normal:
            // No feedback needed when tracking is normal and planes are visible.
            message = ""
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        }
        
        sessionInfoLabel.text = message
        sessionInfoLabel.isHidden = message.isEmpty
    }
    
    private func resetTracking() {
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    @IBAction func redoAction(_ sender: UIBarButtonItem) {
        
        self.resetTracking()
    }
}

