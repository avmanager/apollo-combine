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

public class DefaultGQLClient: GQLClient {
  private let client: ApolloClientProtocol
  private let operationQueue: DispatchQueue = .init(label: "gql-operation", qos: .userInteractive)

  private init(client: ApolloClientProtocol) {
    self.client = client
  }
}

// MARK: - Factory

extension DefaultGQLClient {
  public static func newInstance(
    endpoint: URL,
    intercepterProvider: InterceptorProvider,
    store: ApolloStore
  ) -> GQLClient {
    let normalTransport = RequestChainNetworkTransport(interceptorProvider: intercepterProvider, endpointURL: endpoint)
    let client = ApolloClient(networkTransport: normalTransport, store: store)
    return DefaultGQLClient(client: client)
  }
}

// MARK: - Operations

extension DefaultGQLClient {
  public func fetch<QueryType: GraphQLQuery>(
    query: QueryType,
    cachePolicy: CachePolicy
  ) -> AnyPublisher<QueryType.Data, GQLError> {
    QueryPublisher<QueryType>(cachePolicy: cachePolicy, client: client, query: query, operationQueue: operationQueue)
      .eraseToAnyPublisher()
  }

  public func perform<MutationType: GraphQLMutation>(
    mutation: MutationType
  ) -> AnyPublisher<MutationType.Data, GQLError> {
    MutationPublisher<MutationType>(client: client, operation: mutation, operationQueue: operationQueue)
      .eraseToAnyPublisher()
  }

  public func subscribe<SubscriptionType: GraphQLSubscription>(
    subscription: SubscriptionType
  ) -> AnyPublisher<SubscriptionType.Data, GQLError> {
    SubscriptionPublisher<SubscriptionType>(client: client, operation: subscription, operationQueue: operationQueue)
      .eraseToAnyPublisher()
  }
}
