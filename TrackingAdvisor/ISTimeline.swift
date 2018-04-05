//
//  ISTimeline.swift
//  ISTimeline
//
//  Created by Max Holzleitner on 07.05.16 and modified by Benjamin Baron.
//  Copyright © 2016 instant:solutions. All rights reserved.
//

import UIKit

struct TimelineBlock {
    var iconView: MoveableView? = nil
    var lineLayer:MovableLineLayer? = nil
    var pointLayer: MoveableLayer? = nil
    var bubbleView: MoveableView? = nil
    var descriptionView: MoveableView? = nil
    var descriptionSuppView: MoveableView? = nil
    var feedbackView: MoveableView? = nil
    
    func getLayers() -> [Moveable] {
        var res: [Moveable] = []
        if let layer = iconView { res.append(layer) }
        if let layer = lineLayer { res.append(layer) }
        if let layer = pointLayer { res.append(layer) }
        if let layer = bubbleView { res.append(layer) }
        if let layer = descriptionView { res.append(layer) }
        if let layer = descriptionSuppView { res.append(layer) }
        if let layer = feedbackView { res.append(layer) }
        return res
    }
    
    func hideAllLayers() {
        iconView?.hide();lineLayer?.hide();pointLayer?.hide();bubbleView?.hide()
        descriptionView?.hide();descriptionSuppView?.hide();feedbackView?.hide()
    }
    
    func decrementPosition() {
        iconView?.position -= 1
        lineLayer?.position -= 1
        pointLayer?.position -= 1
        bubbleView?.position -= 1
        descriptionView?.position -= 1
        descriptionSuppView?.position -= 1
        feedbackView?.position -= 1
    }
    
    func decrementMaxPosition() {
        iconView?.maxPosition -= 1
        lineLayer?.maxPosition -= 1
        pointLayer?.maxPosition -= 1
        bubbleView?.maxPosition -= 1
        descriptionView?.maxPosition -= 1
        descriptionSuppView?.maxPosition -= 1
        feedbackView?.maxPosition -= 1
    }
    
    func height() -> CGFloat {
        var height: CGFloat = 27.0
        if let h = bubbleView?.view?.frame.height { height += h }
        if let h = descriptionView?.view?.frame.height { height += h }
        if let h = descriptionSuppView?.view?.frame.height { height += h }
        if let h = feedbackView?.view?.frame.height { height += h }
        return height
    }
}

protocol Moveable {
    func hide()
    func show()
    func move(to: CGPoint, with delay: CFTimeInterval, force: Bool)
    func moveDown(by value: CGFloat, with delay:CFTimeInterval)
    func isLast() -> Bool
    func isLine() -> Bool
    func getPosition() -> Int
}

class MoveableLayer : Moveable {
    var layer: CALayer?
    var position = -1
    var maxPosition = -1
    
    init(layer:CALayer? = nil, position:Int = -1, maxPosition: Int = -1) {
        self.layer = layer
        self.position = position
        self.maxPosition = maxPosition
    }
    
    func hide() {
        guard let layer = layer else { return }
        layer.opacity = 0
    }
    
    func show() {
        guard let layer = layer else { return }
        layer.opacity = 1
    }
    
    func move(to: CGPoint, with delay: CFTimeInterval, force: Bool = false) {
        guard let layer = layer else { return }
        if force || (!force && position > 0) {
            let animation = CABasicAnimation(keyPath: "position")
            animation.fromValue = layer.position
            animation.toValue = to
            animation.duration = delay
            layer.position = to
            layer.add(animation, forKey: "animatePosition")
        }
    }
    
    func moveDown(by value: CGFloat, with delay: CFTimeInterval) {
        guard let layer = layer else { return }
        var position = CGPoint()
        position.x = layer.position.x
        position.y = layer.position.y + value
        move(to: position, with: delay, force: true)
    }
    
    func isLast() -> Bool {
        return self.position == self.maxPosition
    }
    
    func isLine() -> Bool {
        return false
    }
    
    func getPosition() -> Int {
        return position
    }
    
}

class MovableLineLayer: MoveableLayer {
    var line: CAShapeLayer? { didSet {
            self.layer = line
        }
    }
    var topCap: CAShapeLayer?
    var bottomCap: CAShapeLayer?
    var intermediateOffset: CGFloat = 0.0
    var lineOffset: CGFloat = 0.0
    
    init(line:CAShapeLayer? = nil, position:Int = -1, maxPosition: Int = -1, intermediateOffset: CGFloat = 0.0) {
        self.line = line
        self.intermediateOffset = intermediateOffset
        super.init(layer: line, position: position, maxPosition: maxPosition)
    }
    
    override func moveDown(by value: CGFloat, with delay: CFTimeInterval) {
        guard let line = line else { return }
        var newPosition = CGPoint()
        newPosition.x = line.position.x
        newPosition.y = line.position.y + value
        
        if isLast() {
            line.strokeStart = value < 0 ? lineOffset : 0.0
            if let topCap = topCap {
                topCap.position.y += value < 0 ? intermediateOffset : -1*intermediateOffset
            }
        }
        
        move(to: newPosition, with: delay, force: true)
    }
    
    func moveBottomDown(by value: CGFloat, with delay: CFTimeInterval) {
        guard let line = line else { return }
        var position = CGPoint()
        position.x = line.position.x
        position.y = line.position.y + value
        
        if isLast() {
            let increment = self.position == 0 ? 0.0 : value / CGFloat(self.position)
            position.y += increment
            line.strokeStart = value < 0 ? lineOffset : 0.0
            if let topCap = topCap {
                topCap.position.y += value < 0 ? intermediateOffset : -1*intermediateOffset
            }
        }
        
        move(to: position, with: delay, force: true)
    }
    
