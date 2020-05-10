import Combine
import Foundation

public typealias CompletionHandler = (Error?)->()

func completionPublisher(_ block: @escaping (@escaping CompletionHandler)->()) -> AnyPublisher<Void, Error> {
    return Future { promise in
        block() { error in
            if let error = error {
                promise(.failure(error))
            } else {
                promise(.success(()))
            }
        }
    }
    .receive(on: DispatchQueue.main)
    .eraseToAnyPublisher()
}
