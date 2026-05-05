import Foundation

protocol HttpCallBack<T> {
    associatedtype T
    
    func onParseResponse(data: Data, response: URLResponse) throws -> T
    func onFailure(error: Error)
    func onResponse(response: T)
}

extension HttpCallBack {
    func onFailure(error: Error) {
        AppLogger.debug("Request failed: \(error.localizedDescription)")
    }
} 