    func moveUp(by value: CGFloat, with delay: CFTimeInterval) {
        guard let line = line else { return }
        
        var position = CGPoint()
        position.x = line.position.x
        position.y = line.position.y + value
        
        move(to: position, with: delay, force: true)
    }
    
    func movePath(by value: CGFloat, with delay: CFTimeInterval) {
        guard let line = line, let path = line.path else { return }
        
        let boundingBox = path.boundingBox
        let offset:CGFloat = value / boundingBox.height
        
        let from = line.strokeEnd
        let to = from + offset
        
        line.strokeEnd += offset
        
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = delay
        line.add(animation, forKey: "animateStrokeEnd")
        
        if let cap = bottomCap {
            let animation = CABasicAnimation(keyPath: "position")
            animation.fromValue = cap.position.y
            animation.toValue = cap.position.y + value
            animation.duration = delay
            cap.add(animation, forKey: "animateCapPosition")
            cap.position.y += value
        }
    }
    
    override func isLine() -> Bool {
        return true
    }
}

class MoveableView : Moveable {
    let view:UIView?
    var position = -1
    var maxPosition = -1
    
    init(view:UIView? = nil, position:Int = -1, maxPosition: Int = -1) {
        self.view = view
        self.position = position
        self.maxPosition = maxPosition
    }
   
    func hide() {
        guard let view = view else { return }
        view.alpha = 0
    }
    
    func show() {
        guard let view = view else { return }
        view.alpha = 1
    }
    
    func move(to: CGPoint, with delay: CFTimeInterval, force: Bool = false) {
        guard let view = view else { return }
        if force || (!force && self.position > 0) {
            UIView.animate(withDuration: delay) {
                view.center = to
            }
        }
    }
    
    func moveDown(by value: CGFloat, with delay:CFTimeInterval) {
        guard let view = view else { return }
        var position = CGPoint()
        position.x = view.center.x
        position.y = view.center.y + value
        move(to: position, with: delay, force: true)
    }
    
    func isLast() -> Bool {
        return self.position == self.maxPosition
    }
    
    func isLine() -> Bool {
        return false
    }
    
    func getPosition() -> Int {
        return position
    }
}


open class ISTimeline: UIScrollView {
    
    fileprivate static let gap:CGFloat = 15.0
    
    open var pointDiameter:CGFloat = 12.0 {
        didSet {
            if (pointDiameter < 0.0) {
                pointDiameter = 0.0
            } else if (pointDiameter > 100.0) {
                pointDiameter = 100.0
            }
        }
    }
    
    open var lineWidth:CGFloat = 16.0 {
        didSet {
            if (lineWidth < 0.0) {
                lineWidth = 0.0
            } else if(lineWidth > 20.0) {
                lineWidth = 20.0
            }
        }
    }
    
    open var bubbleRadius:CGFloat = 2.0 {
        didSet {
            if (bubbleRadius < 0.0) {
                bubbleRadius = 0.0
            } else if (bubbleRadius > 6.0) {
                bubbleRadius = 6.0
            }
        }
    }
    
    open var iconDiameter: CGFloat = 30.0 {
        didSet {
            if iconDiameter < 0.0 { iconDiameter = 0.0 }
            else if iconDiameter > 100.0 { iconDiameter = 100.0 }
        }
    }
    
    var layers:[TimelineBlock] = []
    var addButtons:[Moveable] = []
    var addButtonViews:[UIView] = []
    
    private var _points:[ISPoint] = [] // emulate a stored property
    
    open var points:[ISPoint] = [] {
        didSet {
            _points.removeAll()
            _points = points
            
            reloadTimeline()
        }
    }
    
    open var bubbleArrows:Bool = false
    open var timelineTitle:String! { didSet {
            timelineTitleLabel.text = timelineTitle
        }
    }
    open var timelineSubtitle:String! { didSet {
            timelineSubtitleLabel.text = timelineSubtitle
        }
    }
    open var timelineUpdateTouchAction: (()->Void)?
    open var timelimeAddPlaceFirstTouchAction: ((_ pt1:ISPoint?, _ pt2:ISPoint?)->Void)?
    open var timelimeAddPlaceLastTouchAction: ((_ pt1:ISPoint?, _ pt2:ISPoint?)->Void)?
    open var timelineValidatedPlaceTouchAction: ((_ pt:ISPoint?)->Void)?
    open var timelineRemovedPlaceTouchAction: ((_ pt:ISPoint?)->Void)?
    
    fileprivate let timelineTitleOffset:CGFloat = 160.0
    fileprivate var timelineTitleLabel: UILabel!
    fileprivate var timelineSubtitleLabel: UILabel!
    fileprivate var timelineEditButton: UIButton!
    fileprivate var timelineUpdateButton: UIButton!
    fileprivate let screenSize:CGRect = UIScreen.main.bounds
    fileprivate var isEditing = false { didSet {
            if isEditing {
                timelineEditButton.setTitle("Done", for: .normal)
                timelineEditButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
            } else {
                if timelineEditButton != nil {
                  timelineEditButton.setTitle("Add places", for: .normal)
                  timelineEditButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
                }
            }
        }
    }
    
    fileprivate var isAnimating = false
    
