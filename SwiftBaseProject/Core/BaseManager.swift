//
//  ServiceManager.swift
//  SwiftBaseProject
//
//  Created by Mauricio Cousillas on 3/12/18.
//  Copyright © 2018 Mauricio Cousillas. All rights reserved.
//

import Foundation
import Moya
import RxSwift

/**
 Public protocol that defines the minimum API that a ServiceManager should expose.

 The ServiceManager is the component in charge of handling al network request for
 an specific TargetType.

 Basic behaviour implemented using RxSwift is provided by the BaseManager class.
*/
public protocol ServiceManager {
  /// The associated TargetType of the Manager.
  associatedtype ProviderType: TargetType
  /// The MoyaProvider instance used to make the network requests.
  var provider: MoyaProvider<ProviderType> { get }
}

/**
 Base Manager class that implements generic behaviour to
 be extendended and used by subclassing it.

 The base manager has an associated TargetType, this means
 that you should have **one and only one** manager for each TargetType.

 This base implementation provides helpers to make requests using RxSwift
 with automatic encoding if you provide a propper model as the expected result type.
*/
open class BaseManager<T>: ServiceManager where T: TargetType {
  public typealias ProviderType = T

  private var sharedProvider: MoyaProvider<T>!

  public required init() {}

  /**
   Default provider implementation as a singleton. It provides networking
   loggin out of the box and you can override it if you want to add more middleware.
 */
  open var provider: MoyaProvider<T> {
    guard let provider = sharedProvider else {
      self.sharedProvider = MoyaProvider<T>(
        plugins: [
          NetworkLoggerPlugin(verbose: true, responseDataFormatter: JSONResponseDataFormatter)
        ]
      )
      return sharedProvider
    }
    return provider
  }

  /**
   Makes a request to the provided target and tries to decode its response
   using the provided keyPath and return type and returning it as an Observable.
   - Parameters:
      - target: The TargetType used to make the request.
      - keyPath: The keypath used to decode from JSON (if passed nil, it will try to decode from the root).
  */
  open func request<T>(_ target: ProviderType, at keyPath: String? = nil) -> Observable<T> where T: Codable {
    return provider.rx.request(target)
      .filterSuccessfulStatusCodes()
      .map(T.self, atKeyPath: keyPath, using: JSONDecoder())
      .asObservable()
  }

  /**
   Makes a request to the provided target and tries to decode its response as an array
   using the provided keyPath and return type and returning it as an Observable.
   - Parameters:
   - target: The TargetType used to make the request.
   - keyPath: The keypath used to decode from JSON (if passed nil, it will try to decode from the root).
   */
  open func requestCollection<T>(_ target: ProviderType, at keyPath: String? = nil) -> Observable<[T]> where T: Codable {
    return provider.rx.request(target)
      .filterSuccessfulStatusCodes()
      .map([T].self, atKeyPath: keyPath, using: JSONDecoder())
      .asObservable()
  }

  /// Helper to use as middleware to pretty print the JSON response.
  private func JSONResponseDataFormatter(_ data: Data) -> Data {
    do {
      let dataAsJSON = try JSONSerialization.jsonObject(with: data)
      let prettyData = try JSONSerialization.data(withJSONObject: dataAsJSON, options: .prettyPrinted)
      return prettyData
    } catch {
      return data
    }
  }
}
