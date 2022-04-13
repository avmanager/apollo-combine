// MIT License
//
// Copyright (c) 2022 Yi Wang
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Apollo
import Combine
import Foundation

enum Completion {
  case onSuccess
  case onCancel
}

class OperationSubscription<SubscriberType: Subscriber, OperationType: GraphQLOperation>: Subscription
  where SubscriberType.Input == OperationType.Data, SubscriberType.Failure == GQLError
{
  let client: ApolloClientProtocol
  let operation: OperationType
  let operationQueue: DispatchQueue

  private let completion: Completion
  private let lock = NSRecursiveLock()
  private var subscriber: SubscriberType?
  private var cancellable: Apollo.Cancellable?

  init(
    subscriber: SubscriberType,
    client: ApolloClientProtocol,
    operation: OperationType,
    operationQueue: DispatchQueue,
    completion: Completion
  ) {
    self.subscriber = subscriber
    self.client = client
    self.operation = operation
    self.operationQueue = operationQueue
    self.completion = completion
  }

  final func request(_ demand: Subscribers.Demand) {
    guard demand > .none else {
      return
    }

    lock.lock()
    defer {
      lock.unlock()
    }

    cancellable?.cancel()
    cancellable = executeOperation()
  }

  final func cancel() {
    lock.lock()
    defer {
      lock.unlock()
    }

    if completion == .onCancel {
      subscriber?.receive(completion: .finished)
    }

    // Release the subscriber reference and also prevent it from further receiving values.
    subscriber = nil
    cancellable?.cancel()
  }

  func executeOperation() -> Apollo.Cancellable {
    EmptyCancellable()
  }

  final func handle(result: Result<GraphQLResult<SubscriberType.Input>, Error>) {
    lock.lock()
    defer {
      lock.unlock()
    }

    guard let subscriber = subscriber else {
      return
    }

    switch result {
    case let .success(data):
      if let data = data.data {
        // Ignore demand since it's unlimited.
        _ = subscriber.receive(data)
        if completion == .onSuccess {
          subscriber.receive(completion: .finished)
        }
      } else if let errors = data.errors, !errors.isEmpty {
        subscriber.receive(completion: .failure(.errors(errors)))
      } else {
        subscriber.receive(completion: .failure(.missingData))
      }
    case let .failure(error):
      subscriber.receive(completion: .failure(.nonGQL(error)))
    }
  }
}
