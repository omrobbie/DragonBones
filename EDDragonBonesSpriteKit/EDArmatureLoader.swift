//
//  ArmatureLoader.swift
//  DragonBonesSpriteKit
//
//  Created by Salo on 16/6/24.
//  Copyright © 2016年 eitdesign. All rights reserved.
//

import SpriteKit
import SwiftyJSON

open class EDArmatureLoader {
    
    fileprivate var armatureConfig: [String: EDSkeleton.Armature] = [:]
    
    public init(filePath: String) {
        
        let JSONData = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        let json = try! JSON(data: JSONData)
        
        let skeleton = EDSkeleton(json: json)
        
        for armature in skeleton.armature {
            armatureConfig[armature.name] = armature
        }
    }
    
    open func loadNode(named name: String) -> EDArmatureNode {
        return self.loadRequireArmature(name)
    }
    
    fileprivate func loadRequireArmature(_ name: String) -> EDArmatureNode {
        return EDArmatureNode(armature: armatureConfig[name]!, loader: self)
    }

}

class EDSlotNode: SKNode {
    
    init(slot: EDSkeleton.Armature.Slot) {
        super.init()
        
        self.name = slot.name
        self.zPosition = CGFloat(slot.z) / 100.0
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class EDDisplayNode: SKSpriteNode {
    
    init(transform: EDSkeleton.Armature.Transform, texture: SKTexture) {
        super.init(texture: texture, color: UIColor.clear, size: texture.size())
        self.transform = transform
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

open class EDArmatureNode: SKNode {
    
    fileprivate var boneAnimationDictionary: [String: [String: SKAction]] = [:]
    fileprivate var slotAnimationDictionary: [String: [String: SKAction]] = [:]
    fileprivate var frameAnimationDictionary: [String: SKAction] = [:]
    fileprivate var boneDictionary: [String: SKNode] = [:]
    fileprivate var slotDictionary: [String: EDSlotNode] = [:]
    fileprivate var childArmatureNodes: [EDArmatureNode] = []
    
    init(armature: EDSkeleton.Armature, loader: EDArmatureLoader, transform: EDSkeleton.Armature.Transform? = nil) {
        
        super.init()
        
        if let transform = transform {
            self.transform = transform
        }
        
        self.name = armature.name
        
        for bone in armature.bone {
            let boneNode = SKNode(bone: bone)
            
            let parentNode: SKNode
            if let parentName = bone.parent {
                parentNode = boneDictionary[parentName]!
            } else {
                parentNode = self
            }
            parentNode.addChild(boneNode)
            boneDictionary[bone.name] = boneNode
        }
        
        for slot in armature.slot {
            let slotNode = EDSlotNode(slot: slot)
            let parentNode = boneDictionary[slot.parent]!
            parentNode.addChild(slotNode)
            slotDictionary[slot.name] = slotNode
        }
        
        for skin in armature.skin {
            for slot in skin.slot {
                let node = slotDictionary[slot.name]!
                for i in 0 ..< slot.display.count {
                    let display = slot.display[i]
                    switch display.type {
                    case .image:
                        let components = display.name.components(separatedBy: "/")
                        let atlasName = components[0]
                        let textureName = components[1].addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
                        let atlas = SKTextureAtlas(named: atlasName)
                        let texture = atlas.textureNamed(textureName)
                        
                        let spriteNode = EDDisplayNode(transform: display.transform, texture: texture)
                        node.addChild(spriteNode)
                    case .armature:
                        let armatureNode = loader.loadRequireArmature(display.name)
                        armatureNode.transform = display.transform
                        node.addChild(armatureNode)
                        
                        self.childArmatureNodes.append(armatureNode)
                    }
                }
            }
        }
        
        for animation in armature.animation {
            boneAnimationDictionary[animation.name] = [:]
            slotAnimationDictionary[animation.name] = [:]
            
            for bone in animation.bone {
                let action = SKAction.boneFrameAction(bone.frame, duration: animation.duration)
                boneAnimationDictionary[animation.name]![bone.name] = action
            }
            
            for slot in animation.slot {
                let action = SKAction.slotFrameAction(slot.frame, duration: animation.duration)
                slotAnimationDictionary[animation.name]![slot.name] = action
            }
            
            var frameActionArray: [SKAction] = []
            for frame in animation.frame {
                frameActionArray.append(SKAction.wait(forDuration: frame.duration))
                if let event = frame.event {
                    frameActionArray.append(SKAction.playSoundFileNamed(event, waitForCompletion: false))
                }
            }
            
            frameAnimationDictionary[animation.name] = SKAction.sequence(frameActionArray)
        }
        
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func stopAllAction() {
        
        for (_, node) in self.boneDictionary {
            node.removeAllActions()
        }
    
        for (_, node) in self.slotDictionary {
            node.removeAllActions()
        }
        
        self.removeAllActions()
        
        for armatureNode in self.childArmatureNodes {
            armatureNode.stopAllAction()
        }
        
    }
    
    open func repeatAnimation(_ name: String) {
        
        self.stopAllAction()
        
        if let animation = self.boneAnimationDictionary[name] {
            for (_, node) in self.boneDictionary {
                if let action = animation[node.name!] {
                    node.run(SKAction.repeatForever(action))
                }
            }
        }
        
        if let animation = self.slotAnimationDictionary[name] {
            for (_, node) in self.slotDictionary {
                if let action = animation[node.name!] {
                    node.run(SKAction.repeatForever(action))
                }
            }
        }
        
        if let action = self.frameAnimationDictionary[name] {
            self.run(SKAction.repeatForever(action))
        }
        
        for armatureNode in self.childArmatureNodes {
            armatureNode.repeatAnimation(name)
        }
    }
    
    open func playAnimation(_ name: String, completion: (() -> Void)?) {
        
        self.stopAllAction()
        
        if let animation = self.boneAnimationDictionary[name] {
            for (_, node) in self.boneDictionary {
                if let action = animation[node.name!] {
                    node.run(action)
                }
            }
        }
        
        if let animation = self.slotAnimationDictionary[name] {
            for (_, node) in self.slotDictionary {
                if let action = animation[node.name!] {
                    node.run(action)
                }
            }
        }
        
        if let eventAction = self.frameAnimationDictionary[name] {
            if let completion = completion {
                self.run(eventAction, completion: completion)
            } else {
                self.run(eventAction)
            }
        }
        
        for armatureNode in self.childArmatureNodes {
            armatureNode.playAnimation(name, completion: nil)
        }
    }
    
}

extension SKNode {
    
    var transform: EDSkeleton.Armature.Transform {
        set {
            self.xScale = CGFloat(newValue.scX)
            self.yScale = CGFloat(newValue.scY)
            self.position = newValue.position
            self.zRotation = newValue.zRotation
        }
        
        get {
            return EDSkeleton.Armature.Transform(scX: self.xScale,
                                                 scY: self.yScale,
                                                 zRotation: self.zRotation,
                                                 position: self.position)
        }
    }
    
    convenience init(bone: EDSkeleton.Armature.Bone) {
        self.init()
        
        self.name = bone.name
        self.transform = bone.transform
    }
    
}

extension SKAction {
    
    class func boneFrameAction(_ frame: [EDSkeleton.Armature.Animation.Bone.Frame], duration: TimeInterval) -> SKAction {
        var sequenceActionArray: [SKAction] = []
        for theFrame in frame {
            let frameDuration = theFrame.duration
            if theFrame.tweenEasing {
                let positionAction = SKAction.move(to: theFrame.transform.position, duration: frameDuration)
                let scaleXAction = SKAction.scaleX(to: theFrame.transform.scX, duration: frameDuration)
                let scaleYAction = SKAction.scaleY(to: theFrame.transform.scY, duration: frameDuration)
                let zRotationAction = SKAction.rotate(toAngle: theFrame.transform.zRotation, duration: frameDuration)
                let groupAction = SKAction.group([positionAction, scaleXAction, scaleYAction, zRotationAction])
                sequenceActionArray.append(groupAction)
            } else {
                let sequenceAction = SKAction.sequence(
                    [
                    SKAction.wait(forDuration: frameDuration),
                    SKAction.customAction(withDuration: 0, actionBlock: {
                        (node: SKNode, elapsedTime: CGFloat) in
                        node.transform = theFrame.transform
                    })
                    ])
                sequenceActionArray.append(sequenceAction)
            }
            
        }
        let sequenceAction = SKAction.sequence(sequenceActionArray)
        sequenceAction.duration = duration
        return sequenceAction
    }
    
    class func slotFrameAction(_ frame: [EDSkeleton.Armature.Animation.Slot.Frame], duration: TimeInterval) -> SKAction {
        var sequenceActionArray: [SKAction] = []
        
        for theFrame in frame {
            let frameAction: SKAction
            
            let duration = theFrame.duration
            if theFrame.tweenEasing {
                frameAction = SKAction.fadeAlpha(to: theFrame.color.alpha, duration: duration)
            } else {
                frameAction = SKAction.wait(forDuration: duration)
            }
            
            let displayAction = SKAction.customAction(withDuration: 0, actionBlock: {
                (node: SKNode, elapsedTime: CGFloat) in
                for idx in 0 ..< node.children.count {
                    node.children[idx].isHidden = (idx != theFrame.displayIndex)
                }
            })
            let subSeq = SKAction.sequence([frameAction, displayAction])

            sequenceActionArray.append(subSeq)
        }
        let sequenceAction = SKAction.sequence(sequenceActionArray)
        sequenceAction.duration = duration
        return sequenceAction
    }
    
}

