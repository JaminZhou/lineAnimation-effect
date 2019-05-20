//
//  EffectView.swift
//  lineAnimation-effect
//
//  Created by JaminZhou on 2017/5/14.
//  Copyright © 2017年 Hangzhou Tomorning Technology Co., Ltd. All rights reserved.
//

import UIKit

class EffectView: UIView {
    
    let KDuration = 0.8
    let KDelay = 1.2
    var pathView: UIView!
    var border: UIView!
    var index = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        pathView = UIView(frame: bounds)
        addSubview(pathView)
        backgroundColor = UIColor.clear
    }
    
    func showAnimation() {
        showSVGAnimation()
    }
    
    func showSVGAnimation() {
        let svgPath = Bundle.main.path(forResource: "\(index%9+1)", ofType: "svg")
        do {
            let svgStr = try String(contentsOfFile: svgPath!, encoding: .utf8)
            let svgData = svgStr.data(using: .utf8)
            let hpple = TFHpple(htmlData: svgData)!
            parseHpple(hpple)
        } catch {}
        index += 1
        borderAnimation()
        pathViewAnimation()
    }
    
    func parseHpple(_ hpple: TFHpple) {
        parseSVG(hpple, command: SVGCommandLine)
        parseSVG(hpple, command: SVGCommandPath)
        parseSVG(hpple, command: SVGCommandCircle)
        parseSVG(hpple, command: SVGCommandEllipse)
        parseSVG(hpple, command: SVGCommandPolyline)
    }
    
    func parseSVG(_ hpple: TFHpple, command: SVGCommandType) {
        var query = ""
        switch command {
        case SVGCommandLine:
            query = "//line"
        case SVGCommandPath:
            query = "//path"
        case SVGCommandCircle:
            query = "//circle"
        case SVGCommandEllipse:
            query = "//ellipse"
        case SVGCommandPolyline:
            query = "//polyline"
        default:
            break
        }
        
        let elements = hpple.search(withXPathQuery: query) as! [TFHppleElement]
        for element in elements {
            let layer = SVGParse.layer(fromSVGPath: element.attributes, command: command)!
            pathView.layer.addSublayer(layer)
            pathLayerAnimation(layer)
        }
    }
    
    func pathLayerAnimation(_ layer: CALayer) {
        let stroke0 = POPBasicAnimation(propertyNamed: kPOPShapeLayerStrokeEnd)!
        stroke0.duration = KDuration
        stroke0.fromValue = 0.0
        stroke0.toValue = 1.0
        
        let stroke1 = POPBasicAnimation(propertyNamed: kPOPShapeLayerStrokeEnd)!
        stroke1.duration = KDuration
        stroke1.beginTime = CACurrentMediaTime() + KDelay
        stroke1.fromValue = 1.0
        stroke1.toValue = 0.0
        
        layer.pop_add(stroke0, forKey: "stroke0")
        layer.pop_add(stroke1, forKey: "stroke1")
    }
    
    func borderAnimation() {
        border = UIView(frame: bounds)
        border.backgroundColor = UIColor.clear
        border.layer.borderColor = UIColor.white.cgColor
        border.layer.borderWidth = 1.5
        border.layer.cornerRadius = border.bounds.width/2
        border.layer.masksToBounds = true
        border.layer.opacity = 0.0
        self.addSubview(border)
        
        let duration = 2*KDuration+KDelay/2
        let scale = POPBasicAnimation.easeInEaseOut()!
        scale.property = POPAnimatableProperty.property(withName: kPOPLayerScaleXY) as? POPAnimatableProperty
        scale.fromValue = CGPoint(x: 0.8, y: 0.8)
        scale.toValue = CGPoint(x: 1.0, y: 1.0)
        scale.duration = duration
         
        let opacity0 = POPBasicAnimation(propertyNamed: kPOPLayerOpacity)!
        opacity0.duration = duration/2
        opacity0.fromValue = 0.0
        opacity0.toValue = 0.6
        opacity0.completionBlock = {anim, finished in
            let opacity1 = POPBasicAnimation(propertyNamed: kPOPLayerOpacity)!
            opacity1.duration = duration/2
            opacity1.toValue = 0.0
            self.border.layer.pop_add(opacity1, forKey: "opacity1")
        }
        
        border.layer.pop_add(scale, forKey: "scale")
        border.layer.pop_add(opacity0, forKey: "opacity0")
    }
    
    func pathViewAnimation() {
        let opacity0 = POPBasicAnimation(propertyNamed: kPOPLayerOpacity)!
        opacity0.duration = KDuration;
        opacity0.fromValue = 0.0
        opacity0.toValue  = 1.0
        
        let opacity1 = POPBasicAnimation(propertyNamed: kPOPLayerOpacity)!
        opacity1.duration = KDuration;
        opacity1.beginTime = CACurrentMediaTime() + KDelay
        opacity1.fromValue = 1.0
        opacity1.toValue  = 0.0
        opacity1.completionBlock = {anim, finished in
            self.clear()
            self.showSVGAnimation()
        }
        
        pathView.layer.pop_add(opacity0, forKey: "opacity0")
        pathView.layer.pop_add(opacity1, forKey: "opacity1")
    }
    
    func clear() {
        pathView.layer.pop_removeAllAnimations()
        border.layer.pop_removeAllAnimations()
        pathView.removeAllSublayer()
        border.removeFromSuperview()
    }
    
}
