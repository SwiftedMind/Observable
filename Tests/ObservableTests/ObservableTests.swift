import XCTest
import Combine
@testable import Observable

final class ObservableTests: XCTestCase {
    
    struct Person {
        var name: String
        var idCardRelay: ObservableRelay<IDCard>
        
        init(name: String, idCardObservable: Observable<IDCard>) {
            self.name = name
            self.idCardRelay = ObservableRelay(observable: idCardObservable)
        }
    }
    
    struct IDCard {
        var name: String
    }
    
    func testObservable() {
        let idCardObservable = Observable(value: IDCard(name: ""))
        
        var person = Person(name: "A", idCardObservable: idCardObservable)
        let personObservable = Observable(value: person)
        
        var observedPersonName: String = ""
        
        // Somehow, I have to save it to a named variable. "_ = ..." does not keep the subscriber alive somehow.
        let subscriber: AnyCancellable = personObservable.publisher.map(\.name).sink { (name) in
            observedPersonName = name
        }
        
        XCTAssertTrue(observedPersonName == "A", "The person's name is not correct.")
        
        // Now change the person
        person.name = "changed"
        personObservable.update(to: person)
        
        XCTAssertTrue(observedPersonName == "changed", "The person's changed name is not correct.")
    }
    
    func testObservableRelay() {
        let firstCard = IDCard(name: "First Card")
        let secondCard = IDCard(name: "Second Card")
        
        let firstCardObservable = Observable(value: firstCard)
        let secondCardObservable = Observable(value: secondCard)
        
        let person = Person(name: "A", idCardObservable: firstCardObservable)
        let personObservable = Observable(value: person)
        
        var observedIdCardName: String = ""
        
        // Subscribe to changes to the person's id card
        let subscriber: AnyCancellable = personObservable
            .publisher
            .flatMap{ $0.idCardRelay.publisher }
            .map(\.name)
            .sink { (name) in
                observedIdCardName = name
        }
        
        XCTAssertEqual(observedIdCardName, "First Card")
        
        // Change the id card's name
        var firstCardCopy = firstCardObservable.publisher.value
        firstCardCopy.name = "changed"
        firstCardObservable.update(to: firstCardCopy)
        
        XCTAssertEqual(observedIdCardName, "changed")
        
        // Now replace the id card with the second card
        person.idCardRelay.update(observableTo: secondCardObservable)
        personObservable.update(to: person)
        
        XCTAssertEqual(observedIdCardName, "Second Card")
    }

    static var allTests = [
        ("testObservable", testObservable),
        ("testObservableRelay", testObservableRelay)
    ]
}