    fileprivate var sections:[(point:CGPoint, bubbleRect:CGRect, descriptionRect:CGRect?, descriptionSuppRect:CGRect?, titleLabel:UILabel, descriptionLabel:UILabel?, descriptionSuppView:UIView?, pointColor:CGColor, lineColor:CGColor, fill:Bool, icon:UIImage, iconBg:CGColor, iconCenter:CGPoint, feedbackRect:CGRect?)] = []
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    fileprivate func initialize() {
        self.clipsToBounds = true
        self.showsVerticalScrollIndicator = false
        buildTimelineTitleLabel()
        buildTimelineSubtitleLabel()
    }
    
    @objc fileprivate func updateTimeline() {
        timelineUpdateTouchAction?()
    }
    
    @objc fileprivate func editTimeline() {
        if isAnimating { return }
        isAnimating = true
        
        if isEditing {
            let duration = 0.5
            
            for i in 0..<self.addButtons.count {
                let layer = self.addButtons[i]
                layer.hide()
            }

            CATransaction.begin()
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
            
            CATransaction.setCompletionBlock { [weak self] in
                self?.isAnimating = false
                self?.isEditing = false
            }
            
            for i in 0..<self.layers.count {
                for layer in self.layers[i].getLayers() {
                    if layer.isLast(), let lineLayer = layer as? MovableLineLayer {
                        lineLayer.moveDown(by: -1.0 * CGFloat(i+2) * 50, with: duration)
                    } else {
                        layer.moveDown(by: -1.0 *  CGFloat(i+1) * 50, with: duration)
                    }
                }
            }
            
            CATransaction.commit()
            
            self.contentSize = CGSize(width: self.contentSize.width, height: self.contentSize.height - CGFloat(self.layers.count+1)*50)
            
        } else {
            reloadTimeline() // reset the view
            
            let duration = 0.5
            CATransaction.begin()
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
            
            CATransaction.setCompletionBlock { [weak self] in
                guard let strongSelf = self else { return  }
                for i in 0..<strongSelf.addButtons.count {
                    let layer = strongSelf.addButtons[i]
                    layer.show()
                }
                
                strongSelf.isAnimating = false
                strongSelf.isEditing = true
            }
            
            for i in 0..<self.layers.count {
                for layer in self.layers[i].getLayers() {
                    if layer.isLast() && layer.isLine() {
                        layer.moveDown(by: CGFloat(i+2) * 50, with: duration)
                    } else {
                        layer.moveDown(by: CGFloat(i+1) * 50, with: duration)
                    }
                }
            }
            
            CATransaction.commit()
            
            self.contentSize = CGSize(width: self.contentSize.width, height: self.contentSize.height + CGFloat(self.layers.count+1)*50)
        }
    }
    
    func reloadTimeline() {
        self.layer.sublayers?.forEach({ (layer:CALayer) in
            if layer.isKind(of: CAShapeLayer.self) {
                layer.removeFromSuperlayer()
            }
        })
        self.subviews.forEach { (view:UIView) in
            view.removeFromSuperview()
        }
        
        self.contentSize = CGSize.zero
        
        sections.removeAll()
        addButtonViews.removeAll()
        addButtons.removeAll()
        layers.removeAll()
        isEditing = false
        isAnimating = false
        
        buildSections()
        
        layer.setNeedsDisplay()
        layer.displayIfNeeded()
    }
    
