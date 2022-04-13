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

class OperationPublisher<OperationType: GraphQLOperation>: Publisher {
  typealias Output = OperationType.Data
  typealias Failure = GQLError

  private let client: ApolloClientProtocol
  private let operation: OperationType
  private let operationQueue: DispatchQueue

  init(client: ApolloClientProtocol, operation: OperationType, operationQueue: DispatchQueue) {
    self.client = client
    self.operation = operation
    self.operationQueue = operationQueue
  }

  final func receive<SubscriberType>(subscriber: SubscriberType)
    where SubscriberType: Subscriber, GQLError == SubscriberType.Failure, OperationType.Data == SubscriberType.Input
  {
    let subscription: OperationSubscription<SubscriberType, OperationType> = createSubscription(
      for: subscriber,
      client: client,
      operation: operation,
      operationQueue: operationQueue
    )
    subscriber.receive(subscription: subscription)
  }

  func createSubscription<SubscriberType>(
    for: SubscriberType,
    client: ApolloClientProtocol,
    operation: OperationType,
    operationQueue: DispatchQueue
  ) -> OperationSubscription<SubscriberType, OperationType> {
    fatalError("missing implementation")
  }
}
