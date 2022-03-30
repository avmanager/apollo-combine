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

/// A client used to communicate with the backend via GraphQL operations.
public protocol GQLClient {
  /// Perform a GQL query operation.
  ///
  /// - Parameters:
  ///   - query: The query operation.
  ///   - cachePolicy: The cache policy to use for the query's results.
  /// - Returns: A publisher for the query result data and error.
  func fetch<QueryType: GraphQLQuery>(
    query: QueryType,
    cachePolicy: CachePolicy
  ) -> AnyPublisher<QueryType.Data, GQLError>

  /// Perform a GQL mutation operation.
  ///
  /// - Parameters:
  ///   - mutation: The mutation operation.
  /// - Returns: A publisher for the mutation result data and error.
  func perform<MutationType: GraphQLMutation>(mutation: MutationType) -> AnyPublisher<MutationType.Data, GQLError>

  /// Subscribe to a GQL subscription.
  ///
  /// - Parameters:
  ///   - subscription: The subscription to subscribe to.
  /// - Returns: A publisher for the subscription result data and error.
  func subscribe<SubscriptionType: GraphQLSubscription>(
    subscription: SubscriptionType
  ) -> AnyPublisher<SubscriptionType.Data, GQLError>
}