    override open func draw(_ rect: CGRect) {
        let ctx:CGContext = UIGraphicsGetCurrentContext()!
        ctx.saveGState()
        
        // Place the timeline update button
        timelineUpdateButton = UIButton(type: UIButtonType.system)
        timelineUpdateButton.contentHorizontalAlignment = .left
        timelineUpdateButton.setTitle("Update", for: .normal)
        timelineUpdateButton.addTarget(self, action: #selector(updateTimeline), for: .touchUpInside)
        timelineUpdateButton.frame = CGRect(x: 1.0, y: 29.0, width: rect.width-76.0, height: 40)
        self.addSubview(timelineUpdateButton)
        
        // Place the timeline title label
        timelineTitleLabel.frame = CGRect(x: 1.0, y: 69.0, width: rect.width-1.0, height: 40)
        timelineSubtitleLabel.frame = CGRect(x: 1.0, y: 115.0, width: rect.width-1.0, height: 20)
        self.addSubview(timelineTitleLabel)
        self.addSubview(timelineSubtitleLabel)
        
        // Place the timeline edit button
        timelineEditButton = UIButton(type: UIButtonType.system)
        timelineEditButton.frame.size = CGSize(width: 100, height: 50)
        timelineEditButton.contentHorizontalAlignment = .right
        timelineEditButton.frame.origin = CGPoint(x: screenSize.width - (timelineEditButton.frame.width + 40), y: -10)
        timelineEditButton.setTitle("Add places", for: .normal)
        timelineEditButton.addTarget(self, action: #selector(ISTimeline.editTimeline), for: .touchUpInside)
        self.addSubview(timelineEditButton)
        
        if sections.count == 0 { return }
        
        // add the first add button
        let addIconPosition = CGPoint(x: sections[0].point.x - lineWidth/2,
                                      y: sections[0].point.y - pointDiameter)
        
        let addIconView = drawIcon(addIconPosition, fill: Constants.colors.primaryLight.cgColor, image: UIImage(named: "plus")!)
        addIconView.alpha = 0
        addButtons.append(MoveableView(view: addIconView, position: -1, maxPosition: sections.count - 2))
        self.addSubview(addIconView)
        
        // Add text (button)
        let addTextRect = CGRect(
            x: addIconPosition.x + 35,
            y: addIconPosition.y + 2,
            width: 100,
            height: 25)
        let addTextLabel = buildAddLabel(text: "Add a place")
        
        let addTextLayer = drawDescription(addTextRect, textColor: Constants.colors.black, descriptionLabel: addTextLabel!)
        addTextLayer.alpha = 0
        addButtons.append(MoveableView(view: addTextLayer, position: -1, maxPosition: sections.count - 2))
        addButtonViews.append(addTextLayer)
        self.addSubview(addTextLayer)
        
        for i in 0 ..< sections.count {
            layers.append(TimelineBlock())
            if (i < sections.count - 1) {
                var start = sections[i].point
                start.x += pointDiameter / 2
                start.y += pointDiameter / 2
                
                var end = sections[i + 1].point
                end.x = start.x
                end.y = sections[sections.count-1].point.y + pointDiameter / 2
                
                let cap = (i == sections.count - 2) ? 2 : 1
                let offset: CGFloat = (i == sections.count - 2) ? 50.0 : 0.0

                let moveableLineLayer = MovableLineLayer(line: nil, position: i, maxPosition: sections.count - 2, intermediateOffset: offset)
                let lineLayer = drawLine(start, end: end, color: sections[i].lineColor,
                                         cap: cap, offset: offset, layer: moveableLineLayer)
                
                self.layer.addSublayer(lineLayer)
                layers[i].lineLayer = moveableLineLayer
                
                // Add button (with opacity = 0)
                let addIconPosition = CGPoint(x: sections[i].point.x - lineWidth/2,
                                              y: 50.0 + sections[i+1].point.y + CGFloat(i) * 50 - 10)
                
                let addIconView = drawIcon(addIconPosition, fill: Constants.colors.primaryLight.cgColor, image: UIImage(named: "plus")!)
                addIconView.alpha = 0
                addButtons.append(MoveableView(view: addIconView, position: i, maxPosition: sections.count - 2))
                self.addSubview(addIconView)
                
                // Add text (button)
                let addTextRect = CGRect(
                    x: addIconPosition.x + 35,
                    y: addIconPosition.y + 2,
                    width: 100,
                    height: 25)
                let addTextLabel = buildAddLabel(text: "Add a place")
                
                let addTextLayer = drawDescription(addTextRect, textColor: Constants.colors.black, descriptionLabel: addTextLabel!)
                addTextLayer.alpha = 0
                addButtons.append(MoveableView(view: addTextLayer, position: i, maxPosition: sections.count - 2))
                addButtonViews.append(addTextLayer)
                self.addSubview(addTextLayer)
                
            } else if i == sections.count - 1 {
                
                // get the maxY position
                var positionY = sections[i].bubbleRect.maxY
                if let rect = sections[i].descriptionRect, positionY < rect.maxY {
                    positionY = rect.maxY
                }
                if let rect = sections[i].descriptionSuppRect, positionY < rect.maxY {
                    positionY = rect.maxY
                }
                if let rect = sections[i].feedbackRect, positionY < rect.maxY {
                    positionY = rect.maxY
                }
                let addIconPosition = CGPoint(x: sections[i].point.x - lineWidth/2,
                                              y: 50.0 + positionY + CGFloat(i) * 50.0 + 30.0)
                
                let addIconView = drawIcon(addIconPosition, fill: Constants.colors.primaryLight.cgColor, image: UIImage(named: "plus")!)
                addIconView.alpha = 0
                addButtons.append(MoveableView(view: addIconView, position: i, maxPosition: sections.count - 2))
                self.addSubview(addIconView)
                
                // Add text (button)
                let addTextRect = CGRect(
                    x: addIconPosition.x + 35,
                    y: addIconPosition.y + 2,
                    width: 100,
                    height: 25)
                let addTextLabel = buildAddLabel(text: "Add a place")
                
                let addTextLayer = drawDescription(addTextRect, textColor: Constants.colors.black, descriptionLabel: addTextLabel!)
                addTextLayer.alpha = 0
                addButtons.append(MoveableView(view: addTextLayer, position: i, maxPosition: sections.count - 2))
                addButtonViews.append(addTextLayer)
                self.addSubview(addTextLayer)
            }
            
            let iconView = drawIcon(sections[i].iconCenter, fill: sections[i].iconBg, image: sections[i].icon, scale: 0.65)
            self.addSubview(iconView)
            layers[i].iconView = MoveableView(view: iconView, position: i, maxPosition: sections.count - 1)
            
            let pointLayer = drawPoint(sections[i].point, color: sections[i].pointColor, fill: sections[i].fill)
            self.layer.addSublayer(pointLayer)
            layers[i].pointLayer = MoveableLayer(layer: pointLayer, position: i, maxPosition: sections.count - 1)
            
            let bubbleLayer = drawBubble(sections[i].bubbleRect, backgroundColor: Constants.colors.primaryLight, textColor: Constants.colors.titleColor, titleLabel: sections[i].titleLabel)
            self.addSubview(bubbleLayer)
            layers[i].bubbleView = MoveableView(view: bubbleLayer, position: i, maxPosition: sections.count - 1)
            
            let descriptionLabel = sections[i].descriptionLabel
            if (descriptionLabel != nil) {
                let descriptionLayer = drawDescription(sections[i].descriptionRect!, textColor: Constants.colors.descriptionColor, descriptionLabel: sections[i].descriptionLabel!)
                self.addSubview(descriptionLayer)
                layers[i].descriptionView = MoveableView(view: descriptionLayer, position: i, maxPosition: sections.count - 1)
            }
            
            let descriptionSuppView = sections[i].descriptionSuppView
            if (descriptionSuppView != nil) {
                let descriptionSuppLayer = drawDescriptionSupp(sections[i].descriptionSuppRect!, descriptionSupp: sections[i].descriptionSuppView!)
                self.addSubview(descriptionSuppLayer)
                layers[i].descriptionSuppView = MoveableView(view: descriptionSuppLayer, position: i, maxPosition: sections.count - 1)
            }
            
            let feedbackRect = sections[i].feedbackRect
            if feedbackRect != nil {
                let feedbackView = buildFeedbackButtons(feedbackRect!, i)
                self.addSubview(feedbackView)
                layers[i].feedbackView = MoveableView(view: feedbackView, position: i, maxPosition: sections.count - 1)
            }
        }
        
        ctx.restoreGState()
    }
    
    fileprivate func buildSections() {
        self.setNeedsLayout()
        self.layoutIfNeeded()
        
        var y:CGFloat = self.bounds.origin.y + self.contentInset.top + timelineTitleOffset
        for i in 0 ..< _points.count {
            let titleLabel = buildTitleLabel(i)
            let descriptionLabel = buildDescriptionLabel(i)
            let descriptionSuppView = _points[i].descriptionSupp
            
            let titleHeight = titleLabel.intrinsicContentSize.height
            var height:CGFloat = titleHeight
            if descriptionLabel != nil {
                height += descriptionLabel!.intrinsicContentSize.height
            }
            if descriptionSuppView != nil {
                height += descriptionSuppView!.frame.height
            }
            if _points[i].showFeedback {
                height += 60.0 // feedbackRect
            }
            height += 10.0 // margin
            
            let iconCenter = CGPoint(
                x: self.bounds.origin.x + self.contentInset.left,
                y: y + (pointDiameter - iconDiameter) / 2 + ISTimeline.gap)
            
            let point = CGPoint(
                x: self.bounds.origin.x + self.contentInset.left + iconDiameter + lineWidth,
                y: y + ISTimeline.gap)
            
            let maxTitleWidth = calcWidth()
            var titleWidth = titleLabel.intrinsicContentSize.width + 20
            if (titleWidth > maxTitleWidth) {
                titleWidth = maxTitleWidth
            }
            
            let offset:CGFloat = bubbleArrows ? 13 : 5
            let bubbleRect = CGRect(
                x: point.x + pointDiameter + lineWidth / 2 + offset,
                y: y + pointDiameter / 2,
                width: titleWidth,
                height: titleHeight + ISTimeline.gap / 2)
            
            var descriptionRect:CGRect?
            if descriptionLabel != nil {
                descriptionRect = CGRect(
                    x: bubbleRect.origin.x,
                    y: bubbleRect.origin.y + bubbleRect.height,
                    width: calcWidth(),
                    height: descriptionLabel!.intrinsicContentSize.height)
            }
            
            var rect = descriptionRect != nil ? descriptionRect! : bubbleRect
            
            var descriptionSuppRect:CGRect?
            if descriptionSuppView != nil {
                descriptionSuppRect = CGRect(
                    x: rect.origin.x,
                    y: rect.origin.y + rect.height + 10,
                    width: calcWidth(),
                    height: descriptionSuppView!.frame.height)
            }
                        
            rect = descriptionSuppRect != nil ? descriptionSuppRect! : rect
            
            var feedbackRect:CGRect?
            if points[i].showFeedback {
                feedbackRect = CGRect(x: rect.origin.x, y: rect.origin.y + rect.height,
                                     width: calcWidth(), height: 70.0)
            }

            sections.append((point, bubbleRect, descriptionRect, descriptionSuppRect, titleLabel, descriptionLabel, descriptionSuppView, points[i].pointColor.cgColor, points[i].lineColor.cgColor, points[i].fill, points[i].icon, points[i].iconBg.cgColor, iconCenter, feedbackRect))
            
            y += height
            y += ISTimeline.gap * 2.2 // section gap
        }
        y += pointDiameter / 2.0 + 100.0
        self.contentSize = CGSize(width: self.bounds.width - (self.contentInset.left + self.contentInset.right), height: y)
    }
    
    fileprivate func buildTimelineTitleLabel() {
        timelineTitleLabel = UILabel()
        timelineTitleLabel.text = timelineTitle
        timelineTitleLabel.font = UIFont.systemFont(ofSize: 36, weight: .heavy)
        timelineTitleLabel.preferredMaxLayoutWidth = calcWidth()
    }
    
    fileprivate func buildTimelineSubtitleLabel() {
        timelineSubtitleLabel = UILabel()
        timelineSubtitleLabel.text = timelineSubtitle
        timelineSubtitleLabel.textColor = Constants.colors.descriptionColor
        timelineSubtitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .light)
        timelineSubtitleLabel.preferredMaxLayoutWidth = calcWidth()
    }
    
    fileprivate func buildTitleLabel(_ index:Int) -> UILabel {
        let titleLabel = UILabel()
        titleLabel.text = points[index].title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20.0)
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 0
        titleLabel.preferredMaxLayoutWidth = calcWidth()
        return titleLabel
    }
    
