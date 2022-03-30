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

class QuerySubscription<SubscriberType: Subscriber, QueryType: GraphQLQuery>: OperationSubscription<SubscriberType, QueryType>
  where SubscriberType.Input == QueryType.Data, SubscriberType.Failure == GQLError
{
  private let cachePolicy: CachePolicy
  private let contextIdentifier: UUID?

  init(
    cachePolicy: CachePolicy,
    contextIdentifier: UUID? = nil,
    subscriber: SubscriberType,
    client: ApolloClientProtocol,
    operation: QueryType,
    operationQueue: DispatchQueue
  ) {
    self.cachePolicy = cachePolicy
    self.contextIdentifier = contextIdentifier

    super.init(
      subscriber: subscriber,
      client: client,
      operation: operation,
      operationQueue: operationQueue,
      completion: .onSuccess
    )
  }

  override func executeOperation() -> Apollo.Cancellable {
    client.fetch(
      query: operation,
      cachePolicy: cachePolicy,
      contextIdentifier: contextIdentifier,
      queue: operationQueue
    ) { [weak self] result in
      self?.handle(result: result)
    }
  }
}
