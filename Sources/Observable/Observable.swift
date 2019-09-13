import Foundation
import Combine

public protocol ModelObserver {
    var disposeBag: Set<AnyCancellable> { get set }
}

public final class Observable<Value> {
    public var publisher: CurrentValueSubject<Value, Never>
    private var value: Value
    
    public init(value: Value) {
        self.value = value
        self.publisher = CurrentValueSubject(value)
    }
    
    public func update(with value: Value) {
        self.value = value
        publisher.send(value)
    }
    
}

// Test

/// Wrapper class for `Observable<Value>` instances.
/// This class places a relay observer between the given observable and any potential subscriber.
/// You can still subscribe to the given observable as if this was a `Observable` class and you will get the same behavior.
/// However, this relay allows for the the observable to be swapped and for that to be detectable by any subscriber.
/// This class is meant to be used within a struct that's referencing another `Observable`.
public final class ObservableRelay<Value>: ModelObserver {
    
    /// The set containing the subscriber so that is stays attached as long as this object exists.
    public var disposeBag: Set<AnyCancellable> = Set()
    
    /// The observer you can subscribe to in order to observe changes to the value.
    /// This is an alias for the internally used `relayObserver`, it is meant to to be used exactly like you would use an `Observable`.
    public private(set) var publisher: CurrentValueSubject<Value, Never> {
        get { relayPublisher }
        set { relayPublisher = newValue }
    }
    
    /// The observer that will take the place of the given observable's publisher (see `self.observable`).
    ///
    /// Instead of subscribing to the observer directly, you implicitly subscribe to this relay.
    /// Whenever the original observable publishes a new value, it will be redirected to the `relayObserver` that instead publishes the value to the outside subscribers.
    private var relayPublisher: CurrentValueSubject<Value, Never>
    
    /// The observer whose observations you want to intercept.
    /// It is kept private to hide it from the outside as the relay observer handles any subscriptions and publications from the observable's publisher.
    private var observable: Observable<Value>
    
    public init(observable: Observable<Value>) {
        self.observable = observable
        self.relayPublisher = CurrentValueSubject<Value, Never>(observable.publisher.value)
        subscribe()
    }
    
    /// Subscribe to the obervable.
    /// Whenever it publishes a new value, simply re-direct it to the relay
    private func subscribe() {
        // Whenever the observable's observer publishes a new value, take that and re-route it through the relay's publisher.
        observable.publisher.sink { (value) in
            self.relayPublisher.send(value)
        }.store(in: &disposeBag)
    }
    
    public func update(valueTo newValue: Value) {
        // Re-route the update to the observer
        observable.update(with: newValue)
    }
    
    public func update(observableTo newObservable: Observable<Value>) {
        // Cancel the subscription to the old observable
        disposeBag.first!.cancel()
        
        // Set the new observable
        observable = newObservable
        
        // re-subscribe
        subscribe()
    }
}
