import Foundation
import Combine

/// Helper protocol for any objects that have subscriber they want to hold on to.
public protocol ModelObserver {
    var disposeBag: Set<AnyCancellable> { get set }
}

/// Wrapper for value types that adds a publisher to it that detects any changes made to the given value.
///
/// **Do not use reference types as Value**
public final class Observable<Value> {
    
    /// The subject that holds the current value and publishes any changes.
    /// Subscribe to this to track changes to the value.
    public var publisher: CurrentValueSubject<Value, Never>
    
    /// The value that should be observed.
    private var value: Value
    
    public init(value: Value) {
        self.value = value
        self.publisher = CurrentValueSubject(value)
    }
    
    /// Update the observed value. This will trigger the publisher to send that new value to all its subscribers.
    /// - Parameter value: The new value
    public func update(valueTo newValue: Value) {
        self.value = newValue
        publisher.send(newValue)
    }
    
}

/// Wrapper class for `Observable<Value>` instances.
/// This class places a relay observer between the given `observable` and any potential subscriber.
///
///
/// You can still subscribe normally to this object's `publisher` property that will behave in the exact same way the observable's publisher would.
/// However, internally you're actually subscribing to a relay publisher that acts as a man-in-the-middle and allows for the observable to be swapped without
/// any of the existing subscribtions to keep receiving updates from the old observable.
///
/// This class is meant to be used within a struct that's referencing another `Observable`. Simply pass the observable to this class and use it as if it were an `Observable`.
public final class ObservableRelay<Value>: ModelObserver {
    
    /// The set containing the subscriber so that it stays attached as long as this object exists.
    public var disposeBag: Set<AnyCancellable> = Set()
    
    /// The publisher you can subscribe to in order to observe changes to the value.
    /// This is an alias for the internally used `relayObserver`, it is meant to to be used exactly like you would use an `Observable`'s publisher.
    public private(set) var publisher: CurrentValueSubject<Value, Never> {
        get { relayPublisher }
        set { relayPublisher = newValue }
    }
    
    /// The observer that will take the place of the given observable's publisher, acting exactly the same to the public (see `self.observable`).
    ///
    /// Instead of subscribing to the observable's publisher directly, you implicitly subscribe to this relay.
    /// Whenever the original observable publishes a new value, it will be redirected to the `relayObserver` that instead publishes the value to the outside subscribers.
    private var relayPublisher: CurrentValueSubject<Value, Never>
    
    /// The observer whose publications you want to intercept.
    /// It is kept private to hide it from the outside as the relay observer handles any subscriptions and publications from the observable's publisher.
    private var observable: Observable<Value>
    
    public init(observable: Observable<Value>) {
        self.observable = observable
        self.relayPublisher = CurrentValueSubject<Value, Never>(observable.publisher.value)
        subscribe()
    }
    
    /// Subscribe to the obervable's publisher.
    /// Whenever it publishes a new value, simply re-direct it to the relay.
    private func subscribe() {
        // Whenever the observable's observer publishes a new value, take that and re-route it through the relay's publisher.
        observable.publisher.sink { (value) in
            self.relayPublisher.send(value)
        }.store(in: &disposeBag)
    }
    
    /// Update the observed value of the given `observable` property. This will trigger the publisher (and therefore the relay publisher) to send that new value to all its subscribers.
    /// - Parameter newValue: The new value
    public func update(valueTo newValue: Value) {
        // Re-route the update to the observer
        observable.update(valueTo: newValue)
    }
    
    public func update(observableTo newObservable: Observable<Value>) {
        
        guard let subscriber = disposeBag.first else {
            fatalError("This should not happen")
        }
        
        // Cancel the subscription to the old observable
        subscriber.cancel()
        disposeBag.remove(subscriber)
        
        // Set the new observable
        observable = newObservable
        
        // re-subscribe
        subscribe()
        
    }
}