    fileprivate func buildDescriptionLabel(_ index:Int) -> UILabel? {
        let text = points[index].description
        return buildDescriptionLabel(text: text)
    }
    
    fileprivate func buildFeedbackView(_ rect:CGRect) -> UIView {
        let feedbackView = UIView()
        feedbackView.frame = rect
//        feedbackView.backgroundColor = UIColor.lightGray
        
        let imageView = UIImageView(image: UIImage(named: "chevron-right")!.withRenderingMode(.alwaysTemplate))
        imageView.tintColor = Constants.colors.primaryLight
        imageView.contentMode = .scaleAspectFit
//        imageView.frame = CGRect(x: 0, y: 0, width: 25, height: 25)
        feedbackView.addSubview(imageView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let imageViewTrailingConstraint = NSLayoutConstraint(item: imageView, attribute: .trailing, relatedBy: .equal, toItem: feedbackView, attribute: .trailing, multiplier: 1, constant: -15)
        let imageViewTopConstraint = NSLayoutConstraint(item: imageView, attribute: .top, relatedBy: .equal, toItem: feedbackView, attribute: .top, multiplier: 1, constant: 8)
        let imageViewWidthContraint = NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 25)
        let imageViewHeightConstraint = NSLayoutConstraint(item: imageView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 25)
    feedbackView.addConstraints([imageViewTrailingConstraint,imageViewTopConstraint,imageViewWidthContraint, imageViewHeightConstraint])
        
        let otherLabel = UILabel()
        otherLabel.text = "Not the right place?"
        otherLabel.font = UIFont.italicSystemFont(ofSize: 14.0)
        otherLabel.textAlignment = .right
        otherLabel.textColor = Constants.colors.primaryLight
        feedbackView.addSubview(otherLabel)
        
        otherLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let otherLabelTrailingConstraint = NSLayoutConstraint(item: otherLabel, attribute: .trailing, relatedBy: .equal, toItem: imageView, attribute: .leading, multiplier: 1, constant: -5)
        let otherLabelTopConstraint = NSLayoutConstraint(item: otherLabel, attribute: .top, relatedBy: .equal, toItem: feedbackView, attribute: .top, multiplier: 1, constant: 8)

        let otherLabelWidthContraint = NSLayoutConstraint(item: otherLabel, attribute: .width, relatedBy: .equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 200)
        let otherLabelHeightContraint = NSLayoutConstraint(item: otherLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 25)

        feedbackView.addConstraints([otherLabelTrailingConstraint, otherLabelTopConstraint, otherLabelWidthContraint, otherLabelHeightContraint])

        return feedbackView
    }
    
