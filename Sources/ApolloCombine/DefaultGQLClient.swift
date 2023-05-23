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
import ApolloAPI
import ApolloWebSocket
import Combine
import Foundation

public class DefaultGQLClient: GQLClient {
  private let client: ApolloClientProtocol
  private let operationQueue = DispatchQueue(label: "gql-operation", qos: .userInteractive)
  private let webSocketStatusLock = NSRecursiveLock()
  private var webSocketTransport: WebSocketTransport?
  private var isWebSocketConnected = false

  private init(client: ApolloClientProtocol, webSocketTransport: WebSocketTransport?) {
    self.client = client
    self.webSocketTransport = webSocketTransport
  }
}

// MARK: - Factory

extension DefaultGQLClient {
  /// Create a new GQL client instance.
  ///
  /// - Parameters:
  ///   - normalEndpoint: The URL of the standard request/response endpoint.
  ///   - webSocketEndpoint: The URL of the web socket endpoint.
  ///   - intercepterProvider: Provider of interceptors used for request/response operations.
  ///   - store: The local cache store.
  ///   - additionalHeaders: The headers used for request/response operations.
  ///   - webSocketConnectingPayload: The payload used when making web socket connections.
  public static func newInstance(
    normalEndpoint: URL,
    webSocketEndpoint: URL? = nil,
    webSocketProtocol: WebSocket.WSProtocol = .graphql_ws,
    intercepterProvider: InterceptorProvider,
    store: ApolloStore,
    additionalHeaders: [String: String] = [:],
    webSocketConnectingPayload: JSONEncodableDictionary? = nil
  ) -> GQLClient {
    let (networkTransport, webSocketTransport) = newTransports(
      normalEndpoint: normalEndpoint,
      webSocketEndpoint: webSocketEndpoint,
      webSocketProtocol: webSocketProtocol,
      intercepterProvider: intercepterProvider,
      store: store,
      additionalHeaders: additionalHeaders,
      webSocketConnectingPayload: webSocketConnectingPayload
    )

    let client = ApolloClient(networkTransport: networkTransport, store: store)
    return DefaultGQLClient(client: client, webSocketTransport: webSocketTransport)
  }

  public static func newTransports(
    normalEndpoint: URL,
    webSocketEndpoint: URL? = nil,
    webSocketProtocol: WebSocket.WSProtocol = .graphql_ws,
    intercepterProvider: InterceptorProvider,
    store: ApolloStore,
    additionalHeaders: [String: String] = [:],
    webSocketConnectingPayload: JSONEncodableDictionary? = nil
  ) -> (NetworkTransport, WebSocketTransport?) {
    let normalTransport = RequestChainNetworkTransport(
      interceptorProvider: intercepterProvider,
      endpointURL: normalEndpoint,
      additionalHeaders: additionalHeaders
    )

    if let webSocketEndpoint = webSocketEndpoint {
      let webSocket = WebSocket(request: URLRequest(url: webSocketEndpoint), protocol: webSocketProtocol)
      let webSocketTransport = WebSocketTransport(
        websocket: webSocket,
        store: store,
        config: WebSocketTransport.Configuration(
          reconnect: false,
          reconnectionInterval: 0.5,
          allowSendingDuplicates: true,
          // Connection is made on first subscription. See below web socket section for details.
          connectOnInit: false,
          connectingPayload: webSocketConnectingPayload
        )
      )

      let splitNetworkTransport = SplitNetworkTransport(
        uploadingNetworkTransport: normalTransport,
        webSocketNetworkTransport: webSocketTransport
      )
      return (splitNetworkTransport, webSocketTransport)
    } else {
      return (normalTransport, nil)
    }
  }
}

// MARK: - Operations

extension DefaultGQLClient {
  public func fetch<QueryType: GraphQLQuery>(
    query: QueryType,
    cachePolicy: CachePolicy,
    contextIdentifier: UUID?
  ) -> AnyPublisher<QueryType.Data, GQLError> {
    QueryPublisher(
      client: client,
      query: query,
      queue: operationQueue,
      cachePolicy: cachePolicy,
      contextIdentifier: contextIdentifier
    )
    .eraseToAnyPublisher()
  }

  public func perform<MutationType: GraphQLMutation>(
    mutation: MutationType
  ) -> AnyPublisher<MutationType.Data, GQLError> {
    MutationPublisher(
      client: client,
      mutation: mutation,
      queue: operationQueue
    )
    .eraseToAnyPublisher()
  }

  public func subscribe<SubscriptionType: GraphQLSubscription>(
    subscription: SubscriptionType
  ) -> AnyPublisher<SubscriptionType.Data, GQLError> {
    SubscriptionPublisher(
      client: client,
      subscription: subscription,
      queue: operationQueue
    )
    .handleEvents(
      receiveSubscription: { [weak self] _ in
        self?.didSubscribeToWebSocket()
      },
      receiveCompletion: { [weak self] completion in
        switch completion {
        case let .failure(error):
          self?.webSocketDidError(error)
        default:
          break
        }
      }
    )
    .eraseToAnyPublisher()
  }
}

// MARK: - Web Socket

// The web socket is only connected on first subscription. Without a subscription, the connection error is not handled
// anywhere, therefore never retried. Apollo internally assumes the socket is connected even if the `connection_init`
// operation returned `connection_error`. When this occurs, the client can receive the error via the publisher and
// retry connecting.
extension DefaultGQLClient {
  public func updateWebSocketConnectingPayload(_ payload: JSONEncodableDictionary) {
    webSocketTransport?.updateConnectingPayload(payload, reconnectIfConnected: true)
  }

  private func didSubscribeToWebSocket() {
    webSocketStatusLock.lock()
    defer { webSocketStatusLock.unlock() }

    // Connect web socket on subscribe, if it's not connected.
    if !isWebSocketConnected {
      webSocketTransport?.resumeWebSocketConnection(autoReconnect: true)
      isWebSocketConnected = true
    }
  }

  private func webSocketDidError(_ error: GQLError) {
    webSocketStatusLock.lock()
    defer { webSocketStatusLock.unlock() }

    // Disconnect web socket on error. This allows subsequent subscriptions to retry connecting.
    if case let .nonGQL(underlyingError) = error, underlyingError is WebSocketError {
      webSocketTransport?.pauseWebSocketConnection()
      isWebSocketConnected = false
    }
  }
}
