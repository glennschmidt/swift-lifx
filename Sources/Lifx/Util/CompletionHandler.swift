import Combine
import Foundation

public typealias CompletionHandler = (Error?)->()

func completionPublisher(on queue: DispatchQueue, block: @escaping (@escaping CompletionHandler)->()) -> AnyPublisher<Void, Error> {
    return Future { promise in
        block() { error in
            if let error = error {
                promise(.failure(error))
            } else {
                promise(.success(()))
            }
        }
    }
    .receive(on: queue)
    .eraseToAnyPublisher()
}

func completionHandler(_ handler: CompletionHandler?, on queue: DispatchQueue) -> CompletionHandler? {
    guard let handler = handler else {
        return nil
    }
    return { err in
        queue.async {
            handler(err)
        }
    }
}