    fileprivate func buildFeedbackButtons(_ rect: CGRect, _ index: Int) -> UIView {
        let feedbackView = UIView()
        feedbackView.frame = rect
        
        let btn1 = feedbackButton(text: "Yes ✓", tag: index, type: 0)
        let btn2 = feedbackButton(text: "Delete ✕", tag: index, type: 1)
        let btn3 = feedbackButton(text: "Correct ‣", tag: index, type: 2)
        
        let buttonWidth: CGFloat = (rect.width - 14.0 - 20.0) / 3.0 // margin right and interspaces
        
        var x: CGFloat = 0.0
        btn1.frame = CGRect(x: x, y: 10, width: buttonWidth, height: 40)
        x += buttonWidth + 10.0
        btn2.frame = CGRect(x: x, y: 10, width: buttonWidth, height: 40)
        x += buttonWidth + 10.0
        btn3.frame = CGRect(x: x, y: 10, width: buttonWidth, height: 40)
        
        feedbackView.addSubview(btn1)
        feedbackView.addSubview(btn2)
        feedbackView.addSubview(btn3)
        
        return feedbackView
    }
    
    fileprivate func feedbackButton(text: String, tag: Int, type: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.layer.cornerRadius = 5.0
        btn.layer.masksToBounds = true
        btn.tag = tag
        btn.setTitle(text, for: .normal)
        btn.setTitleColor(Constants.colors.primaryDark, for: .normal)
        btn.setTitleColor(Constants.colors.primaryMidDark, for: .highlighted)
        btn.setBackgroundColor(Constants.colors.superLightGray, for: .normal)
        btn.setBackgroundColor(Constants.colors.primaryLight, for: .highlighted)
        btn.titleLabel?.font =  UIFont.italicSystemFont(ofSize: 14.0)
        if type == 0 { // Yes
            btn.addTarget(self, action: #selector(feedbackButtonTappedYes), for: .touchUpInside)
        } else if type == 1 { // No, not at a place
            btn.addTarget(self, action: #selector(feedbackButtonTappedNo), for: .touchUpInside)
        } else if type == 2 { // No, other place
            btn.addTarget(self, action: #selector(feedbackButtonTappedOther), for: .touchUpInside)
        }
        
        return btn
    }
    
    func removeFeedbackLine(at index: Int, callback: (()->Void)? = nil) {
        if isAnimating { return }
        
        let duration = 0.25
        let feedbackHeight:CGFloat = 60.0
        isAnimating = true
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
        
        // hide the feedback view buttons
        self.layers[index].feedbackView?.hide()
        
        CATransaction.setCompletionBlock { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.isAnimating = false
            callback?()
        }
        
        for i in index+1..<self.layers.count {
            for layer in self.layers[i].getLayers() {
                if let lineLayer = layer as? MovableLineLayer {
                    lineLayer.moveUp(by: -1.0 * feedbackHeight, with: duration)
                } else {
                    layer.moveDown(by: -1.0 * feedbackHeight, with: duration)
                }
            }
        }
        
        // Deal with the bottom of the timeline
        if index+1 != self.layers.count {
            for i in 0..<index+1 {
                if let lineLayer = self.layers[i].lineLayer {
                    lineLayer.movePath(by: -1.0 * feedbackHeight, with: duration)
                }
            }
        }
        
        // Deal with the add place buttons
        for btn in self.addButtons {
            if btn.getPosition() >= index {
                btn.moveDown(by: -1.0 * feedbackHeight, with: duration)
            }
        }
        
        // Remove feedbackView from the visit block
        self.layers[index].feedbackView = nil
        
        CATransaction.commit()
        
        self.contentSize = CGSize(width: self.contentSize.width, height: self.contentSize.height - feedbackHeight)
    }
    
    func removeVisitFromTimeline(at index: Int, callback: (()->Void)? = nil) {
        if isAnimating { return }
        
        let duration = 0.5
        let visitBlockHeight = self.layers[index].height()
        
        isAnimating = true
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
        
        // hide the visit block
        self.layers[index].hideAllLayers()
        
        CATransaction.setCompletionBlock { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.isAnimating = false
            
            // Adjust the indexes for all the visit blocks
            for i in 0..<strongSelf.layers.count {
                if i > index {
                    if let subviews = strongSelf.layers[i].feedbackView?.view?.subviews {
                        for case let btn as UIButton in subviews {
                            btn.tag -= 1
                        }
                    }
                    strongSelf.layers[i].decrementPosition()
                }
                strongSelf.layers[i].decrementMaxPosition()
            }
            strongSelf._points.remove(at: index)
            strongSelf.layers.remove(at: index)
            strongSelf.sections.remove(at: index)
            
            strongSelf.contentSize = CGSize(width: strongSelf.contentSize.width, height: strongSelf.contentSize.height - visitBlockHeight)
            
            callback?()
        }
        
        for i in index+1..<self.layers.count {
            for layer in self.layers[i].getLayers() {
                if let lineLayer = layer as? MovableLineLayer {
                    lineLayer.moveUp(by: -1.0 * visitBlockHeight, with: duration)
                } else {
                    layer.moveDown(by: -1.0 * visitBlockHeight, with: duration)
                }
            }
        }
        
        // Deal with the bottom of the timeline
        if index < self.layers.count-2 {
            for i in 0..<index+1 {
                if let lineLayer = self.layers[i].lineLayer {
                    lineLayer.movePath(by: -1.0 * visitBlockHeight, with: duration)
                }
            }
        } else if index == self.layers.count-1 { // last visit block
            // add a bottom cap if the index is last
            if index > 1 {
                if let lineLayer = self.layers[index-1].lineLayer {
                    lineLayer.hide()
                }
                if let lineLayer = self.layers[index-2].lineLayer {
                    lineLayer.bottomCap?.isHidden = false
                }
            }
            if index > 0 {
                for i in 0..<index {
                    if let lineLayer = self.layers[i].lineLayer {
                        let previousVisitBlockHeight = self.layers[index-1].height()
                        lineLayer.movePath(by: -1.0 * previousVisitBlockHeight, with: duration)
                    }
                }
            }
        } else if index == self.layers.count-2 { // before to last visit block
            // add a bottom cap to the previous line
            if index > 0 {
                if let lineLayer = self.layers[index-1].lineLayer {
                    lineLayer.bottomCap?.isHidden = false
                }
                
                for i in 0..<index {
                    if let lineLayer = self.layers[i].lineLayer {
                        lineLayer.movePath(by: -1.0 * visitBlockHeight, with: duration)
                    }
                }
            }
        }
        
        CATransaction.commit()
    }
    
    @objc func feedbackButtonTappedYes(sender: UIButton) {
        print("At a place (\(sender.tag))")
        if !isEditing {
            let pt = self._points[sender.tag]
            removeFeedbackLine(at: sender.tag) { [weak self] in
                guard let strongSelf = self else { return }
                print("feedbackButtonTappedYes")
                strongSelf.timelineValidatedPlaceTouchAction?(pt)
            }
        }
    }
    
    @objc func feedbackButtonTappedNo(sender: UIButton) {
        print("Not at a place (\(sender.tag))")
        print("number of layers: \(self.layers.count), number of points: \(_points.count)")
        if !isEditing {
            let pt = self._points[sender.tag]
            removeVisitFromTimeline(at: sender.tag) { [weak self] in
                guard let strongSelf = self else { return }
                print("feedbackButtonTappedNo")
                strongSelf.timelineRemovedPlaceTouchAction?(pt)
            }
        }
    }
    
    @objc func feedbackButtonTappedOther(sender: UIButton) {
        print("At an other place (\(sender.tag))")
        if !isEditing {
            points[sender.tag].feedbackTouchUpInside?(points[sender.tag])
        }
    }
    
    fileprivate func buildDescriptionLabel(text: String?) -> UILabel? {
        if (text != nil) {
            let descriptionLabel = UILabel()
            descriptionLabel.text = text
            descriptionLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .light)
            descriptionLabel.lineBreakMode = .byWordWrapping
            descriptionLabel.numberOfLines = 0
            descriptionLabel.preferredMaxLayoutWidth = calcWidth()
            return descriptionLabel
        }
        return nil
    }
    
    fileprivate func buildAddLabel(text: String?) -> UILabel? {
        if (text != nil) {
            let addLabel = UILabel()
            addLabel.text = text
            addLabel.font = UIFont.boldSystemFont(ofSize: 14.0)
            addLabel.lineBreakMode = .byWordWrapping
            addLabel.numberOfLines = 0
            addLabel.preferredMaxLayoutWidth = calcWidth()
            return addLabel
        }
        return nil
    }
    
    fileprivate func calcWidth() -> CGFloat {
        return self.bounds.width - (self.contentInset.left + self.contentInset.right) - pointDiameter - lineWidth - ISTimeline.gap * 1.5
    }
    
    fileprivate func drawLine(_ start:CGPoint, end:CGPoint, color:CGColor, cap:Int, offset:CGFloat = 0.0, layer:MovableLineLayer) -> CAShapeLayer {
        var startPoint = start
        startPoint.y -= offset
        
        let path = UIBezierPath()
        path.move(to: startPoint)
        path.addLine(to: end)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = color
        shapeLayer.lineWidth = lineWidth
        
        if cap > 0 {
            let topRoundedCap = UIBezierPath(ovalIn: CGRect(x: start.x - lineWidth/2.0, y: start.y - lineWidth/2.0, width: lineWidth, height: lineWidth))
            let topRoundedCapLayer = CAShapeLayer()
            topRoundedCapLayer.path = topRoundedCap.cgPath
            topRoundedCapLayer.fillColor = color
            topRoundedCapLayer.lineWidth = 0
            shapeLayer.addSublayer(topRoundedCapLayer)
            layer.topCap = topRoundedCapLayer
            
            let lineOffset = 1.0 - ((end.y - start.y) / (end.y - startPoint.y))
            shapeLayer.strokeStart = lineOffset
            let bottomRoundedCap = UIBezierPath(ovalIn: CGRect(x: end.x - lineWidth/2.0, y: end.y - lineWidth/2.0, width: lineWidth, height: lineWidth))
            let bottomRoundedCapLayer = CAShapeLayer()
            bottomRoundedCapLayer.path = bottomRoundedCap.cgPath
            bottomRoundedCapLayer.fillColor = color
            bottomRoundedCapLayer.lineWidth = 0
            shapeLayer.addSublayer(bottomRoundedCapLayer)
            layer.bottomCap = bottomRoundedCapLayer
            
            if cap == 2 {
                layer.bottomCap?.isHidden = false
                layer.lineOffset = lineOffset
            } else {
                layer.bottomCap?.isHidden = true
            }
        }
        
        layer.line = shapeLayer
        return shapeLayer
    }
    
    fileprivate func drawPoint(_ point:CGPoint, color:CGColor, fill:Bool) -> CALayer {
        let path = UIBezierPath(ovalIn: CGRect(x: point.x, y: point.y, width: pointDiameter, height: pointDiameter))
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = color
        shapeLayer.fillColor = fill ? color : UIColor.clear.cgColor
        shapeLayer.lineWidth = 0
        
        return shapeLayer
    }
    
    fileprivate func drawIcon(_ point: CGPoint, fill: CGColor, image: UIImage, scale: CGFloat = 0.8) -> UIView {
        let path = UIBezierPath(ovalIn: CGRect(x: point.x, y: point.y, width: iconDiameter, height: iconDiameter))
        
        let iconView = UIView()
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = fill
        shapeLayer.lineWidth = 0
        iconView.layer.addSublayer(shapeLayer)
        
        let imageView = UIImageView(image: image.withRenderingMode(.alwaysTemplate))
        imageView.tintColor = UIColor.white
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: point.x + (1.0-scale)/2*iconDiameter, y: point.y + (1.0-scale)/2*iconDiameter, width: scale*iconDiameter, height: scale*iconDiameter)
        iconView.addSubview(imageView)
        
        return iconView
    }
    
    fileprivate func drawBubble(_ rect:CGRect, backgroundColor:UIColor, textColor:UIColor, titleLabel:UILabel) -> UILabel {
        
        let titleRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width - 15, height: rect.size.height - 1)
        titleLabel.textColor = Constants.colors.black
        titleLabel.frame = titleRect
        
        return titleLabel
    }
    
