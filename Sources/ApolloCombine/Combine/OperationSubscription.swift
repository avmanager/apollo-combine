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
  case none
  case onServerData
  case onSuccess
}

final class OperationSubscription<SubscriberType: Subscriber, Input>: Subscription
  where SubscriberType.Input == Input, SubscriberType.Failure == GQLError
{
  private var cancellable: Apollo.Cancellable?
  private let completion: Completion
  private let lock = NSRecursiveLock()
  private let operation: (@escaping (Result<GraphQLResult<Input>, Error>) -> Void) -> Apollo.Cancellable
  private var subscriber: SubscriberType?

  init(
    completion: Completion,
    operation: @escaping (@escaping (Result<GraphQLResult<Input>, Error>) -> Void) -> Apollo.Cancellable,
    subscriber: SubscriberType
  ) {
    self.completion = completion
    self.operation = operation
    self.subscriber = subscriber
  }

  func request(_ demand: Subscribers.Demand) {
    guard demand > .none else {
      return
    }

    lock.lock()
    defer {
      lock.unlock()
    }

    cancellable?.cancel()
    cancellable = operation { [weak self] value in
      self?.handle(result: value)
    }
  }

  func cancel() {
    lock.lock()
    defer {
      lock.unlock()
    }

    // Release the subscriber reference and also prevent it from further receiving values.
    self.subscriber = nil
    cancellable?.cancel()

    // Do not send a `finished` event on cancel, since a GQL subscription should never complete. Sending an event
    // upon cancel can result in a fatal error of: Fatal error: Unexpected state: received completion but do not have
    // subscription
  }

  private func handle(result: Result<GraphQLResult<Input>, Error>) {
    lock.lock()
    defer {
      lock.unlock()
    }

    guard let subscriber = subscriber else {
      return
    }

    func complete(completion: Subscribers.Completion<GQLError>) {
      self.subscriber = nil
      subscriber.receive(completion: completion)
    }

    switch result {
    case let .success(resultData):
      if let errors = resultData.errors, !errors.isEmpty {
        complete(completion: .failure(.errors(errors)))
      } else if let data = resultData.data {
        // Ignore demand since it's unlimited.
        _ = subscriber.receive(data)
        if completion == .onSuccess {
          complete(completion: .finished)
        } else if completion == .onServerData, resultData.source == .server {
          complete(completion: .finished)
        }
      } else {
        complete(completion: .failure(.missingData))
      }
    case let .failure(error):
      complete(completion: .failure(.nonGQL(error)))
    }
  }
}
