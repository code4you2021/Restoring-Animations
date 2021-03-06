import UIKit


/// The `AnimationPreservingView` class keeps it's layer tree animations safe from being removed.
/// There are two cases when `CAAnimation` can be removed from `CALayer` automatically:
/// - when application goes to background
/// - when view backed by the layer is removed from window
class AnimationPreservingView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForNotifications()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        registerForNotifications()
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { layer.storeAnimations() }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { layer.restoreAnimations() }
    }
}


extension AnimationPreservingView {
    
    fileprivate func registerForNotifications() {
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(AnimationPreservingView.applicationWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(AnimationPreservingView.applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    @objc private func applicationWillResignActive() {
        
        guard window != nil else { return }
        layer.storeAnimations()
    }
    
    @objc private func applicationDidBecomeActive() {
        
        guard window != nil else { return }
        layer.restoreAnimations()
    }
}


extension CALayer {
    
    private static let association = ObjectAssociation<NSDictionary>()
    
    private var animationsStorage: [String: CAAnimation] {

        get { return CALayer.association[self] as? [String : CAAnimation] ?? [:] }
        set { CALayer.association[self] = newValue as NSDictionary }
    }
    
    /// Returns a dictionary of copies of animations currently attached to the layer along with their's keys.
    private var animationsForKeys: [String: CAAnimation] {
        
        guard let keys = animationKeys() else { return [:] }
        return keys.reduce([:], {
            var result = $0
            let key = $1
            result[key] = (animation(forKey: key)!.copy() as! CAAnimation)
            return result
        })
    }
    
    /// Pauses the layer tree and stores it's animations.
    func storeAnimations() {
        
        pause()
        depositAnimations()
    }
    
    /// Resumes the layer tree and restores it's animations.
    func restoreAnimations() {
        
        withdrawAnimations()
        resume()
    }
    
    private func depositAnimations() {
        
        animationsStorage = animationsForKeys
        sublayers?.forEach { $0.depositAnimations() }
    }
    
    private func withdrawAnimations() {
        
        sublayers?.forEach { $0.withdrawAnimations() }
        animationsStorage.forEach { add($0.value, forKey: $0.key) }
        animationsStorage = [:]
    }
}


extension CALayer {
    
    /// Pauses animations in layer tree.
    /// - note: [Technical Q&A QA1673](https://developer.apple.com/library/ios/qa/qa1673/_index.html#//apple_ref/doc/uid/DTS40010053)
    fileprivate func pause() {
        
        let pausedTime = convertTime(CACurrentMediaTime(), from: nil)
        speed = 0.0;
        timeOffset = pausedTime;
    }
    
    /// Resumes animations in layer tree.
    /// - note: [Technical Q&A QA1673](https://developer.apple.com/library/ios/qa/qa1673/_index.html#//apple_ref/doc/uid/DTS40010053)
    fileprivate func resume() {
        
        let pausedTime = timeOffset;
        speed = 1.0;
        timeOffset = 0.0;
        beginTime = 0.0;
        let timeSincePause = convertTime(CACurrentMediaTime(), from: nil) - pausedTime;
        beginTime = timeSincePause;
    }
}

/// Wraps Objective-C runtime object associations. Assumes one instance per association key.
///
/// Example usage when simulating stored property with a computed one:
///
///     extension SomeType {
///         private static let association = ObjectAssociation<NSObject>()
///         var simulatedProperty: NSObject? {
///             get { return SomeType.association[self] }
///             set { SomeType.association[self] = newValue }
///         }
///     }
public final class ObjectAssociation<T: AnyObject> {
    
    private let policy: objc_AssociationPolicy
    
    /// - Parameter policy: An association policy that will be used when linking objects.
    public init(policy: objc_AssociationPolicy = .OBJC_ASSOCIATION_RETAIN_NONATOMIC) {
        
        self.policy = policy
    }
    
    /// Accesses associated object.
    /// - Parameter index: An object whose associated object is to be accessed.
    public subscript(index: AnyObject) -> T? {
        
        get { return objc_getAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque()) as! T? }
        set { objc_setAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque(), newValue, policy) }
    }
}