    fileprivate func drawDescription(_ rect:CGRect, textColor:UIColor, descriptionLabel:UILabel) -> UILabel {
        descriptionLabel.textColor = textColor
        descriptionLabel.frame = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.width - 10, height: rect.height)
        
        return descriptionLabel
    }
    
    fileprivate func drawDescriptionSupp(_ rect:CGRect, descriptionSupp:UIView) -> UIView {
        descriptionSupp.frame = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.width - 10, height: rect.height)
        return descriptionSupp
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let point = touches.first!.location(in: self)
        
        if isEditing {
            for (index, addButton) in addButtonViews.enumerated() {
                if addButton.frame.contains(point) {
                    isEditing = false
                    if index == 0 {
                        timelimeAddPlaceFirstTouchAction?(_points.first, nil)
                    } else if index == addButtonViews.count - 1 {
                        timelimeAddPlaceLastTouchAction?(nil, _points.last)
                    } else {
                        _points[index-1].addPlaceTouchUpInside?(points[index-1], points[index])
                    }
                    return
                }
            }
        } else {
            for (index, layer) in layers.enumerated() {
                if (layer.bubbleView != nil && layer.bubbleView!.view!.frame.contains(point) ||
                    (layer.descriptionView != nil && layer.descriptionView!.view!.frame.contains(point)) ||
                    (layer.descriptionSuppView != nil && layer.descriptionSuppView!.view!.frame.contains(point))) {
                    _points[index].touchUpInside?(_points[index])
                    return
                }
            }
        }
    }
}
